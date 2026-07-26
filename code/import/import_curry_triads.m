function [triads, importLog] = import_curry_triads(rawDataDir, outputDir, varargin)
% IMPORT_CURRY_TRIADS Import raw CURRY/Neuroscan EEG data from participant triads.
%
%   [TRIADS, IMPORTLOG] = IMPORT_CURRY_TRIADS(RAWDATADIR, OUTPUTDIR)
%   searches RAWDATADIR for participant folders whose names follow this
%   structure:
%
%       <triad code>_<triad member>
%
%   For example:
%
%       303_1
%       303_2
%       303_3
%
%   These three folders are interpreted as the three EEG recordings
%   belonging to triad 303.
%
%   Each participant folder is expected to contain one CURRY/Neuroscan
%   recording consisting of files with a common filename stem:
%
%       recording.dat
%       recording.dap
%       recording.rs3
%       recording.ceo
%
%   A .cef event file is also accepted instead of .ceo.
%
%   The .dat file is passed to EEGLAB's POP_FILEIO function. POP_FILEIO
%   should use the accompanying CURRY files automatically.
%
%   Imported EEGLAB datasets are saved using the following structure:
%
%       outputDir/
%       ├── triad_303/
%       │   ├── 303_1_raw.set
%       │   ├── 303_2_raw.set
%       │   └── 303_3_raw.set
%       └── ...
%
%   This function performs ONLY the initial raw-data import. 
%
% INPUTS
%
%   rawDataDir
%       Directory containing the participant folders.
%
%   outputDir
%       Directory in which the imported EEGLAB .set files will be saved.
%
% OPTIONAL NAME-VALUE INPUTS
%
%   'Overwrite'
%       If true, existing .set files are overwritten.
%
%       Default: false
%
%   'ContinueOnError'
%       If true, an import error affecting one participant is recorded in
%       IMPORTLOG and the function continues with the next participant.
%
%       If false, the function stops when an error is encountered.
%
%       Default: true
%
%   'KeepEEGInMemory'
%       If true, the imported EEG structures are retained inside TRIADS.
%
%       This may require a large amount of memory. By default, the datasets
%       are saved to disk and removed from memory before the next recording
%       is imported.
%
%       Default: false
%
%   'InitialiseEEGLAB'
%       If true, EEGLAB is started in no-GUI mode before importing the data.
%
%       Default: true
%
%   'RequireEventFile'
%       If true, each recording must contain a matching .ceo or .cef event
%       file.
%
%       The default is true because the experiment will use common event
%       markers to align the three recordings.
%
%       Default: true
%
%   'Verbose'
%       If true, progress information is printed in the Command Window.
%
%       Default: true
%
% OUTPUTS
%
%   triads
%       Structure array containing one element per triad.
%
%       Important fields include:
%
%           triads(t).code
%           triads(t).isComplete
%           triads(t).members
%           triads(t).commonEventTypes
%
%   importLog
%       Table containing one row per recognised participant folder.
%
%       The log includes:
%
%           - triad code;
%           - triad member;
%           - participant-folder name;
%           - import status;
%           - input .dat file;
%           - output .set file;
%           - number of channels;
%           - sampling rate;
%           - number of samples;
%           - recording duration;
%           - number of events;
%           - event types;
%           - error or warning messages.
%
% DEPENDENCIES
%
%   - MATLAB
%   - EEGLAB
%   - EEGLAB FileIO plug-in
%
% EXAMPLE
%
%   rawDataDir = 'D:\TriadicEEG\data_raw';
%   outputDir  = 'D:\TriadicEEG\data_derivatives\01_imported';
%
%   [triads, importLog] = import_curry_triads( ...
%       rawDataDir, ...
%       outputDir, ...
%       'Overwrite', false, ...
%       'ContinueOnError', true, ...
%       'KeepEEGInMemory', false);
%
% AUTHORS
%
%   Alejandro Pérez (@AlejandroPérezB2B)
%   Celia Sissi Stijsiger (@CeliaSissi)
%
% -------------------------------------------------------------------------


%% Parse the function inputs

parser = inputParser;

parser.FunctionName = mfilename;

