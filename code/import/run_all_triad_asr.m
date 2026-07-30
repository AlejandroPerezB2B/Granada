function [batchTable, allParticipantTable, allIntervalTable, ...
    allChannelTable, allTriadSummary] = ...
    run_all_triad_asr(inputRootDir, outputRootDir, varargin)
% RUN_ALL_TRIAD_ASR Run clean_triad_asr for every triad_xxx folder.
%
% The function searches the input root directory for folders following the
% convention:
%
%   triad_<numeric code>
%
% Each folder is expected to contain three synchronised EEGLAB datasets:
%
%   <code>_1_raw_sync.set
%   <code>_2_raw_sync.set
%   <code>_3_raw_sync.set
%
% For every triad, the function:
%
%   1. Locates the three synchronised recordings.
%   2. Creates a corresponding output folder.
%   3. Runs clean_triad_asr.
%   4. Collects participant-, channel-, interval-, and triad-level QC data.
%   5. Continues to the next triad when requested if one triad fails.
%   6. Saves one combined Excel workbook and one MATLAB report.
%
% EXPECTED INPUT STRUCTURE
%
%   inputRootDir/
%   |-- triad_303/
%   |   |-- 303_1_raw_sync.set
%   |   |-- 303_2_raw_sync.set
%   |   `-- 303_3_raw_sync.set
%   |-- triad_306/
%   |   |-- 306_1_raw_sync.set
%   |   |-- 306_2_raw_sync.set
%   |   `-- 306_3_raw_sync.set
%   `-- ...
%
% OUTPUT STRUCTURE
%
%   outputRootDir/
%   |-- triad_303/
%   |   |-- 303_1_raw_sync_asr.set
%   |   |-- 303_2_raw_sync_asr.set
%   |   |-- 303_3_raw_sync_asr.set
%   |   |-- 303_asr_qc.xlsx
%   |   `-- 303_asr_qc.mat
%   |-- triad_306/
%   |   `-- ...
%   |-- all_triads_asr_qc.xlsx
%   `-- all_triads_asr_qc.mat
%
% INPUTS
%
%   inputRootDir
%       Root directory containing the triad_xxx input folders.
%
%   outputRootDir
%       Root directory in which the cleaned triad folders and combined
%       reports will be saved.
%
% OPTIONAL NAME-VALUE INPUTS
%
%   'InputPattern'
%       sprintf-compatible filename pattern containing one string field for
%       the triad code and one integer field for the member number.
%
%       Default:
%           '%s_%d_raw_sync.set'
%
%   'ContinueOnError'
%       Continue processing subsequent triads when one triad fails.
%
%       Default:
%           true
%
%   'ReportFilename'
%       Filename of the combined Excel report.
%
%       Default:
%           'all_triads_asr_qc.xlsx'
%
%   'MatFilename'
%       Filename of the combined MATLAB report.
%
%       Default:
%           'all_triads_asr_qc.mat'
%
%   'CleanerOptions'
%       Cell array of additional name-value arguments passed directly to
%       clean_triad_asr. Do not include 'OutputDir' or 'SaveOutput', because
%       these are controlled by this wrapper.
%
%       Example:
%
%           cleanOptions = { ...
%               'HighpassHz', 1, ...
%               'ASRBurstCriterion', 20, ...
%               'WindowCriterion', 0.30};
%
%   'SaveCombinedReport'
%       Save the project-level Excel and MATLAB reports.
%
%       Default:
%           true
%
% OUTPUTS
%
%   batchTable
%       One row per triad explored, including input files, processing
%       status, processing time, data-loss summary, and error messages.
%
%   allParticipantTable
%       Combined participant-level QC table from all successful triads.
%
%   allIntervalTable
%       Combined shared-interval table from all successful triads.
%
%   allChannelTable
%       Combined channel-level QC table from all successful triads.
%
%   allTriadSummary
%       Combined triad-level QC table from all successful triads.
%
% EXAMPLE
%
%   inputRootDir = ...
%       'E:\Granada\data_derivatives\02_synchronised';
%
%   outputRootDir = ...
%       'E:\Granada\data_derivatives\03_asr_cleaned';
%
%   [batchTable, allParticipantTable, allIntervalTable, ...
%       allChannelTable, allTriadSummary] = ...
%       run_all_triad_asr( ...
%           inputRootDir, ...
%           outputRootDir, ...
%           'ContinueOnError', true);
%
% AUTHORS
%
%   Alejandro Perez
%   Celia Sissi Stijsiger (@CeliaSissi)
%
% -------------------------------------------------------------------------


%% Parse inputs

parser = inputParser;
parser.FunctionName = mfilename;

pathValidator = @(x) ischar(x) || ...
    (isstring(x) && isscalar(x));

