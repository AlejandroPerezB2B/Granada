function [batchTable, allSummaryTable, allComponentTable, ...
    allRankTable] = ...
    run_all_ica_dipfit_iclabel(inputRootDir, outputRootDir, varargin)
% RUN_ALL_ICA_DIPFIT_ICLABEL Process every participant in triad_xxx folders.
%
% The function searches every immediate subfolder following the convention:
%
%   triad_<numeric code>
%
% Each folder is expected to contain:
%
%   <code>_1_raw_sync_asr.set
%   <code>_2_raw_sync_asr.set
%   <code>_3_raw_sync_asr.set
%
% Every participant is processed independently using
% run_ica_dipfit_iclabel. The wrapper does not repeat triad-level temporal
% validation.
%
% EXPECTED INPUT STRUCTURE
%
%   inputRootDir/
%   |-- triad_303/
%   |   |-- 303_1_raw_sync_asr.set
%   |   |-- 303_2_raw_sync_asr.set
%   |   `-- 303_3_raw_sync_asr.set
%   |-- triad_306/
%   |   `-- ...
%   `-- ...
%
% OUTPUT STRUCTURE
%
%   outputRootDir/
%   |-- triad_303/
%   |   |-- 303_1_raw_sync_asr_ica.set
%   |   |-- 303_2_raw_sync_asr_ica.set
%   |   |-- 303_3_raw_sync_asr_ica.set
%   |   `-- participant-specific QC files
%   |-- triad_306/
%   |   `-- ...
%   |-- all_participants_ica_qc.xlsx
%   `-- all_participants_ica_qc.mat
%
% INPUTS
%
%   inputRootDir
%       Root directory containing the ASR-cleaned triad_xxx folders.
%
%   outputRootDir
%       Root directory for the ICA/DIPFIT/ICLabel outputs.
%
% OPTIONAL NAME-VALUE INPUTS
%
%   'InputPattern'
%       sprintf-compatible pattern with one string field for the triad code
%       and one integer field for the participant number.
%
%       Default:
%           '%s_%d_raw_sync_asr.set'
%
%   'ContinueOnError'               Default: true
%
%   'PipelineOptions'
%       Cell array of additional name-value arguments passed directly to
%       run_ica_dipfit_iclabel. Do not include OutputDir or SaveOutput.
%
%       Example:
%
%           pipelineOptions = { ...
%               'ICAResampleRate', 250, ...
%               'RandomSeed', 1, ...
%               'RunDIPFIT', true, ...
%               'RunICLabel', true};
%
%   'ReportFilename'
%       Default: 'all_participants_ica_qc.xlsx'
%
%   'MatFilename'
%       Default: 'all_participants_ica_qc.mat'
%
%   'SaveCombinedReport'            Default: true
%
% OUTPUTS
%
%   batchTable
%       One row per participant attempted, including status and errors.
%
%   allSummaryTable
%       Combined participant-level summaries.
%
%   allComponentTable
%       Combined component-level ICLabel and DIPFIT results.
%
%   allRankTable
%       Combined ICA-rank information.
%
% EXAMPLE
%
%   inputRootDir = ...
%       'E:\Granada\data_derivatives\03_asr_cleaned';
%
%   outputRootDir = ...
%       'E:\Granada\data_derivatives\04_ica';
%
%   [batchTable, allSummaryTable, allComponentTable, allRankTable] = ...
%       run_all_ica_dipfit_iclabel( ...
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
    '%s_%d_raw_sync_asr.set', ...
    pathValidator);

addParameter(parser, ...
    'ContinueOnError', ...
    true, ...
    logicalScalar);

addParameter(parser, ...
    'PipelineOptions', ...
    {}, ...
    @iscell);

addParameter(parser, ...
    'ReportFilename', ...
    'all_participants_ica_qc.xlsx', ...
    pathValidator);

addParameter(parser, ...
    'MatFilename', ...
    'all_participants_ica_qc.mat', ...
    pathValidator);

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


%% Validate paths and dependencies

if ~isfolder(inputRootDir)
    error( ...
        'run_all_ica_dipfit_iclabel:InputRootNotFound', ...
        'Input root directory not found:\n%s', ...
        inputRootDir);
end

if ~isfolder(outputRootDir)
    mkdir(outputRootDir);
end