addRequired( ...
    parser, ...
    'rawDataDir', ...
    @(x) ischar(x) || (isstring(x) && isscalar(x)));

addRequired( ...
    parser, ...
    'outputDir', ...
    @(x) ischar(x) || (isstring(x) && isscalar(x)));

addParameter( ...
    parser, ...
    'Overwrite', ...
    false, ...
    @(x) islogical(x) && isscalar(x));

addParameter( ...
    parser, ...
    'ContinueOnError', ...
    true, ...
    @(x) islogical(x) && isscalar(x));

addParameter( ...
    parser, ...
    'KeepEEGInMemory', ...
    false, ...
    @(x) islogical(x) && isscalar(x));

addParameter( ...
    parser, ...
    'InitialiseEEGLAB', ...
    true, ...
    @(x) islogical(x) && isscalar(x));

addParameter( ...
    parser, ...
    'RequireEventFile', ...
    true, ...
    @(x) islogical(x) && isscalar(x));

addParameter( ...
    parser, ...
    'Verbose', ...
    true, ...
    @(x) islogical(x) && isscalar(x));

parse(parser, rawDataDir, outputDir, varargin{:});

options = parser.Results;


%% Standardise directory inputs

% Some EEGLAB functions work more consistently with character vectors than
% with MATLAB string objects. The paths are therefore converted here.
rawDataDir = char(rawDataDir);
outputDir  = char(outputDir);


%% Check the raw-data directory

if ~isfolder(rawDataDir)

    error( ...
        'import_curry_triads:RawDirectoryNotFound', ...
        'The raw-data directory does not exist:\n%s', ...
        rawDataDir);

end


%% Create the output directory when necessary

if ~isfolder(outputDir)

    [directoryCreated, creationMessage] = mkdir(outputDir);

    if ~directoryCreated

        error( ...
            'import_curry_triads:CannotCreateOutputDirectory', ...
            'Could not create the output directory:\n%s\n%s', ...
            outputDir, ...
            creationMessage);

    end

end


%% Check EEGLAB availability

if exist('eeglab', 'file') ~= 2

    error( 'import_curry_triads:EEGLABNotFound', ...
        ['EEGLAB was not found on the MATLAB path. Add the EEGLAB ' ...
         'root directory to the MATLAB path before running this function.']);

end


%% Initialise EEGLAB

if options.InitialiseEEGLAB

    if options.Verbose
        fprintf('Initialising EEGLAB in no-GUI mode...\n');
    end

    % Starting EEGLAB allows it to add its installed plug-ins to the path.
    eeglab('nogui');

end


%% Check the required EEGLAB functions

if exist('pop_fileio', 'file') ~= 2

    error( 'import_curry_triads:FileIONotFound', ...
        ['The EEGLAB function POP_FILEIO was not found. Install the ' ...
         'EEGLAB FileIO plug-in and restart EEGLAB.']);

end


%% Find participant folders

directoryContents = dir(rawDataDir);

% Retain only directories.
directoryContents = directoryContents([directoryContents.isdir]);

% Remove "." and "..".
directoryNames = {directoryContents.name};

keepDirectory = ~ismember(directoryNames, {'.', '..'});

directoryContents = directoryContents(keepDirectory);


% Create an initially empty structure for the participant-folder records.
participantRecords = struct( ...
    'triadCode', {}, ...
    'memberIndex', {}, ...
    'participantId', {}, ...
    'folderPath', {});


for folderIndex = 1:numel(directoryContents)

    folderName = directoryContents(folderIndex).name;

    % Participant folders must contain:
    %
    %   one or more numbers;
    %   an underscore;
    %   the member number 1, 2, or 3.
    %
    % Examples:
    %
    %   303_1
    %   303_2
    %   303_3
    %
    tokens = regexp( ...
        folderName, ...
        '^(?<triadCode>\d+)_(?<memberIndex>[123])$', ...
        'names', ...
        'once');

    % Ignore directories that do not follow the participant naming rule.
    if isempty(tokens)
        continue;
    end

    participantRecords(end + 1).triadCode = ... %#ok<AGROW>
        tokens.triadCode;

    participantRecords(end).memberIndex = ...
        str2double(tokens.memberIndex);

    participantRecords(end).participantId = ...
        folderName;

    participantRecords(end).folderPath = ...
        fullfile(rawDataDir, folderName);