logicalScalar = @(x) islogical(x) && isscalar(x);

addRequired(parser, 'inputRootDir', pathValidator);
addRequired(parser, 'outputRootDir', pathValidator);

addParameter(parser, ...
    'InputPattern', ...
    '%s_%d_raw_sync.set', ...
    pathValidator);

addParameter(parser, ...
    'ContinueOnError', ...
    true, ...
    logicalScalar);

addParameter(parser, ...
    'ReportFilename', ...
    'all_triads_asr_qc.xlsx', ...
    pathValidator);

addParameter(parser, ...
    'MatFilename', ...
    'all_triads_asr_qc.mat', ...
    pathValidator);

addParameter(parser, ...
    'CleanerOptions', ...
    {}, ...
    @iscell);

addParameter(parser, ...
    'SaveCombinedReport', ...
    true, ...
    logicalScalar);

parse(parser, inputRootDir, outputRootDir, varargin{:});

options = parser.Results;

inputRootDir = char(inputRootDir);
outputRootDir = char(outputRootDir);
options.InputPattern = char(options.InputPattern);
options.ReportFilename = char(options.ReportFilename);
options.MatFilename = char(options.MatFilename);


%% Validate directories and dependencies

if ~isfolder(inputRootDir)
    error( ...
        'run_all_triad_asr:InputRootNotFound', ...
        'Input root directory not found:\n%s', ...
        inputRootDir);
end

if ~isfolder(outputRootDir)
    mkdir(outputRootDir);
end

if exist('clean_triad_asr', 'file') ~= 2
    error( ...
        'run_all_triad_asr:CleanerNotFound', ...
        ['clean_triad_asr.m was not found on the MATLAB path. ' ...
         'Place it in the current folder or add its folder to the path.']);
end

validateCleanerOptions(options.CleanerOptions);


%% Find triad_xxx folders

folderListing = dir(fullfile(inputRootDir, 'triad_*'));
folderListing = folderListing([folderListing.isdir]);

triadCodes = strings(0, 1);
triadFolders = strings(0, 1);

for folderIndex = 1:numel(folderListing)

    tokens = regexp( ...
        folderListing(folderIndex).name, ...
        '^triad_(\d+)$', ...
        'tokens', ...
        'once');

    if isempty(tokens)
        continue;
    end

    triadCodes(end + 1, 1) = string(tokens{1}); %#ok<AGROW>
    triadFolders(end + 1, 1) = string( ...
        fullfile(folderListing(folderIndex).folder, ...
        folderListing(folderIndex).name)); %#ok<AGROW>

end

if isempty(triadCodes)
    error( ...
        'run_all_triad_asr:NoTriadFolders', ...
        'No folders following the triad_xxx convention were found in:\n%s', ...
        inputRootDir);
end


%% Sort triads numerically

numericTriadCodes = str2double(triadCodes);

[~, sortOrder] = sort(numericTriadCodes);

triadCodes = triadCodes(sortOrder);
triadFolders = triadFolders(sortOrder);


%% Prepare batch-level containers

numberOfTriads = numel(triadCodes);

emptyBatchRow = struct( ...
    'TriadCode', "", ...
    'InputFolder', "", ...
    'OutputFolder', "", ...
    'InputFile1', "", ...
    'InputFile2', "", ...
    'InputFile3', "", ...
    'Status', "", ...
    'ProcessingSeconds', NaN, ...
    'ParticipantRows', 0, ...
    'ChannelRows', 0, ...
    'RemovedIntervalRows', 0, ...
    'SharedRemovedSamples', NaN, ...
    'SharedRemovedPercent', NaN, ...
    'FinalSamples', NaN, ...
    'FinalDurationSeconds', NaN, ...
    'Message', "");

batchRows = repmat(emptyBatchRow, numberOfTriads, 1);

participantTables = cell(numberOfTriads, 1);
intervalTables = cell(numberOfTriads, 1);
channelTables = cell(numberOfTriads, 1);
triadSummaryTables = cell(numberOfTriads, 1);


%% Process every triad