if exist('run_ica_dipfit_iclabel', 'file') ~= 2
    error( ...
        'run_all_ica_dipfit_iclabel:PipelineFunctionNotFound', ...
        ['run_ica_dipfit_iclabel.m was not found on the MATLAB path.']);
end

validatePipelineOptions(options.PipelineOptions);


%% Find and sort triad_xxx folders

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
    triadFolders(end + 1, 1) = string(fullfile( ...
        folderListing(folderIndex).folder, ...
        folderListing(folderIndex).name)); %#ok<AGROW>

end

if isempty(triadCodes)
    error( ...
        'run_all_ica_dipfit_iclabel:NoTriadFolders', ...
        'No triad_xxx folders were found in:\n%s', ...
        inputRootDir);
end

[~, sortOrder] = sort(str2double(triadCodes));
triadCodes = triadCodes(sortOrder);
triadFolders = triadFolders(sortOrder);


%% Prepare output containers

numberOfRows = numel(triadCodes) * 3;

emptyBatchRow = struct( ...
    'TriadCode', "", ...
    'Participant', NaN, ...
    'ParticipantID', "", ...
    'InputFile', "", ...
    'OutputFolder', "", ...
    'OutputFile', "", ...
    'Status', "", ...
    'ProcessingSeconds', NaN, ...
    'FinalICARank', NaN, ...
    'ICAComponentCount', NaN, ...
    'DipolesFitted', NaN, ...
    'Message', "");

batchRows = repmat(emptyBatchRow, numberOfRows, 1);

summaryTables = cell(numberOfRows, 1);
componentTables = cell(numberOfRows, 1);
rankTables = cell(numberOfRows, 1);

batchIndex = 0;


%% Process every participant independently

for triadIndex = 1:numel(triadCodes)

    triadCode = char(triadCodes(triadIndex));
    inputTriadDir = char(triadFolders(triadIndex));

    outputTriadDir = fullfile( ...
        outputRootDir, ...
        ['triad_' triadCode]);

    if ~isfolder(outputTriadDir)
        mkdir(outputTriadDir);
    end

    for participant = 1:3

        batchIndex = batchIndex + 1;
        processingTimer = tic;

        row = emptyBatchRow;
        row.TriadCode = string(triadCode);
        row.Participant = participant;
        row.ParticipantID = sprintf('%s_%d', triadCode, participant);
        row.OutputFolder = string(outputTriadDir);

        fprintf('\n============================================================\n');
        fprintf('[%d/%d] Processing participant %s_%d\n', ...
            batchIndex, numberOfRows, triadCode, participant);
        fprintf('============================================================\n');

        try

            setFile = findParticipantInputFile( ...
                inputTriadDir, ...
                triadCode, ...
                participant, ...
                options.InputPattern);

            row.InputFile = string(setFile);

            [~, currentSummary, currentComponents, currentRank] = ...
                run_ica_dipfit_iclabel( ...
                    setFile, ...
                    'OutputDir', outputTriadDir, ...
                    'SaveOutput', true, ...
                    options.PipelineOptions{:});

            summaryTables{batchIndex} = currentSummary;
            componentTables{batchIndex} = currentComponents;
            rankTables{batchIndex} = currentRank;

            row.OutputFile = currentSummary.OutputFile(1);
            row.Status = "Success";
            row.FinalICARank = currentSummary.FinalICARank(1);
            row.ICAComponentCount = currentSummary.ICAComponentCount(1);
            row.DipolesFitted = currentSummary.DipolesFitted(1);
            row.Message = "";

        catch processingError

            row.Status = "Error";
            row.Message = string(getReport( ...
                processingError, ...
                'extended', ...
                'hyperlinks', ...
                'off'));

            fprintf(2, ...
                '\nERROR processing participant %s_%d:\n%s\n', ...
                triadCode, ...
                participant, ...
                processingError.message);

            if ~options.ContinueOnError

                row.ProcessingSeconds = toc(processingTimer);
                batchRows(batchIndex) = row;
                rethrow(processingError);

            end

        end

        row.ProcessingSeconds = toc(processingTimer);
        batchRows(batchIndex) = row;

        fprintf('Status: %s\n', char(row.Status));
        fprintf('Processing time: %.1f seconds\n', ...
            row.ProcessingSeconds);

    end

end


%% Combine batch outputs

batchTable = struct2table(batchRows);

allSummaryTable = concatenateNonemptyTables(summaryTables);
allComponentTable = concatenateNonemptyTables(componentTables);
allRankTable = concatenateNonemptyTables(rankTables);