end


if isempty(participantRecords)

    error( ...
        'import_curry_triads:NoParticipantFolders', ...
        ['No folders matching <number>_1, <number>_2, or <number>_3 ' ...
         'were found in:\n%s'], ...
        rawDataDir);

end


%% Sort folders by triad and member number

triadNumbers = str2double({participantRecords.triadCode})';

memberNumbers = [participantRecords.memberIndex]';

[~, sortingOrder] = sortrows( ...
    [triadNumbers, memberNumbers], ...
    [1, 2]);

participantRecords = participantRecords(sortingOrder);


% Preserve the text form of each triad code so that leading zeroes are not
% removed if they are used in the folder names.
uniqueTriadCodes = unique( {participantRecords.triadCode}, 'stable');


%% Define the empty participant structure

emptyMember = struct( ...
    'participantId', '', ...
    'memberIndex', NaN, ...
    'folderPath', '', ...
    'rawFiles', struct( ...
        'dat', '', ...
        'dap', '', ...
        'rs3', '', ...
        'event', ''), ...
    'outputSetFile', '', ...
    'status', '', ...
    'nChannels', NaN, ...
    'samplingRateHz', NaN, ...
    'nSamples', NaN, ...
    'durationSeconds', NaN, ...
    'nEvents', NaN, ...
    'eventTypes', {{}}, ...
    'message', '', ...
    'EEG', []);


%% Define the triad structure

triads = repmat( ...
    struct( ...
        'code', '', ...
        'isComplete', false, ...
        'members', repmat(emptyMember, 0, 1), ...
        'commonEventTypes', {{}}), ...
    numel(uniqueTriadCodes), ...
    1);


for triadIndex = 1:numel(uniqueTriadCodes)

    triads(triadIndex).code = uniqueTriadCodes{triadIndex};

end


%% Define the import-log structure

emptyLogRow = struct( ...
    'triad_code', '', ...
    'member', NaN, ...
    'participant_id', '', ...
    'status', '', ...
    'dat_file', '', ...
    'output_set_file', '', ...
    'n_channels', NaN, ...
    'sampling_rate_hz', NaN, ...
    'n_samples', NaN, ...
    'duration_seconds', NaN, ...
    'n_events', NaN, ...
    'event_types', '', ...
    'message', '');


logRows = repmat(emptyLogRow, 0, 1);


%% Import each participant recording