for triadIndex = 1:numberOfTriads

    triadTimer = tic;

    triadCode = char(triadCodes(triadIndex));
    inputTriadDir = char(triadFolders(triadIndex));
    outputTriadDir = fullfile( ...
        outputRootDir, ...
        ['triad_' triadCode]);

    if ~isfolder(outputTriadDir)
        mkdir(outputTriadDir);
    end

    row = emptyBatchRow;
    row.TriadCode = string(triadCode);
    row.InputFolder = string(inputTriadDir);
    row.OutputFolder = string(outputTriadDir);

    fprintf('\n============================================================\n');
    fprintf('[%d/%d] Processing triad %s\n', ...
        triadIndex, numberOfTriads, triadCode);
    fprintf('Input folder:\n%s\n', inputTriadDir);
    fprintf('============================================================\n');

    try

        %% Locate the three synchronised datasets

        setFiles = strings(3, 1);

        for participant = 1:3
            setFiles(participant) = string(findTriadInputFile( ...
                inputTriadDir, ...
                triadCode, ...
                participant, ...
                options.InputPattern));
        end

        row.InputFile1 = setFiles(1);
        row.InputFile2 = setFiles(2);
        row.InputFile3 = setFiles(3);


        %% Run conservative ASR cleaning

        [~, currentParticipantTable, currentIntervalTable, ...
            currentChannelTable, currentTriadSummary] = ...
            clean_triad_asr( ...
                char(setFiles(1)), ...
                char(setFiles(2)), ...
                char(setFiles(3)), ...
                'OutputDir', outputTriadDir, ...
                'SaveOutput', true, ...
                options.CleanerOptions{:});


        %% Store the successful outputs

        participantTables{triadIndex} = currentParticipantTable;
        channelTables{triadIndex} = currentChannelTable;

        if ~isempty(currentIntervalTable)
            intervalTables{triadIndex} = currentIntervalTable;
        end

        currentTriadSummary = addvars( ...
            currentTriadSummary, ...
            string(inputTriadDir), ...
            string(outputTriadDir), ...
            "Success", ...
            'Before', 1, ...
            'NewVariableNames', { ...
                'InputFolder', ...
                'OutputFolder', ...
                'Status'});

        triadSummaryTables{triadIndex} = currentTriadSummary;

        row.Status = "Success";
        row.ParticipantRows = height(currentParticipantTable);
        row.ChannelRows = height(currentChannelTable);
        row.RemovedIntervalRows = height(currentIntervalTable);
        row.SharedRemovedSamples = ...
            currentTriadSummary.SharedRemovedSamples(1);
        row.SharedRemovedPercent = ...
            currentTriadSummary.SharedRemovedPercent(1);
        row.FinalSamples = ...
            currentTriadSummary.FinalSamples(1);
        row.FinalDurationSeconds = ...
            currentTriadSummary.FinalDurationSeconds(1);
        row.Message = "";

    catch processingError

        row.Status = "Error";
        row.Message = string(getReport( ...
            processingError, ...
            'extended', ...
            'hyperlinks', ...
            'off'));

        fprintf(2, ...
            '\nERROR processing triad %s:\n%s\n', ...
            triadCode, ...
            processingError.message);

        if ~options.ContinueOnError
            row.ProcessingSeconds = toc(triadTimer);
            batchRows(triadIndex) = row;
            rethrow(processingError);
        end

    end

    row.ProcessingSeconds = toc(triadTimer);
    batchRows(triadIndex) = row;

    fprintf('Triad %s status: %s\n', ...
        triadCode, char(row.Status));
    fprintf('Processing time: %.1f seconds\n', ...
        row.ProcessingSeconds);

end


%% Combine all tables

batchTable = struct2table(batchRows);

allParticipantTable = concatenateNonemptyTables( ...
    participantTables);

allIntervalTable = concatenateNonemptyTables( ...
    intervalTables);

allChannelTable = concatenateNonemptyTables( ...
    channelTables);

allTriadSummary = concatenateNonemptyTables( ...
    triadSummaryTables);


%% Save combined project-level reports

excelFile = fullfile( ...
    outputRootDir, ...
    options.ReportFilename);

matFile = fullfile( ...
    outputRootDir, ...
    options.MatFilename);

if options.SaveCombinedReport

    if isfile(excelFile)
        delete(excelFile);
    end

    writeTableOrMessage( ...
        batchTable, ...
        excelFile, ...
        'Batch status', ...
        'No triad folders were processed.');

    writeTableOrMessage( ...
        allParticipantTable, ...
        excelFile, ...
        'Participants', ...
        'No participant-level results were generated.');

    writeTableOrMessage( ...
        allChannelTable, ...
        excelFile, ...
        'Channels', ...
        'No channel-level results were generated.');

    writeTableOrMessage( ...
        allIntervalTable, ...
        excelFile, ...
        'Removed intervals', ...
        'No shared temporal intervals were removed.');

    writeTableOrMessage( ...
        allTriadSummary, ...
        excelFile, ...
        'Triad summaries', ...
        'No triad-level summaries were generated.');

    save( ...
        matFile, ...
        'batchTable', ...
        'allParticipantTable', ...
        'allIntervalTable', ...
        'allChannelTable', ...
        'allTriadSummary', ...
        'options', ...
        '-v7.3');

end


%% Print final batch summary