%% Save project-level reports

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
        'No participants were processed.');

    writeTableOrMessage( ...
        allSummaryTable, ...
        excelFile, ...
        'Participant summaries', ...
        'No participant summaries were generated.');

    writeTableOrMessage( ...
        allRankTable, ...
        excelFile, ...
        'ICA rank', ...
        'No ICA-rank results were generated.');

    writeTableOrMessage( ...
        allComponentTable, ...
        excelFile, ...
        'Components', ...
        'No component-level results were generated.');

    save( ...
        matFile, ...
        'batchTable', ...
        'allSummaryTable', ...
        'allComponentTable', ...
        'allRankTable', ...
        'options', ...
        '-v7.3');

end


%% Print final result

numberSuccessful = nnz(batchTable.Status == "Success");
numberErrors = nnz(batchTable.Status == "Error");

fprintf('\n\nBatch ICA processing completed\n');
fprintf('==============================\n');
fprintf('Participants attempted: %d\n', height(batchTable));
fprintf('Successful:             %d\n', numberSuccessful);
fprintf('Errors:                 %d\n', numberErrors);

if options.SaveCombinedReport
    fprintf('Combined Excel report:\n%s\n', excelFile);
    fprintf('Combined MATLAB report:\n%s\n\n', matFile);
else
    fprintf('Combined reports were not saved.\n\n');
end

end


%% ========================================================================
function validatePipelineOptions(pipelineOptions)
% Validate name-value arguments forwarded to the participant function.

if isempty(pipelineOptions)
    return;
end

if mod(numel(pipelineOptions), 2) ~= 0
    error( ...
        'run_all_ica_dipfit_iclabel:InvalidPipelineOptions', ...
        'PipelineOptions must contain complete name-value pairs.');
end

optionNames = pipelineOptions(1:2:end);

for optionIndex = 1:numel(optionNames)

    if ~(ischar(optionNames{optionIndex}) || ...
            (isstring(optionNames{optionIndex}) && ...
             isscalar(optionNames{optionIndex})))

        error( ...
            'run_all_ica_dipfit_iclabel:InvalidPipelineOptionName', ...
            ['Every odd element of PipelineOptions must be a character ' ...
             'vector or scalar string.']);

    end

end

normalisedNames = lower(strtrim(string(optionNames)));
reservedNames = ["outputdir", "saveoutput"];

if any(ismember(normalisedNames, reservedNames))
    error( ...
        'run_all_ica_dipfit_iclabel:ReservedPipelineOption', ...
        ['Do not include OutputDir or SaveOutput in PipelineOptions. ' ...
         'The wrapper controls these settings.']);
end

end


%% ========================================================================
function setFile = findParticipantInputFile( ...
    triadDir, triadCode, participant, inputPattern)
% Locate one ASR-cleaned participant dataset.

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

searchPattern = sprintf( ...
    '%s_%d*_asr.set', ...
    triadCode, ...
    participant);

candidateListing = dir(fullfile(triadDir, searchPattern));
candidateListing = candidateListing(~[candidateListing.isdir]);

candidateFiles = strings(0, 1);

for candidateIndex = 1:numel(candidateListing)

    candidateName = string(candidateListing(candidateIndex).name);

    if endsWith(lower(candidateName), "_ica.set")
        continue;
    end

    candidateFiles(end + 1, 1) = string(fullfile( ...
        candidateListing(candidateIndex).folder, ...
        candidateListing(candidateIndex).name)); %#ok<AGROW>

end

candidateFiles = unique(candidateFiles, 'stable');

if isempty(candidateFiles)

    error( ...
        'run_all_ica_dipfit_iclabel:InputFileNotFound', ...
        ['Could not locate the ASR-cleaned dataset for triad %s, ' ...
         'participant %d.\nExpected file:\n%s'], ...
        triadCode, ...
        participant, ...
        expectedFile);

end

if numel(candidateFiles) > 1

    error( ...
        'run_all_ica_dipfit_iclabel:AmbiguousInputFiles', ...
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
% Vertically concatenate all non-empty tables.

validTables = tableCells(~cellfun(@isempty, tableCells));

if isempty(validTables)
    combinedTable = table();
else
    combinedTable = vertcat(validTables{:});
end

end


%% ========================================================================
function writeTableOrMessage( ...
    dataTable, excelFile, sheetName, emptyMessage)
% Write a data table or an explanatory one-row table.

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
