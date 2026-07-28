function [batchSummary, allSyncTable] = ...
    run_all_triad_synchronisation(inputRootDir, outputRootDir, varargin)
% RUN_ALL_TRIAD_SYNCHRONISATION Synchronise all triads in a directory.
%
% Expected input organisation:
%
%   inputRootDir/
%   ├── triad_303/
%   │   ├── 303_1_raw.set
%   │   ├── 303_2_raw.set
%   │   └── 303_3_raw.set
%   ├── triad_306/
%   │   ├── 306_1_raw.set
%   │   ├── 306_2_raw.set
%   │   └── 306_3_raw.set
%   └── ...
%
% Synchronised datasets are saved as:
%
%   outputRootDir/
%   ├── triad_303/
%   │   ├── 303_1_raw_sync.set
%   │   ├── 303_2_raw_sync.set
%   │   └── 303_3_raw_sync.set
%   └── ...
%
% The function also creates:
%
%   triad_synchronisation_report.xlsx
%
% containing:
%
%   - "Triad summary": one row per triad;
%   - "Marker details": one row per marker and triad.
%
% INPUTS
%
%   inputRootDir
%       Folder containing the triad_xxx folders.
%
%   outputRootDir
%       Folder where the synchronised datasets and report will be saved.
%
% OPTIONAL NAME-VALUE INPUTS
%
%   'IgnoreTypes'
%       Event types excluded from marker synchronisation.
%
%       Default:
%           {'boundary', '100008', '249'}
%
%   'ContinueOnError'
%       Continue with the next triad if one triad fails.
%
%       Default:
%           true
%
%   'ReportFilename'
%       Name of the combined Excel report.
%
%       Default:
%           'triad_synchronisation_report.xlsx'
%
% OUTPUTS
%
%   batchSummary
%       Table containing one row per triad.
%
%   allSyncTable
%       Combined marker-level synchronisation table.
%
% AUTHORS
%
%   Alejandro Pérez
%   Celia Sissi Stijsiger (@CeliaSissi)
%
% -------------------------------------------------------------------------


%% Parse inputs

parser = inputParser;

addRequired(parser, 'inputRootDir', ...
    @(x) ischar(x) || (isstring(x) && isscalar(x)));

addRequired(parser, 'outputRootDir', ...
    @(x) ischar(x) || (isstring(x) && isscalar(x)));

addParameter(parser, 'IgnoreTypes', ...
    {'boundary', '100008', '249'}, ...
    @(x) ischar(x) || isstring(x) || iscell(x));

addParameter(parser, 'ContinueOnError', true, ...
    @(x) islogical(x) && isscalar(x));

addParameter(parser, 'ReportFilename', ...
    'triad_synchronisation_report.xlsx', ...
    @(x) ischar(x) || (isstring(x) && isscalar(x)));

parse(parser, inputRootDir, outputRootDir, varargin{:});

options = parser.Results;

inputRootDir  = char(inputRootDir);
outputRootDir = char(outputRootDir);


%% Validate directories and required function

if ~isfolder(inputRootDir)

    error( ...
        'run_all_triad_synchronisation:InputFolderNotFound', ...
        'Input folder not found:\n%s', ...
        inputRootDir);

end

if ~isfolder(outputRootDir)
    mkdir(outputRootDir);
end

if exist('synchronise_triad_markers', 'file') ~= 2

    error( ...
        'run_all_triad_synchronisation:FunctionNotFound', ...
        ['The function synchronise_triad_markers.m was not found ' ...
         'on the MATLAB path.']);

end


%% Find folders named triad_xxx

folderList = dir(fullfile(inputRootDir, 'triad_*'));
folderList = folderList([folderList.isdir]);

triadCodes = {};
validFolders = [];

for folderIndex = 1:numel(folderList)

    tokens = regexp( ...
        folderList(folderIndex).name, ...
        '^triad_(\d+)$', ...
        'tokens', ...
        'once');

    if isempty(tokens)
        continue;
    end

    triadCodes{end + 1, 1} = tokens{1}; %#ok<AGROW>
    validFolders(end + 1, 1) = folderIndex; %#ok<AGROW>

end

folderList = folderList(validFolders);

if isempty(folderList)

    error( ...
        'run_all_triad_synchronisation:NoTriadFolders', ...
        'No folders named triad_xxx were found in:\n%s', ...
        inputRootDir);

end


%% Sort triads numerically

numericCodes = str2double(triadCodes);

[~, sortingOrder] = sort(numericCodes);

triadCodes = triadCodes(sortingOrder);
folderList = folderList(sortingOrder);


%% Prepare batch results

emptySummaryRow = struct( ...
    'TriadCode', "", ...
    'Status', "", ...
    'InputFile1', "", ...
    'InputFile2', "", ...
    'InputFile3', "", ...
    'OutputFile1', "", ...
    'OutputFile2', "", ...
    'OutputFile3', "", ...
    'SamplingRateHz', NaN, ...
    'OriginalMarkers1', NaN, ...
    'OriginalMarkers2', NaN, ...
    'OriginalMarkers3', NaN, ...
    'FinalMarkerCount', NaN, ...
    'InsertedMarkers1', NaN, ...
    'InsertedMarkers2', NaN, ...
    'InsertedMarkers3', NaN, ...
    'FirstMarkerType', "", ...
    'FirstMarkerLatencySeconds', NaN, ...
    'LastMarkerType', "", ...
    'OutputDurationSeconds', NaN, ...
    'ExactlySynchronised', false, ...
    'Message', "");

summaryRows = repmat(emptySummaryRow, numel(folderList), 1);

syncTables = cell(numel(folderList), 1);


%% Process each triad