for participantIndex = 1:numel(participantRecords)

    currentRecord = participantRecords(participantIndex);


    if options.Verbose

        fprintf( ...
            '\n[%d/%d] Processing participant %s\n', ...
            participantIndex, ...
            numel(participantRecords), ...
            currentRecord.participantId);

        fprintf( ...
            'Triad: %s | Member: %d\n', ...
            currentRecord.triadCode, ...
            currentRecord.memberIndex);

    end


    % Start with an empty participant result.
    currentMember = emptyMember;

    currentMember.participantId = currentRecord.participantId;

    currentMember.memberIndex = currentRecord.memberIndex;

    currentMember.folderPath = currentRecord.folderPath;


    % Start the corresponding log row.
    currentLogRow = emptyLogRow;

    currentLogRow.triad_code = currentRecord.triadCode;

    currentLogRow.member = currentRecord.memberIndex;

    currentLogRow.participant_id = currentRecord.participantId;

    try

        %% Identify the four CURRY recording files

        curryFiles = identifyCurryFileSet( ...
            currentRecord.folderPath, ...
            options.RequireEventFile);


        currentMember.rawFiles = curryFiles;

        currentLogRow.dat_file = curryFiles.dat;


        %% Define the output location

        triadOutputDir = fullfile( ...
            outputDir, ...
            ['triad_' currentRecord.triadCode]);


        if ~isfolder(triadOutputDir)

            [directoryCreated, creationMessage] = ...
                mkdir(triadOutputDir);

            if ~directoryCreated

                error( ...
                    'import_curry_triads:CannotCreateTriadDirectory', ...
                    'Could not create:\n%s\n%s', ...
                    triadOutputDir, ...
                    creationMessage);

            end

        end


        outputSetName = sprintf( ...
            '%s_raw.set', ...
            currentRecord.participantId);


        outputSetFile = fullfile( triadOutputDir, outputSetName);

        currentMember.outputSetFile = outputSetFile;

        currentLogRow.output_set_file = outputSetFile;


        %% Decide whether an existing dataset should be skipped

        if isfile(outputSetFile) && ~options.Overwrite

            currentMember.status = 'skipped_existing';

            currentMember.message = ...
                ['The output dataset already exists and the Overwrite ' ...
                 'option is false.'];


            currentLogRow.status = currentMember.status;

            currentLogRow.message = currentMember.message;


            if options.Verbose
                fprintf('Skipped: the output dataset already exists.\n');
            end


        else

            %% Import the CURRY recording

            if options.Verbose
                fprintf('Importing:\n%s\n', curryFiles.dat);
            end


            % POP_FILEIO receives the .dat file. The FileIO reader should
            % locate the matching .dap, .rs3, and event files automatically.
            EEG = pop_fileio(curryFiles.dat);
           
            % Temporarily rename Neuroscan CB1/CB2 to their standard 10-5 equivalents.
            cb1Idx = find(strcmpi({EEG.chanlocs.labels}, 'CB1'), 1);
            cb2Idx = find(strcmpi({EEG.chanlocs.labels}, 'CB2'), 1);

            EEG.chanlocs(cb1Idx).labels = 'I1';
            EEG.chanlocs(cb2Idx).labels = 'I2';

            % Import standard channel locations by matching channel labels.
            eeglabRoot = fileparts(which('eeglab.m'));
            EEG = pop_chanedit(EEG, 'lookup', fullfile( ...
                eeglabRoot, 'functions', 'supportfiles', ...
                'Standard-10-5-Cap385.sfp'));

            % Restore the original Neuroscan labels.
            EEG.chanlocs(cb1Idx).labels = 'CB1';
            EEG.chanlocs(cb2Idx).labels = 'CB2';

            % Obtain channel labels in a consistent format.
labels = upper(string({EEG.chanlocs.labels}));

% Initially classify every recorded channel as EEG.
for ch = 1:EEG.nbchan
    EEG.chanlocs(ch).type = 'EEG';
end

% Classify the two ocular channels.
eogIdx = find(ismember(labels, ["HEO", "VEO"]));

for k = 1:numel(eogIdx)
    EEG.chanlocs(eogIdx(k)).type = 'EOG';
end

% Classify the trigger channel.
triggerIdx = find(labels == "TRIGGER");

for k = 1:numel(triggerIdx)
    EEG.chanlocs(triggerIdx(k)).type = 'TRIG';
end