numberSuccessful = nnz(batchTable.Status == "Success");
numberErrors = nnz(batchTable.Status == "Error");

fprintf('\n\nBatch ASR cleaning completed\n');
fprintf('============================\n');
fprintf('Triad folders explored: %d\n', height(batchTable));
fprintf('Successful triads:      %d\n', numberSuccessful);
fprintf('Triads with errors:     %d\n', numberErrors);

if options.SaveCombinedReport
    fprintf('Combined Excel report:\n%s\n', excelFile);
    fprintf('Combined MATLAB report:\n%s\n\n', matFile);
else
    fprintf('Combined reports were not saved.\n\n');
end

end


%% ========================================================================
function validateCleanerOptions(cleanerOptions)
% Validate name-value arguments forwarded to clean_triad_asr.

if isempty(cleanerOptions)
    return;
end

if mod(numel(cleanerOptions), 2) ~= 0
    error( ...
        'run_all_triad_asr:InvalidCleanerOptions', ...
        'CleanerOptions must contain complete name-value pairs.');
end

optionNames = cleanerOptions(1:2:end);

for optionIndex = 1:numel(optionNames)

    if ~(ischar(optionNames{optionIndex}) || ...
            (isstring(optionNames{optionIndex}) && ...
             isscalar(optionNames{optionIndex})))

        error( ...
            'run_all_triad_asr:InvalidCleanerOptionName', ...
            ['Every odd element of CleanerOptions must be a character ' ...
             'vector or scalar string.']);
    end

end

normalisedNames = lower(strtrim(string(optionNames)));

reservedNames = ["outputdir", "saveoutput"];

if any(ismember(normalisedNames, reservedNames))
    error( ...
        'run_all_triad_asr:ReservedCleanerOption', ...
        ['Do not include OutputDir or SaveOutput in CleanerOptions. ' ...
         'The batch wrapper controls these settings.']);
end

end


%% ========================================================================
function setFile = findTriadInputFile( ...
    triadDir, triadCode, participant, inputPattern)
% Locate one participant's synchronised .set file.

expectedName = sprintf( ...
    inputPattern, ...
    triadCode, ...
    participant);

expectedFile = fullfile( ...
    triadDir, ...
    expectedName);

if isfile(expectedFile)
    setFile = expectedFile;
    return;
end


%% Fall back to a constrained search

searchPattern = sprintf( ...
    '%s_%d*_sync.set', ...
    triadCode, ...
    participant);

candidateListing = dir( ...
    fullfile(triadDir, searchPattern));

candidateListing = candidateListing(~[candidateListing.isdir]);

candidateFiles = strings(0, 1);

for candidateIndex = 1:numel(candidateListing)

    candidateName = string( ...
        candidateListing(candidateIndex).name);

    % Never treat an already ASR-cleaned output as an input.
    if endsWith( ...
            lower(candidateName), ...
            "_asr.set")
        continue;
    end

    candidateFiles(end + 1, 1) = string(fullfile( ...
        candidateListing(candidateIndex).folder, ...
        candidateListing(candidateIndex).name)); %#ok<AGROW>

end

candidateFiles = unique(candidateFiles, 'stable');

if isempty(candidateFiles)

    error( ...
        'run_all_triad_asr:InputFileNotFound', ...
        ['Could not locate the synchronised dataset for triad %s, ' ...
         'participant %d.\nExpected file:\n%s'], ...
        triadCode, ...
        participant, ...
        expectedFile);

end

if numel(candidateFiles) > 1

    error( ...
        'run_all_triad_asr:AmbiguousInputFiles', ...
        ['Multiple candidate files were found for triad %s, ' ...
         'participant %d:\n%s\n\nSet InputPattern explicitly to resolve ' ...
         'the ambiguity.'], ...
        triadCode, ...
        participant, ...
        strjoin(candidateFiles, newline));

end

setFile = char(candidateFiles(1));

end


%% ========================================================================
function combinedTable = concatenateNonemptyTables(tableCells)
% Vertically concatenate all non-empty tables in a cell array.

validTables = tableCells( ...
    ~cellfun(@isempty, tableCells));

if isempty(validTables)
    combinedTable = table();
    return;
end

combinedTable = vertcat(validTables{:});

end


%% ========================================================================
function writeTableOrMessage( ...
    dataTable, excelFile, sheetName, emptyMessage)
% Write a table or a one-row explanatory message to an Excel worksheet.

if isempty(dataTable)

    messageTable = table( ...
        string(emptyMessage), ...
        'VariableNames', {'Message'});

    writetable( ...
        messageTable, ...
        excelFile, ...
        'Sheet', ...
        sheetName);

else

    writetable( ...
        dataTable, ...
        excelFile, ...
        'Sheet', ...
        sheetName);

end

end