for triadIndex = 1:numel(folderList)

    triadCode = triadCodes{triadIndex};

    inputTriadDir = fullfile( ...
        inputRootDir, ...
        folderList(triadIndex).name);

    outputTriadDir = fullfile( ...
        outputRootDir, ...
        ['triad_' triadCode]);

    if ~isfolder(outputTriadDir)
        mkdir(outputTriadDir);
    end


    %% Define the expected input filenames

    setFile1 = fullfile( ...
        inputTriadDir, ...
        sprintf('%s_1_raw.set', triadCode));

    setFile2 = fullfile( ...
        inputTriadDir, ...
        sprintf('%s_2_raw.set', triadCode));

    setFile3 = fullfile( ...
        inputTriadDir, ...
        sprintf('%s_3_raw.set', triadCode));


    %% Initialise the summary row

    row = emptySummaryRow;

    row.TriadCode = string(triadCode);

    row.InputFile1 = string(setFile1);
    row.InputFile2 = string(setFile2);
    row.InputFile3 = string(setFile3);


    fprintf( ...
        '\n[%d/%d] Processing triad %s\n', ...
        triadIndex, ...
        numel(folderList), ...
        triadCode);


    try

        %% Confirm that all three files exist

        missingFiles = {};

        if ~isfile(setFile1)
            missingFiles{end + 1} = setFile1; %#ok<AGROW>
        end

        if ~isfile(setFile2)
            missingFiles{end + 1} = setFile2; %#ok<AGROW>
        end

        if ~isfile(setFile3)
            missingFiles{end + 1} = setFile3; %#ok<AGROW>
        end

        if ~isempty(missingFiles)

            error( ...
                'run_all_triad_synchronisation:MissingSetFiles', ...
                'Missing files:\n%s', ...
                strjoin(missingFiles, newline));

        end


        %% Run the triad synchronisation function

        [~, currentSyncTable, currentSummary] = ...
            synchronise_triad_markers( ...
                setFile1, ...
                setFile2, ...
                setFile3, ...
                'IgnoreTypes', options.IgnoreTypes, ...
                'OutputDir', outputTriadDir);


        %% Add the triad identifier to every marker row

        currentSyncTable = addvars( ...
            currentSyncTable, ...
            repmat(string(triadCode), height(currentSyncTable), 1), ...
            'Before', 1, ...
            'NewVariableNames', 'TriadCode');

        syncTables{triadIndex} = currentSyncTable;


        %% Add results to the triad-level summary

        row.Status = "Success";

        row.OutputFile1 = string(currentSummary.outputFiles{1});
        row.OutputFile2 = string(currentSummary.outputFiles{2});
        row.OutputFile3 = string(currentSummary.outputFiles{3});

        row.SamplingRateHz = ...
            currentSummary.samplingRate;

        row.OriginalMarkers1 = ...
            currentSummary.originalMarkerCounts(1);

        row.OriginalMarkers2 = ...
            currentSummary.originalMarkerCounts(2);

        row.OriginalMarkers3 = ...
            currentSummary.originalMarkerCounts(3);

        row.FinalMarkerCount = ...
            currentSummary.finalMarkerCount;

        row.InsertedMarkers1 = ...
            currentSummary.insertedPerRecording(1);

        row.InsertedMarkers2 = ...
            currentSummary.insertedPerRecording(2);

        row.InsertedMarkers3 = ...
            currentSummary.insertedPerRecording(3);

        row.FirstMarkerType = ...
            string(currentSummary.firstMarkerType);

        row.FirstMarkerLatencySeconds = ...
            currentSummary.firstMarkerLatencySeconds;

        row.LastMarkerType = ...
            string(currentSummary.lastMarkerType);

        row.OutputDurationSeconds = ...
            currentSummary.outputDurationSeconds;

        row.ExactlySynchronised = ...
            currentSummary.exactlySynchronised;

        row.Message = "";


    catch processingError

        row.Status = "Error";
        row.Message = string(processingError.message);

        fprintf( ...
            2, ...
            'ERROR processing triad %s:\n%s\n', ...
            triadCode, ...
            processingError.message);

        if ~options.ContinueOnError
            rethrow(processingError);
        end

    end

    summaryRows(triadIndex) = row;

end


%% Create the combined summary table

batchSummary = struct2table(summaryRows);


%% Combine all marker-level synchronisation tables

validSyncTables = syncTables(~cellfun(@isempty, syncTables));

if isempty(validSyncTables)

    allSyncTable = table();

else

    allSyncTable = vertcat(validSyncTables{:});

end


%% Save the combined Excel report

reportFile = fullfile( ...
    outputRootDir, ...
    char(options.ReportFilename));

% Delete an earlier report to avoid retaining obsolete worksheets.
if isfile(reportFile)
    delete(reportFile);
end

writetable( ...
    batchSummary, ...
    reportFile, ...
    'Sheet', ...
    'Triad summary');

if ~isempty(allSyncTable)

    writetable( ...
        allSyncTable, ...
        reportFile, ...
        'Sheet', ...
        'Marker details');

end


%% Also save the MATLAB tables

save( ...
    fullfile(outputRootDir, ...
    'triad_synchronisation_report.mat'), ...
    'batchSummary', ...
    'allSyncTable');


%% Print final summary

numberSuccessful = sum(batchSummary.Status == "Success");
numberErrors = sum(batchSummary.Status == "Error");

fprintf('\nBatch synchronisation completed\n');
fprintf('-------------------------------\n');

fprintf('Triads explored:   %d\n', height(batchSummary));
fprintf('Successful triads: %d\n', numberSuccessful);
fprintf('Triads with errors: %d\n', numberErrors);

fprintf( ...
    'Excel report:\n%s\n\n', ...
    reportFile);

end