EEG = eeg_checkset(EEG);


            %% Add project-specific metadata

            EEG.setname = sprintf( ...
                'triad_%s_member_%d_raw', ...
                currentRecord.triadCode, ...
                currentRecord.memberIndex);


            EEG.subject = currentRecord.participantId;


            EEG.group = ['triad_' currentRecord.triadCode];


            EEG.comments = sprintf( ...
                ['Raw CURRY recording imported using %s. ' ...
                 'No preprocessing or temporal synchronisation applied.'], ...
                mfilename);


            % Store information needed to trace the origin of the dataset.
            EEG.etc.triadic_pipeline.import_function = mfilename;

            EEG.etc.triadic_pipeline.import_date = datestr(now, 30);

            EEG.etc.triadic_pipeline.triad_code = currentRecord.triadCode;

            EEG.etc.triadic_pipeline.member_index = ...
                currentRecord.memberIndex;

            EEG.etc.triadic_pipeline.participant_id = ...
                currentRecord.participantId;

            EEG.etc.triadic_pipeline.raw_files = curryFiles;

            EEG.etc.triadic_pipeline.preprocessing_applied = false;

            EEG.etc.triadic_pipeline.synchronisation_applied = false;


            EEG = eeg_checkset( EEG, 'eventconsistency');


            %% Obtain a summary of the imported recording

            eventTypes = summariseEventTypes(EEG);

            currentMember.nChannels = EEG.nbchan;

            currentMember.samplingRateHz = EEG.srate;

            currentMember.nSamples = EEG.pnts * EEG.trials;

            currentMember.durationSeconds = currentMember.nSamples / EEG.srate;

            currentMember.nEvents = numel(EEG.event);

            currentMember.eventTypes = eventTypes;

            currentLogRow.n_channels = currentMember.nChannels;

            currentLogRow.sampling_rate_hz = currentMember.samplingRateHz;

            currentLogRow.n_samples = currentMember.nSamples;

            currentLogRow.duration_seconds = currentMember.durationSeconds;

            currentLogRow.n_events = currentMember.nEvents;

            currentLogRow.event_types = strjoin(eventTypes, ' | ');


            %% Save the imported EEGLAB dataset

            EEG = pop_saveset( ...
                EEG, ...
                'filename', outputSetName, ...
                'filepath', triadOutputDir);


            currentMember.status = 'imported';

            currentMember.message = '';

            currentLogRow.status = 'imported';

            currentLogRow.message = '';


            %% Retain or remove the EEG data from memory

            if options.KeepEEGInMemory

                currentMember.EEG = EEG;

            else

                currentMember.EEG = [];

                clear EEG;

            end


            if options.Verbose

                fprintf( ...
                    'Saved:\n%s\n', ...
                    outputSetFile);

                fprintf( ...
                    ['Channels: %d | Sampling rate: %.3f Hz | ' ...
                     'Events: %d\n'], ...
                    currentMember.nChannels, ...
                    currentMember.samplingRateHz, ...
                    currentMember.nEvents);

            end

        end


    catch importError

        %% Record an import error

        currentMember.status = 'error';

        currentMember.message = importError.message;


        currentLogRow.status = 'error';

        currentLogRow.message = importError.message;


        if options.Verbose

            fprintf( ...
                2, ...
                'ERROR: %s\n', ...
                importError.message);

        end


        if ~options.ContinueOnError
            rethrow(importError);
        end

    end


    %% Add this participant to the appropriate triad

    triadIndex = find( ...
        strcmp( ...
            {triads.code}, ...
            currentRecord.triadCode), ...
        1, ...
        'first');


    triads(triadIndex).members(end + 1, 1) = currentMember;


    %% Add the participant result to the import log

    logRows(end + 1, 1) = currentLogRow; %#ok<AGROW>

end


%% Generate triad-level summaries

for triadIndex = 1:numel(triads)

    if isempty(triads(triadIndex).members)
        continue;
    end


    %% Sort the members as 1, 2, and 3

    [~, memberOrder] = sort([triads(triadIndex).members.memberIndex]);


    triads(triadIndex).members = ...
        triads(triadIndex).members(memberOrder);


    %% Determine whether the triad has all three member folders

    memberIndices = ...
        [triads(triadIndex).members.memberIndex];


    triads(triadIndex).isComplete = ...
        numel(memberIndices) == 3 && ...
        isequal(sort(memberIndices), [1, 2, 3]);


    %% Identify event types present in all three imported datasets

    eventTypeLists = {};


    for memberIndex = 1:numel(triads(triadIndex).members)

        currentMember = ...
            triads(triadIndex).members(memberIndex);


        if strcmp(currentMember.status, 'imported') && ...
                ~isempty(currentMember.eventTypes)

            eventTypeLists{end + 1} = ... %#ok<AGROW>
                currentMember.eventTypes;

        end

    end


    % Only calculate common event types if all three recordings were
    % imported successfully.
    if numel(eventTypeLists) == 3

        commonEventTypes = ...
            eventTypeLists{1};


        commonEventTypes = intersect( ...
            commonEventTypes, ...
            eventTypeLists{2}, ...
            'stable');


        commonEventTypes = intersect( ...
            commonEventTypes, ...
            eventTypeLists{3}, ...
            'stable');


        triads(triadIndex).commonEventTypes = ...
            commonEventTypes;

    else

        triads(triadIndex).commonEventTypes = {};

    end


    if options.Verbose && ...
            ~triads(triadIndex).isComplete

        fprintf( ...
            2, ...
            ['Warning: triad %s does not contain exactly one folder ' ...
             'for members 1, 2, and 3.\n'], ...
            triads(triadIndex).code);

    end

end


%% Convert the import log to a table

importLog = struct2table(logRows);


%% Print a final import summary

if options.Verbose

    fprintf('\nImport finished.\n');

    fprintf( ...
        'Recognised triads: %d\n', ...
        numel(triads));

    fprintf( ...
        'Recognised participant folders: %d\n', ...
        height(importLog));

    fprintf( ...
        'Imported: %d\n', ...
        sum(strcmp(importLog.status, 'imported')));

    fprintf( ...
        'Skipped: %d\n', ...
        sum(strcmp(importLog.status, 'skipped_existing')));

    fprintf( ...
        'Errors: %d\n', ...
        sum(strcmp(importLog.status, 'error')));

end

end


%% ========================================================================
function curryFiles = identifyCurryFileSet( ...
    participantFolder, ...
    requireEventFile)
% IDENTIFYCURRYFILESET Identify one complete CURRY recording.
%
%   CURRYFILES = IDENTIFYCURRYFILESET(PARTICIPANTFOLDER,
%   REQUIREEVENTFILE) examines the files in a participant folder and
%   identifies a .dat file with matching .dap, .rs3, and event files.
%
%   The function raises an error if:
%
%       - no .dat file exists;
%       - no complete recording exists;
%       - more than one complete recording exists.
%
%   Selecting one recording silently when several are present could result
%   in the wrong recording being analysed. Ambiguous folders are therefore
%   treated as errors.


%% List all files in the participant folder

folderContents = dir(participantFolder);

folderContents = folderContents(~[folderContents.isdir]);

allFileNames = {folderContents.name};


% Produce lower-case copies for extension comparisons.
lowerFileNames = cellfun( ...
    @lower, ...
    allFileNames, ...
    'UniformOutput', ...
    false);


%% Identify all .dat files

isDatFile = cellfun( ...
    @(fileName) endsWith(fileName, '.dat'), ...
    lowerFileNames);


datFileNames = allFileNames(isDatFile);


if isempty(datFileNames)

    error( ...
        'import_curry_triads:NoDatFile', ...
        'No .dat file was found in:\n%s', ...
        participantFolder);

end


%% Check which .dat files have the required companions

completeFileSets = repmat( ...
    struct( ...
        'dat', '', ...
        'dap', '', ...
        'rs3', '', ...
        'event', ''), ...
    0, ...
    1);


incompleteDescriptions = {};


for datIndex = 1:numel(datFileNames)

    datFileName = datFileNames{datIndex};


    [~, baseFileName] = fileparts(datFileName);


    dapFileName = findFileIgnoringCase( ...
        allFileNames, ...
        [baseFileName '.dap']);


    rs3FileName = findFileIgnoringCase( ...
        allFileNames, ...
        [baseFileName '.rs3']);


    ceoFileName = findFileIgnoringCase( ...
        allFileNames, ...
        [baseFileName '.ceo']);


    cefFileName = findFileIgnoringCase( ...
        allFileNames, ...
        [baseFileName '.cef']);


    % Prefer .ceo if both .ceo and .cef are present.
    if ~isempty(ceoFileName)

        eventFileName = ceoFileName;

    else

        eventFileName = cefFileName;

    end


    hasRequiredFiles = ...
        ~isempty(dapFileName) && ...
        ~isempty(rs3FileName);


    if requireEventFile

        hasRequiredFiles = ...
            hasRequiredFiles && ...
            ~isempty(eventFileName);

    end


    if hasRequiredFiles

        currentFileSet.dat = fullfile( ...
            participantFolder, ...
            datFileName);


        currentFileSet.dap = fullfile( ...
            participantFolder, ...
            dapFileName);


        currentFileSet.rs3 = fullfile( ...
            participantFolder, ...
            rs3FileName);


        if isempty(eventFileName)

            currentFileSet.event = '';

        else

            currentFileSet.event = fullfile( ...
                participantFolder, ...
                eventFileName);

        end


        completeFileSets(end + 1, 1) = ... %#ok<AGROW>
            currentFileSet;


    else

        missingExtensions = {};


        if isempty(dapFileName)

            missingExtensions{end + 1} = ... %#ok<AGROW>
                '.dap';

        end


        if isempty(rs3FileName)

            missingExtensions{end + 1} = ... %#ok<AGROW>
                '.rs3';

        end


        if requireEventFile && ...
                isempty(eventFileName)

            missingExtensions{end + 1} = ... %#ok<AGROW>
                '.ceo or .cef';

        end


        incompleteDescriptions{end + 1} = sprintf( ... %#ok<AGROW>
            '%s is missing %s', ...
            datFileName, ...
            strjoin(missingExtensions, ', '));

    end

end


%% Check that exactly one complete recording was found

if isempty(completeFileSets)

    if isempty(incompleteDescriptions)

        errorDetails = ...
            'No complete CURRY file set could be identified.';

    else

        errorDetails = ...
            strjoin(incompleteDescriptions, newline);

    end


    error( ...
        'import_curry_triads:IncompleteCurryDataset', ...
        'No complete CURRY dataset was found in:\n%s\n%s', ...
        participantFolder, ...
        errorDetails);

end


if numel(completeFileSets) > 1

    datFileList = strjoin( ...
        {completeFileSets.dat}, ...
        newline);


    error( ...
        'import_curry_triads:MultipleCurryDatasets', ...
        ['More than one complete CURRY recording was found in:\n%s\n\n' ...
         '%s\n\nThe current importer expects one recording per folder.'], ...
        participantFolder, ...
        datFileList);

end


curryFiles = completeFileSets(1);

end


%% ========================================================================
function matchingFileName = findFileIgnoringCase( ...
    allFileNames, ...
    targetFileName)
% FINDFILEIGNORINGCASE Find a filename without case sensitivity.
%
%   This is useful because files may contain upper- or lower-case extensions,
%   particularly when data have been moved between operating systems.


matchingIndex = find( ...
    strcmpi(allFileNames, targetFileName), ...
    1, ...
    'first');


if isempty(matchingIndex)

    matchingFileName = '';

else

    matchingFileName = ...
        allFileNames{matchingIndex};

end

end


%% ========================================================================
function eventTypes = summariseEventTypes(EEG)
% SUMMARISEEVENTTYPES Return the unique EEGLAB event types as text.
%
%   EEGLAB event types can be represented as:
%
%       - character vectors;
%       - MATLAB strings;
%       - numerical values;
%       - cells.
%
%   The event types are converted to character vectors so that they can be
%   stored consistently in the import log.


eventTypes = {};


if ~isfield(EEG, 'event') || ...
        isempty(EEG.event)

    return;

end


convertedEventTypes = cell( ...
    1, ...
    numel(EEG.event));


for eventIndex = 1:numel(EEG.event)

    if ~isfield(EEG.event(eventIndex), 'type')

        convertedEventTypes{eventIndex} = ...
            '<missing type>';

        continue;

    end


    convertedEventTypes{eventIndex} = ...
        eventTypeToText( ...
            EEG.event(eventIndex).type);

end


eventTypes = unique( ...
    convertedEventTypes, ...
    'stable');

end


%% ========================================================================
function textValue = eventTypeToText(eventType)
% EVENTTYPETOTEXT Convert one EEGLAB event type to a character vector.


if ischar(eventType)

    textValue = eventType;


elseif isstring(eventType)

    textValue = char(eventType);


elseif isnumeric(eventType) || ...
        islogical(eventType)

    if isscalar(eventType)

        textValue = num2str(eventType);

    else

        textValue = mat2str(eventType);

    end


elseif iscell(eventType)

    if isempty(eventType)

        textValue = '<empty>';


    elseif numel(eventType) == 1

        textValue = eventTypeToText( ...
            eventType{1});


    else

        eventParts = cellfun( ...
            @eventTypeToText, ...
            eventType, ...
            'UniformOutput', ...
            false);


        textValue = strjoin( ...
            eventParts, ...
            ',');

    end


else

    textValue = ...
        ['<' class(eventType) '>'];

end


if isempty(textValue)

    textValue = '<empty>';

end

end