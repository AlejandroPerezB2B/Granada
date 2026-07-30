function [EEGclean, participantTable, intervalTable, channelTable, triadSummary] = ...
    clean_triad_asr(setFile1, setFile2, setFile3, varargin)
% CLEAN_TRIAD_ASR Conservatively clean three synchronised EEG recordings.
%
% This function prepares one triad for a later ICA-preparation stage. It:
%
%   1. Loads and validates three continuous, synchronised EEGLAB datasets.
%   2. Identifies EEG, EOG, and trigger channels.
%   3. High-pass filters EEG and EOG channels once at 1 Hz by default.
%      The trigger channel is never filtered.
%   4. Detects flat-lined and poorly reconstructed EEG channels.
%   5. Protects frontal channels from correlation-only rejection.
%   6. Runs conservative Artifact Subspace Reconstruction (ASR) separately
%      for each participant, on retained EEG channels only.
%   7. Identifies severe residual bad periods separately for each recording.
%   8. Forms the union of those bad periods across the triad.
%   9. Removes exactly the same samples from all three recordings.
%  10. Saves participant-, channel-, interval-, and triad-level QC results.
%
% The function deliberately does NOT:
%
%   - remove line noise;
%   - rereference the data;
%   - interpolate removed channels;
%   - run ICA or ICLabel.
%
% M1 and M2 are treated as EEG channels when their channel type is EEG.
% HEO, VEO, and Trigger are retained as auxiliary channels. EOG channels
% are high-pass filtered but are not used for bad-channel detection, ASR,
% or residual-window rejection. Trigger is only shortened by the final
% shared temporal mask and is otherwise left unchanged.
%
% INPUTS
%
%   setFile1, setFile2, setFile3
%       Paths to the three synchronised continuous EEGLAB .set datasets.
%
% OPTIONAL NAME-VALUE INPUTS
%
%   'OutputDir'                       Default: ''
%       Output folder. When empty, files are saved beside the first input.
%
%   'SaveOutput'                      Default: true
%       Save cleaned .set files and QC reports.
%
%   'OnlineReferenceDescription'
%       Default: dedicated Quik-Cap reference between Cz and CPz; not
%       stored as a channel and not restored as a zero-valued channel.
%       This is metadata only; the function does not rereference.
%
%   'HighpassHz'                      Default: 1
%       One-time high-pass passband edge in Hz.
%
%   'FilterEOG'                       Default: true
%       Also high-pass filter HEO/VEO. Trigger is never filtered.
%
%   'EOGLabels'                       Default: {'HEO','VEO'}
%   'TriggerLabels'                   Default: {'Trigger'}
%
%   'ProtectedFrontalLabels'
%       Default:
%       {'Fp1','Fpz','Fp2','AF7','AF3','AFz','AF4','AF8','F7','F8'}
%
%       Protected channels are retained when they fail only the robust
%       channel-correlation criterion. They are still removed if flat-lined.
%
%   'EOGAssociationThreshold'         Default: 0.25
%       Descriptive threshold used to distinguish protected channels with
%       appreciable EOG association in the channel-level QC table. It does
%       not itself cause channel rejection.
%
%   'FlatlineCriterion'               Default: 5 seconds
%   'ChannelCriterion'                Default: 0.75
%   'ChannelCriterionMaxBadTime'      Default: 0.50
%   'ChannelRansacSamples'            Default: 50
%
%   'ASRBurstCriterion'               Default: 20
%   'ASRMaxDimensions'                Default: 0.66
%   'ASRReferenceMaxBadChannels'      Default: 0.075
%   'ASRReferenceTolerances'          Default: [-3.5 5.5]
%   'ASRReferenceWindowLength'        Default: 1 second
%   'ASRUseRiemannian'                Default: false
%   'ASRMaxMemoryMB'                  Default: 64
%   'ASRChangeTolerance'              Default: 1e-8
%
%   'WindowCriterion'                 Default: 0.30
%   'WindowTolerances'                Default: [-Inf 7]
%   'WindowLength'                    Default: 1 second
%   'WindowOverlap'                   Default: 0.66
%   'ExcludeProtectedFromWindows'     Default: true
%
%       The window detector identifies severe activity remaining after ASR.
%       A period rejected by any participant is removed from all three.
%
%   'IgnoreEventTypes'
%       Default: {'boundary','100008','249'}
%       These event types are ignored when validating experimental-marker
%       correspondence across recordings.
%
% OUTPUTS
%
%   EEGclean
%       1-by-3 cell array containing the cleaned datasets.
%
%   participantTable
%       One row per recording with channel and sample-loss statistics.
%
%   intervalTable
%       One row per shared removed interval, in original sample coordinates.
%
%   channelTable
%       One row per original EEG channel and participant, documenting the
%       automatic flags and final channel decision.
%
%   triadSummary
%       One-row table summarising final temporal correspondence and data loss.
%
% EXAMPLE
%
%   [EEGclean, participantTable, intervalTable, channelTable, triadSummary] = ...
%       clean_triad_asr( ...
%           '303_1_raw_sync.set', ...
%           '303_2_raw_sync.set', ...
%           '303_3_raw_sync.set', ...
%           'OutputDir', 'D:\TriadicEEG\cleaned');
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

fileValidator = @(x) ischar(x) || (isstring(x) && isscalar(x));
positiveScalar = @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x > 0;
unitInterval = @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x >= 0 && x <= 1;
logicalScalar = @(x) islogical(x) && isscalar(x);
labelList = @(x) ischar(x) || isstring(x) || iscellstr(x); %#ok<ISCLSTR>

addRequired(parser, 'setFile1', fileValidator);
addRequired(parser, 'setFile2', fileValidator);
addRequired(parser, 'setFile3', fileValidator);

addParameter(parser, 'OutputDir', '', fileValidator);
addParameter(parser, 'SaveOutput', true, logicalScalar);
addParameter(parser, 'OnlineReferenceDescription', ...
    'Dedicated Quik-Cap reference between Cz and CPz; not stored and not restored', ...
    fileValidator);

addParameter(parser, 'HighpassHz', 1, positiveScalar);
addParameter(parser, 'FilterEOG', true, logicalScalar);

addParameter(parser, 'EOGLabels', {'HEO', 'VEO'}, labelList);
addParameter(parser, 'TriggerLabels', {'Trigger'}, labelList);
addParameter(parser, 'ProtectedFrontalLabels', ...
    {'Fp1','Fpz','Fp2','AF7','AF3','AFz','AF4','AF8','F7','F8'}, ...
    labelList);
addParameter(parser, 'EOGAssociationThreshold', 0.25, unitInterval);

addParameter(parser, 'FlatlineCriterion', 5, positiveScalar);
addParameter(parser, 'ChannelCriterion', 0.75, unitInterval);
addParameter(parser, 'ChannelCriterionMaxBadTime', 0.50, unitInterval);
addParameter(parser, 'ChannelRansacSamples', 50, positiveScalar);

addParameter(parser, 'ASRBurstCriterion', 20, positiveScalar);
addParameter(parser, 'ASRMaxDimensions', 0.66, unitInterval);
addParameter(parser, 'ASRReferenceMaxBadChannels', 0.075, unitInterval);
addParameter(parser, 'ASRReferenceTolerances', [-3.5 5.5], ...
    @(x) isnumeric(x) && numel(x) == 2);
addParameter(parser, 'ASRReferenceWindowLength', 1, positiveScalar);
addParameter(parser, 'ASRUseRiemannian', false, logicalScalar);
addParameter(parser, 'ASRMaxMemoryMB', 64, positiveScalar);
addParameter(parser, 'ASRChangeTolerance', 1e-8, positiveScalar);

addParameter(parser, 'WindowCriterion', 0.30, unitInterval);
addParameter(parser, 'WindowTolerances', [-Inf 7], ...
    @(x) isnumeric(x) && numel(x) == 2);
addParameter(parser, 'WindowLength', 1, positiveScalar);
addParameter(parser, 'WindowOverlap', 0.66, unitInterval);
addParameter(parser, 'ExcludeProtectedFromWindows', true, logicalScalar);

addParameter(parser, 'IgnoreEventTypes', ...
    {'boundary', '100008', '249'}, labelList);

parse(parser, setFile1, setFile2, setFile3, varargin{:});
options = parser.Results;

options.OutputDir = char(options.OutputDir);
options.OnlineReferenceDescription = ...
    char(options.OnlineReferenceDescription);
options.EOGLabels = cellstr(string(options.EOGLabels));
options.TriggerLabels = cellstr(string(options.TriggerLabels));
options.ProtectedFrontalLabels = ...
    cellstr(string(options.ProtectedFrontalLabels));
options.IgnoreEventTypes = cellstr(string(options.IgnoreEventTypes));
options.ChannelRansacSamples = round(options.ChannelRansacSamples);

setFiles = {
    char(setFile1)
    char(setFile2)
    char(setFile3)
    };


%% Check dependencies

requiredFunctions = { ...
    'pop_loadset', ...
    'pop_saveset', ...
    'pop_select', ...
    'pop_eegfiltnew', ...
    'eeg_checkset', ...
    'clean_flatlines', ...
    'clean_channels', ...
    'clean_asr', ...
    'clean_windows'};

missingFunctions = requiredFunctions( ...
    cellfun(@(x) exist(x, 'file') ~= 2, requiredFunctions));

if ~isempty(missingFunctions)
    error( ...
        'clean_triad_asr:MissingDependencies', ...
        ['The following required EEGLAB or clean_rawdata functions were ' ...
         'not found on the MATLAB path:\n%s'], ...
        strjoin(missingFunctions, ', '));
end


%% Load datasets

EEGclean = cell(1, 3);
inputFolders = cell(3, 1);
inputNames = cell(3, 1);
inputExtensions = cell(3, 1);

for recording = 1:3

    if ~isfile(setFiles{recording})
        error( ...
            'clean_triad_asr:FileNotFound', ...
            'Dataset not found:\n%s', ...
            setFiles{recording});
    end

    [inputFolders{recording}, inputNames{recording}, ...
        inputExtensions{recording}] = fileparts(setFiles{recording});

    if isempty(inputFolders{recording})
        inputFolders{recording} = pwd;
    end

    EEGclean{recording} = pop_loadset( ...
        'filename', [inputNames{recording} inputExtensions{recording}], ...
        'filepath', inputFolders{recording});

    EEGclean{recording} = eeg_checkset( ...
        EEGclean{recording}, 'eventconsistency');

    if EEGclean{recording}.trials ~= 1
        error( ...
            'clean_triad_asr:EpochedDataset', ...
            ['Recording %d is epoched. This function requires ' ...
             'continuous data.'], ...
            recording);
    end
end


%% Validate temporal and marker correspondence

samplingRates = cellfun(@(x) double(x.srate), EEGclean);
pointCounts = cellfun(@(x) double(x.pnts), EEGclean);

if any(abs(samplingRates - samplingRates(1)) > 1e-10)
    error( ...
        'clean_triad_asr:DifferentSamplingRates', ...
        ['The recordings have different sampling rates: ' ...
         '%.10g, %.10g, %.10g Hz.'], ...
        samplingRates(1), samplingRates(2), samplingRates(3));
end

if any(pointCounts ~= pointCounts(1))
    error( ...
        'clean_triad_asr:DifferentPointCounts', ...
        ['The recordings do not have identical sample counts: ' ...
         '%d, %d, %d. Run marker synchronisation first.'], ...
        pointCounts(1), pointCounts(2), pointCounts(3));
end

samplingRate = samplingRates(1);
originalPointCount = pointCounts(1);

validateComparableEvents(EEGclean, options.IgnoreEventTypes, 'before cleaning');


%% Resolve output location and triad identifier

if isempty(options.OutputDir)
    outputDir = inputFolders{1};
else
    outputDir = options.OutputDir;
end

if options.SaveOutput && ~isfolder(outputDir)
    mkdir(outputDir);
end

triadCode = inferTriadCode(inputNames);


%% Initialise QC containers

originalChanlocs = cell(1, 3);
originalEventCounts = zeros(1, 3);
filteredChannelLabels = cell(1, 3);
removedChannelLabels = cell(1, 3);
protectedRetainedLabels = cell(1, 3);

asrChangedMasks = false(3, originalPointCount);
participantBadMasks = false(3, originalPointCount);
asrChangedChannelSamples = zeros(1, 3);

channelRows = struct( ...
    'TriadCode', {}, ...
    'Participant', {}, ...
    'InputFile', {}, ...
    'ChannelLabel', {}, ...
    'IsProtectedFrontal', {}, ...
    'FlatlineFlagged', {}, ...
    'CorrelationFlagged', {}, ...
    'MaxAbsEOGCorrelation', {}, ...
    'EOGAssociated', {}, ...
    'Removed', {}, ...
    'Decision', {});


%% Process each recording independently before forming the shared mask

for recording = 1:3

    fprintf('\n[%d/3] Cleaning %s\n', recording, setFiles{recording});

    EEG = EEGclean{recording};

    originalChanlocs{recording} = EEG.chanlocs;
    originalEventCounts(recording) = numel(EEG.event);


    %% Identify channel groups

    groups = classifyChannels( ...
        EEG, options.EOGLabels, options.TriggerLabels);

    if isempty(groups.eegIndices)
        error( ...
            'clean_triad_asr:NoEEGChannels', ...
            'No EEG channels were identified in recording %d.', ...
            recording);
    end

    originalEEGLabels = groups.labels(groups.eegIndices);
    protectedLabelsPresent = intersectLabels( ...
        originalEEGLabels, options.ProtectedFrontalLabels);


    %% Apply a one-time 1-Hz high-pass filter to EEG and optionally EOG

    filterIndices = groups.eegIndices;

    if options.FilterEOG
        filterIndices = unique([filterIndices groups.eogIndices], 'stable');
    end

    filteredChannelLabels{recording} = ...
        cellstr(groups.labels(filterIndices));

    EEG = filterSelectedChannels( ...
        EEG, filterIndices, options.HighpassHz);


    %% Calculate EOG association for protected channels

    groupsAfterFilter = classifyChannels( ...
        EEG, options.EOGLabels, options.TriggerLabels);

    protectedEOGCorrelation = calculateProtectedEOGCorrelation( ...
        EEG, ...
        protectedLabelsPresent, ...
        groupsAfterFilter.eogIndices);


    %% Detect flat-lined EEG channels

    eegOnly = pop_select( ...
        EEG, 'channel', groupsAfterFilter.eegIndices);

    labelsBeforeFlat = string({eegOnly.chanlocs.labels});

    eegWithoutFlat = clean_flatlines( ...
        eegOnly, options.FlatlineCriterion);

    labelsAfterFlat = string({eegWithoutFlat.chanlocs.labels});

    flatlineLabels = setdiffLabels( ...
        labelsBeforeFlat, labelsAfterFlat);

    if isempty(labelsAfterFlat)
        error( ...
            'clean_triad_asr:AllEEGChannelsFlat', ...
            'All EEG channels were removed as flat-lined in recording %d.', ...
            recording);
    end


    %% Detect persistently poorly reconstructed EEG channels

    % Infinite threshold strictly disables line-noise-based channel rejection.
    % No line-noise correction or notch filtering is performed.
    lineNoiseCriterionOff = Inf;

    try
        eegAfterCorrelation = clean_channels( ...
            eegWithoutFlat, ...
            options.ChannelCriterion, ...
            lineNoiseCriterionOff, ...
            [], ...
            options.ChannelCriterionMaxBadTime, ...
            options.ChannelRansacSamples);
    catch channelError
        error( ...
            'clean_triad_asr:ChannelDetectionFailed', ...
            ['Bad-channel correlation detection failed for recording %d. ' ...
             'Confirm that all EEG channels have valid channel locations.\n' ...
             'Original error: %s'], ...
            recording, channelError.message);
    end

    labelsAfterCorrelation = ...
        string({eegAfterCorrelation.chanlocs.labels});

    correlationFlaggedLabels = setdiffLabels( ...
        labelsAfterFlat, labelsAfterCorrelation);


    %% Protect frontal channels from correlation-only rejection

    protectedCorrelationLabels = intersectLabels( ...
        correlationFlaggedLabels, protectedLabelsPresent);

    correlationRemovedLabels = setdiffLabels( ...
        correlationFlaggedLabels, protectedLabelsPresent);

    finalRemovedLabels = unique( ...
        [flatlineLabels(:); correlationRemovedLabels(:)], ...
        'stable');

    protectedRetainedLabels{recording} = ...
        cellstr(protectedCorrelationLabels);

    removedChannelLabels{recording} = ...
        cellstr(finalRemovedLabels);


    %% Create channel-level QC rows

    for channelIndex = 1:numel(originalEEGLabels)

        channelLabel = originalEEGLabels(channelIndex);

        isProtected = containsLabel( ...
            protectedLabelsPresent, channelLabel);

        isFlat = containsLabel(flatlineLabels, channelLabel);
        isCorrelationFlagged = containsLabel( ...
            correlationFlaggedLabels, channelLabel);
        isRemoved = containsLabel(finalRemovedLabels, channelLabel);

        eogCorrelation = lookupCorrelation( ...
            protectedEOGCorrelation, channelLabel);

        eogAssociated = isfinite(eogCorrelation) && ...
            eogCorrelation >= options.EOGAssociationThreshold;

        if isFlat
            decision = "Removed: flatline";
        elseif isCorrelationFlagged && isProtected && eogAssociated
            decision = "Retained: protected; EOG-associated";
        elseif isCorrelationFlagged && isProtected
            decision = "Retained: protected; inspect manually";
        elseif isCorrelationFlagged
            decision = "Removed: low robust correlation";
        else
            decision = "Retained";
        end

        newRow = struct;
        newRow.TriadCode = string(triadCode);
        newRow.Participant = recording;
        newRow.InputFile = string(setFiles{recording});
        newRow.ChannelLabel = channelLabel;
        newRow.IsProtectedFrontal = isProtected;
        newRow.FlatlineFlagged = isFlat;
        newRow.CorrelationFlagged = isCorrelationFlagged;
        newRow.MaxAbsEOGCorrelation = eogCorrelation;
        newRow.EOGAssociated = eogAssociated;
        newRow.Removed = isRemoved;
        newRow.Decision = decision;

        channelRows(end + 1) = newRow; %#ok<AGROW>
    end


    %% Remove final bad-channel set from the complete dataset

    if ~isempty(finalRemovedLabels)
        EEG = pop_select( ...
            EEG, 'nochannel', cellstr(finalRemovedLabels));
    end

    EEG = eeg_checkset(EEG, 'eventconsistency');


    %% Run conservative ASR on retained EEG channels only

    retainedGroups = classifyChannels( ...
        EEG, options.EOGLabels, options.TriggerLabels);

    if isempty(retainedGroups.eegIndices)
        error( ...
            'clean_triad_asr:NoEEGChannelsAfterRejection', ...
            'No EEG channels remain after bad-channel rejection in recording %d.', ...
            recording);
    end

    asrInput = pop_select( ...
        EEG, 'channel', retainedGroups.eegIndices);

    dataBeforeASR = double(asrInput.data);

    asrOutput = clean_asr( ...
        asrInput, ...
        options.ASRBurstCriterion, ...
        [], ...                         % automatic window length
        [], ...                         % automatic processing step size
        options.ASRMaxDimensions, ...
        options.ASRReferenceMaxBadChannels, ...
        options.ASRReferenceTolerances, ...
        options.ASRReferenceWindowLength, ...
        false, ...                      % do not use GPU by default
        options.ASRUseRiemannian, ...
        options.ASRMaxMemoryMB);

    if asrOutput.pnts ~= EEG.pnts
        error( ...
            'clean_triad_asr:ASRChangedLength', ...
            ['ASR unexpectedly changed the number of samples in ' ...
             'recording %d.'], ...
            recording);
    end

    asrDifference = abs(double(asrOutput.data) - dataBeforeASR);

    asrChangedMasks(recording, :) = ...
        any(asrDifference > options.ASRChangeTolerance, 1);

    asrChangedChannelSamples(recording) = ...
        nnz(asrDifference > options.ASRChangeTolerance);

    EEG.data(retainedGroups.eegIndices, :) = asrOutput.data;


    %% Identify severe residual periods after ASR

    windowGroups = classifyChannels( ...
        EEG, options.EOGLabels, options.TriggerLabels);

    windowLabels = windowGroups.labels(windowGroups.eegIndices);

    if options.ExcludeProtectedFromWindows
        protectedWindowLabels = intersectLabels( ...
            windowLabels, options.ProtectedFrontalLabels);

        detectorLabels = setdiffLabels( ...
            windowLabels, protectedWindowLabels);
    else
        detectorLabels = windowLabels;
    end

    if numel(detectorLabels) < 4
        error( ...
            'clean_triad_asr:TooFewWindowChannels', ...
            ['Fewer than four EEG channels remain for residual-window ' ...
             'detection in recording %d.'], ...
            recording);
    end

    detectorIndices = labelsToIndices( ...
        windowGroups.labels, detectorLabels);

    windowInput = pop_select( ...
        EEG, 'channel', detectorIndices);

    [~, individualKeepMask] = clean_windows( ...
        windowInput, ...
        options.WindowCriterion, ...
        options.WindowTolerances, ...
        options.WindowLength, ...
        options.WindowOverlap);

    individualKeepMask = logical(individualKeepMask(:)');

    if numel(individualKeepMask) ~= originalPointCount
        error( ...
            'clean_triad_asr:WindowMaskLengthMismatch', ...
            ['Residual-window mask length for recording %d is %d, ' ...
             'but %d samples were expected.'], ...
            recording, numel(individualKeepMask), originalPointCount);
    end

    participantBadMasks(recording, :) = ~individualKeepMask;


    %% Store participant-specific metadata before shared rejection

    EEG.etc.triad_asr_cleaning.function = mfilename;
    EEG.etc.triad_asr_cleaning.date = datestr(now, 30);
    EEG.etc.triad_asr_cleaning.stage = ...
        'ASR complete; shared temporal rejection pending';
    EEG.etc.triad_asr_cleaning.originalChanlocs = ...
        originalChanlocs{recording};
    EEG.etc.triad_asr_cleaning.originalEEGLabels = ...
        cellstr(originalEEGLabels);
    EEG.etc.triad_asr_cleaning.removedEEGLabels = ...
        removedChannelLabels{recording};
    EEG.etc.triad_asr_cleaning.protectedCorrelationFailuresRetained = ...
        protectedRetainedLabels{recording};
    EEG.etc.triad_asr_cleaning.highpassHz = options.HighpassHz;
    EEG.etc.triad_asr_cleaning.lineNoiseRemoval = false;
    EEG.etc.triad_asr_cleaning.onlineReferenceAssumption = ...
        options.OnlineReferenceDescription;
    EEG.etc.triad_asr_cleaning.referenceChannelRestored = false;
    EEG.etc.triad_asr_cleaning.asrBurstCriterion = ...
        options.ASRBurstCriterion;
    EEG.etc.triad_asr_cleaning.windowCriterion = ...
        options.WindowCriterion;
    EEG.etc.triad_asr_cleaning.windowTolerances = ...
        options.WindowTolerances;

    EEGclean{recording} = EEG;
end


%% Construct the shared triad mask

sharedBadMask = any(participantBadMasks, 1);
sharedKeepMask = ~sharedBadMask;

if ~any(sharedKeepMask)
    error( ...
        'clean_triad_asr:AllDataRejected', ...
        'The union of participant bad-period masks rejects all samples.');
end

sharedRemovedIntervals = maskToIntervals(sharedBadMask);
sharedRetainedIntervals = maskToIntervals(sharedKeepMask);


%% Build shared-interval QC table in original sample coordinates

intervalTable = buildIntervalTable( ...
    triadCode, ...
    sharedRemovedIntervals, ...
    participantBadMasks, ...
    samplingRate);


%% Apply exactly the same retained intervals to all recordings

outputFiles = strings(3, 1);
finalEventCounts = zeros(1, 3);

for recording = 1:3

    EEG = EEGclean{recording};

    if any(sharedBadMask)
        EEG = pop_select( ...
            EEG, 'point', sharedRetainedIntervals);
    end

    EEG = eeg_checkset(EEG, 'eventconsistency');

    EEG.etc.triad_asr_cleaning.stage = ...
        'ASR complete; shared temporal rejection applied';
    EEG.etc.triad_asr_cleaning.sharedSamplesRemoved = ...
        nnz(sharedBadMask);
    EEG.etc.triad_asr_cleaning.sharedPercentRemoved = ...
        100 * nnz(sharedBadMask) / originalPointCount;
    EEG.etc.triad_asr_cleaning.finalPointCount = EEG.pnts;
    EEG.etc.triad_asr_cleaning.sharedRemovedIntervalsOriginalSamples = ...
        sharedRemovedIntervals;
    EEG.etc.triad_asr_cleaning.triggerFiltered = false;
    EEG.etc.triad_asr_cleaning.rereferenced = false;
    EEG.etc.triad_asr_cleaning.interpolated = false;
    EEG.etc.triad_asr_cleaning.ICAperformed = false;

    finalEventCounts(recording) = numel(EEG.event);

    outputName = [inputNames{recording} '_asr.set'];
    outputFiles(recording) = string(fullfile(outputDir, outputName));

    EEG.setname = [inputNames{recording} '_asr'];

    if options.SaveOutput
        EEG = pop_saveset( ...
            EEG, ...
            'filename', outputName, ...
            'filepath', outputDir);
    end

    EEGclean{recording} = EEG;
end


%% Verify exact final temporal and marker correspondence

finalPointCounts = cellfun(@(x) double(x.pnts), EEGclean);

if any(finalPointCounts ~= finalPointCounts(1))
    error( ...
        'clean_triad_asr:FinalPointMismatch', ...
        'Final sample counts are not identical across the triad.');
end

validateComparableEvents(EEGclean, options.IgnoreEventTypes, 'after cleaning');

finalMarkers = extractComparableEvents( ...
    EEGclean{1}, options.IgnoreEventTypes);


%% Create participant-level table

participantRows = repmat(struct( ...
    'TriadCode', "", ...
    'Participant', NaN, ...
    'InputFile', "", ...
    'OutputFile', "", ...
    'SamplingRateHz', NaN, ...
    'OriginalSamples', NaN, ...
    'OriginalDurationSeconds', NaN, ...
    'OriginalEEGChannels', NaN, ...
    'FilteredChannels', "", ...
    'RemovedEEGChannels', NaN, ...
    'RemovedEEGLabels', "", ...
    'ProtectedCorrelationFailuresRetained', NaN, ...
    'ProtectedRetainedLabels', "", ...
    'RetainedEEGChannelsBeforeSharedRejection', NaN, ...
    'ASRChangedSamples', NaN, ...
    'ASRChangedPercent', NaN, ...
    'ASRChangedChannelSamples', NaN, ...
    'IndividuallyFlaggedSamples', NaN, ...
    'IndividuallyFlaggedPercent', NaN, ...
    'SharedRemovedSamples', NaN, ...
    'SharedRemovedPercent', NaN, ...
    'FinalSamples', NaN, ...
    'FinalDurationSeconds', NaN, ...
    'EventsBefore', NaN, ...
    'EventsAfter', NaN), ...
    3, 1);

for recording = 1:3

    originalGroups = classifyChannelsFromChanlocs( ...
        originalChanlocs{recording}, ...
        options.EOGLabels, ...
        options.TriggerLabels);

    finalGroups = classifyChannels( ...
        EEGclean{recording}, ...
        options.EOGLabels, ...
        options.TriggerLabels);

    participantRows(recording).TriadCode = string(triadCode);
    participantRows(recording).Participant = recording;
    participantRows(recording).InputFile = string(setFiles{recording});
    participantRows(recording).OutputFile = outputFiles(recording);
    participantRows(recording).SamplingRateHz = samplingRate;
    participantRows(recording).OriginalSamples = originalPointCount;
    participantRows(recording).OriginalDurationSeconds = ...
        (originalPointCount - 1) / samplingRate;
    participantRows(recording).OriginalEEGChannels = ...
        numel(originalGroups.eegIndices);
    participantRows(recording).FilteredChannels = ...
        strjoin(string(filteredChannelLabels{recording}), '; ');
    participantRows(recording).RemovedEEGChannels = ...
        numel(removedChannelLabels{recording});
    participantRows(recording).RemovedEEGLabels = ...
        strjoin(string(removedChannelLabels{recording}), '; ');
    participantRows(recording).ProtectedCorrelationFailuresRetained = ...
        numel(protectedRetainedLabels{recording});
    participantRows(recording).ProtectedRetainedLabels = ...
        strjoin(string(protectedRetainedLabels{recording}), '; ');
    participantRows(recording).RetainedEEGChannelsBeforeSharedRejection = ...
        numel(finalGroups.eegIndices);
    participantRows(recording).ASRChangedSamples = ...
        nnz(asrChangedMasks(recording, :));
    participantRows(recording).ASRChangedPercent = ...
        100 * nnz(asrChangedMasks(recording, :)) / originalPointCount;
    participantRows(recording).ASRChangedChannelSamples = ...
        asrChangedChannelSamples(recording);
    participantRows(recording).IndividuallyFlaggedSamples = ...
        nnz(participantBadMasks(recording, :));
    participantRows(recording).IndividuallyFlaggedPercent = ...
        100 * nnz(participantBadMasks(recording, :)) / originalPointCount;
    participantRows(recording).SharedRemovedSamples = ...
        nnz(sharedBadMask);
    participantRows(recording).SharedRemovedPercent = ...
        100 * nnz(sharedBadMask) / originalPointCount;
    participantRows(recording).FinalSamples = ...
        EEGclean{recording}.pnts;
    participantRows(recording).FinalDurationSeconds = ...
        (EEGclean{recording}.pnts - 1) / samplingRate;
    participantRows(recording).EventsBefore = ...
        originalEventCounts(recording);
    participantRows(recording).EventsAfter = ...
        finalEventCounts(recording);
end

participantTable = struct2table(participantRows);
channelTable = struct2table(channelRows);


%% Create triad-level summary

sharedSamplesRemoved = nnz(sharedBadMask);
sharedPercentRemoved = 100 * sharedSamplesRemoved / originalPointCount;

triadSummary = table( ...
    string(triadCode), ...
    samplingRate, ...
    originalPointCount, ...
    sharedSamplesRemoved, ...
    sharedPercentRemoved, ...
    finalPointCounts(1), ...
    (finalPointCounts(1) - 1) / samplingRate, ...
    size(sharedRemovedIntervals, 1), ...
    numel(finalMarkers.types), ...
    true, ...
    true, ...
    options.HighpassHz, ...
    options.ASRBurstCriterion, ...
    options.WindowCriterion, ...
    string(options.OnlineReferenceDescription), ...
    false, ...
    'VariableNames', { ...
        'TriadCode', ...
        'SamplingRateHz', ...
        'OriginalSamples', ...
        'SharedRemovedSamples', ...
        'SharedRemovedPercent', ...
        'FinalSamples', ...
        'FinalDurationSeconds', ...
        'SharedRemovedIntervals', ...
        'FinalExperimentalMarkerCount', ...
        'IdenticalFinalSampleCounts', ...
        'IdenticalFinalMarkers', ...
        'HighpassHz', ...
        'ASRBurstCriterion', ...
        'WindowCriterion', ...
        'OnlineReferenceAssumption', ...
        'ReferenceChannelRestored'});


%% Save QC files

if options.SaveOutput

    reportBase = sprintf('%s_asr_qc', triadCode);
    excelFile = fullfile(outputDir, [reportBase '.xlsx']);
    matlabFile = fullfile(outputDir, [reportBase '.mat']);

    if isfile(excelFile)
        delete(excelFile);
    end

    writetable(participantTable, excelFile, 'Sheet', 'Participants');
    writetable(channelTable, excelFile, 'Sheet', 'Channels');

    if isempty(intervalTable)
        noIntervalsTable = table( ...
            "No shared intervals were removed", ...
            'VariableNames', {'Message'});
        writetable(noIntervalsTable, excelFile, 'Sheet', 'Removed intervals');
    else
        writetable(intervalTable, excelFile, 'Sheet', 'Removed intervals');
    end

    writetable(triadSummary, excelFile, 'Sheet', 'Triad summary');

    qcMasks = struct;
    qcMasks.asrChangedMasks = asrChangedMasks;
    qcMasks.participantBadMasks = participantBadMasks;
    qcMasks.sharedBadMask = sharedBadMask;
    qcMasks.sharedKeepMask = sharedKeepMask;
    qcMasks.sharedRemovedIntervals = sharedRemovedIntervals;
    qcMasks.sharedRetainedIntervals = sharedRetainedIntervals;

    save( ...
        matlabFile, ...
        'participantTable', ...
        'intervalTable', ...
        'channelTable', ...
        'triadSummary', ...
        'qcMasks', ...
        'options', ...
        '-v7.3');
end


%% Print main result

fprintf('\nTriad ASR cleaning completed\n');
fprintf('----------------------------\n');
fprintf('Triad:                    %s\n', triadCode);
fprintf('Original samples:         %d\n', originalPointCount);
fprintf('Shared samples removed:   %d (%.3f%%)\n', ...
    sharedSamplesRemoved, sharedPercentRemoved);
fprintf('Final samples:            %d\n', finalPointCounts(1));
fprintf('Bad EEG channels removed: %d, %d, %d\n', ...
    numel(removedChannelLabels{1}), ...
    numel(removedChannelLabels{2}), ...
    numel(removedChannelLabels{3}));
fprintf('Exact shared time axis:   YES\n');
fprintf('Exact marker alignment:   YES\n');
fprintf('Rereferenced:             NO\n');
fprintf('Interpolated:             NO\n');
fprintf('ICA performed:            NO\n');

if options.SaveOutput
    fprintf('Output folder:\n%s\n\n', outputDir);
else
    fprintf('Outputs were not saved.\n\n');
end

end


%% ========================================================================
function EEG = filterSelectedChannels(EEG, channelIndices, highpassHz)
% High-pass filter selected channels without altering unselected channels.

if isempty(channelIndices)
    return;
end

filteredSubset = pop_select( ...
    EEG, 'channel', channelIndices);

filteredSubset = pop_eegfiltnew( ...
    filteredSubset, ...
    'locutoff', highpassHz, ...
    'plotfreqz', 0);

if filteredSubset.pnts ~= EEG.pnts
    error( ...
        'clean_triad_asr:FilterChangedLength', ...
        'High-pass filtering unexpectedly changed the number of samples.');
end

EEG.data(channelIndices, :) = filteredSubset.data;
EEG = eeg_checkset(EEG);

end


%% ========================================================================
function groups = classifyChannels(EEG, eogLabels, triggerLabels)
% Identify EEG, EOG, and trigger channels from labels and channel types.

groups = classifyChannelsFromChanlocs( ...
    EEG.chanlocs, eogLabels, triggerLabels);

end


%% ========================================================================
function groups = classifyChannelsFromChanlocs(chanlocs, eogLabels, triggerLabels)
% Identify channel groups from an EEGLAB chanlocs structure.

labels = string({chanlocs.labels});
labels = strtrim(labels);

channelTypes = repmat("", size(labels));

if isfield(chanlocs, 'type')
    for channelIndex = 1:numel(chanlocs)
        if ~isempty(chanlocs(channelIndex).type)
            channelTypes(channelIndex) = lower(strtrim( ...
                string(chanlocs(channelIndex).type)));
        end
    end
end

eogKeys = lower(strtrim(string(eogLabels)));
triggerKeys = lower(strtrim(string(triggerLabels)));
labelKeys = lower(labels);

isEOG = ismember(labelKeys, eogKeys) | contains(channelTypes, 'eog');
isTrigger = ismember(labelKeys, triggerKeys) | ...
    contains(channelTypes, 'trig') | ...
    contains(channelTypes, 'stim');

isEOG = isEOG & ~isTrigger;
isEEG = ~(isEOG | isTrigger);

groups.labels = labels;
groups.types = channelTypes;
groups.eegIndices = find(isEEG);
groups.eogIndices = find(isEOG);
groups.triggerIndices = find(isTrigger);

end


%% ========================================================================
function correlationTable = calculateProtectedEOGCorrelation( ...
    EEG, protectedLabels, eogIndices)
% Calculate maximum absolute Pearson correlation with any EOG channel.

if isempty(protectedLabels)
    correlationTable = table( ...
        strings(0, 1), zeros(0, 1), ...
        'VariableNames', {'ChannelLabel', 'MaxAbsEOGCorrelation'});
    return;
end

allLabels = string({EEG.chanlocs.labels});
protectedIndices = labelsToIndices(allLabels, protectedLabels);

correlations = nan(numel(protectedIndices), 1);

if ~isempty(eogIndices)

    maximumSamples = 200000;
    step = max(1, floor(EEG.pnts / maximumSamples));
    sampleIndices = 1:step:EEG.pnts;

    eogData = double(EEG.data(eogIndices, sampleIndices));

    for protectedIndex = 1:numel(protectedIndices)

        eegData = double(EEG.data( ...
            protectedIndices(protectedIndex), sampleIndices));

        currentCorrelations = nan(1, size(eogData, 1));

        for eogIndex = 1:size(eogData, 1)
            currentCorrelations(eogIndex) = abs( ...
                pearsonCorrelation(eegData, eogData(eogIndex, :)));
        end

        if any(isfinite(currentCorrelations))
            correlations(protectedIndex) = ...
                max(currentCorrelations, [], 'omitnan');
        end
    end
end

correlationTable = table( ...
    allLabels(protectedIndices)', ...
    correlations, ...
    'VariableNames', ...
    {'ChannelLabel', 'MaxAbsEOGCorrelation'});

end


%% ========================================================================
function r = pearsonCorrelation(x, y)
% Toolbox-independent Pearson correlation.

x = double(x(:));
y = double(y(:));

valid = isfinite(x) & isfinite(y);
x = x(valid);
y = y(valid);

if numel(x) < 3
    r = NaN;
    return;
end

x = x - mean(x);
y = y - mean(y);

denominator = sqrt(sum(x .^ 2) * sum(y .^ 2));

if denominator <= eps
    r = NaN;
else
    r = sum(x .* y) / denominator;
end

end


%% ========================================================================
function value = lookupCorrelation(correlationTable, channelLabel)
% Return the saved EOG association for one protected channel.

value = NaN;

if isempty(correlationTable)
    return;
end

match = find(strcmpi( ...
    correlationTable.ChannelLabel, string(channelLabel)), 1);

if ~isempty(match)
    value = correlationTable.MaxAbsEOGCorrelation(match);
end

end


%% ========================================================================
function validateComparableEvents(EEGcell, ignoreEventTypes, stageText)
% Confirm identical experimental event types and latencies across datasets.

referenceEvents = extractComparableEvents( ...
    EEGcell{1}, ignoreEventTypes);

for recording = 2:3

    currentEvents = extractComparableEvents( ...
        EEGcell{recording}, ignoreEventTypes);

    sameCount = numel(currentEvents.keys) == ...
        numel(referenceEvents.keys);

    if sameCount
        sameTypes = all(strcmp( ...
            currentEvents.keys(:), referenceEvents.keys(:)));
        sameLatencies = all(abs( ...
            currentEvents.latencies(:) - ...
            referenceEvents.latencies(:)) < 1e-6);
    else
        sameTypes = false;
        sameLatencies = false;
    end

    if ~(sameCount && sameTypes && sameLatencies)
        error( ...
            'clean_triad_asr:EventMismatch', ...
            ['Experimental events are not identical across the triad ' ...
             '%s. Recording %d differs from recording 1.'], ...
            stageText, recording);
    end
end

end


%% ========================================================================
function events = extractComparableEvents(EEG, ignoreEventTypes)
% Extract non-ignored events in chronological order.

ignoreKeys = lower(strtrim(string(ignoreEventTypes)));

types = strings(0, 1);
keys = strings(0, 1);
latencies = zeros(0, 1);

for eventIndex = 1:numel(EEG.event)

    eventType = eventTypeToText(EEG.event(eventIndex).type);
    eventKey = lower(strtrim(string(eventType)));

    if ismember(eventKey, ignoreKeys)
        continue;
    end

    if isempty(EEG.event(eventIndex).latency) || ...
            ~isfinite(EEG.event(eventIndex).latency)
        continue;
    end

    types(end + 1, 1) = string(eventType); %#ok<AGROW>
    keys(end + 1, 1) = eventKey; %#ok<AGROW>
    latencies(end + 1, 1) = ...
        double(EEG.event(eventIndex).latency); %#ok<AGROW>
end

[latencies, order] = sort(latencies);

events.types = types(order);
events.keys = keys(order);
events.latencies = latencies;

end


%% ========================================================================
function intervals = maskToIntervals(mask)
% Convert a logical mask to inclusive [start end] sample intervals.

mask = logical(mask(:)');

if isempty(mask) || ~any(mask)
    intervals = zeros(0, 2);
    return;
end

edges = diff([false mask false]);
starts = find(edges == 1);
ends = find(edges == -1) - 1;
intervals = [starts(:) ends(:)];

end


%% ========================================================================
function intervalTable = buildIntervalTable( ...
    triadCode, sharedIntervals, participantBadMasks, samplingRate)
% Create one QC row per shared rejected interval.

numberOfIntervals = size(sharedIntervals, 1);

if numberOfIntervals == 0
    intervalTable = table();
    return;
end

intervalIndex = (1:numberOfIntervals)';
startSample = sharedIntervals(:, 1);
endSample = sharedIntervals(:, 2);
sampleCount = endSample - startSample + 1;
startSeconds = (startSample - 1) / samplingRate;
endSeconds = (endSample - 1) / samplingRate;
durationSeconds = sampleCount / samplingRate;

flaggedBy1 = false(numberOfIntervals, 1);
flaggedBy2 = false(numberOfIntervals, 1);
flaggedBy3 = false(numberOfIntervals, 1);
samplesFlaggedBy1 = zeros(numberOfIntervals, 1);
samplesFlaggedBy2 = zeros(numberOfIntervals, 1);
samplesFlaggedBy3 = zeros(numberOfIntervals, 1);

for interval = 1:numberOfIntervals
    intervalSamples = startSample(interval):endSample(interval);

    samplesFlaggedBy1(interval) = ...
        nnz(participantBadMasks(1, intervalSamples));
    samplesFlaggedBy2(interval) = ...
        nnz(participantBadMasks(2, intervalSamples));
    samplesFlaggedBy3(interval) = ...
        nnz(participantBadMasks(3, intervalSamples));

    flaggedBy1(interval) = samplesFlaggedBy1(interval) > 0;
    flaggedBy2(interval) = samplesFlaggedBy2(interval) > 0;
    flaggedBy3(interval) = samplesFlaggedBy3(interval) > 0;
end

intervalTable = table( ...
    repmat(string(triadCode), numberOfIntervals, 1), ...
    intervalIndex, ...
    startSample, ...
    endSample, ...
    sampleCount, ...
    startSeconds, ...
    endSeconds, ...
    durationSeconds, ...
    flaggedBy1, ...
    flaggedBy2, ...
    flaggedBy3, ...
    samplesFlaggedBy1, ...
    samplesFlaggedBy2, ...
    samplesFlaggedBy3, ...
    'VariableNames', { ...
        'TriadCode', ...
        'IntervalIndex', ...
        'StartSampleOriginal', ...
        'EndSampleOriginal', ...
        'SampleCount', ...
        'StartSecondsOriginal', ...
        'EndSecondsOriginal', ...
        'DurationSeconds', ...
        'FlaggedByParticipant1', ...
        'FlaggedByParticipant2', ...
        'FlaggedByParticipant3', ...
        'SamplesFlaggedByParticipant1', ...
        'SamplesFlaggedByParticipant2', ...
        'SamplesFlaggedByParticipant3'});

end


%% ========================================================================
function indices = labelsToIndices(allLabels, requestedLabels)
% Resolve labels case-insensitively and retain requested order.

allLabels = string(allLabels);
requestedLabels = string(requestedLabels);
indices = zeros(1, numel(requestedLabels));

for labelIndex = 1:numel(requestedLabels)
    match = find(strcmpi(allLabels, requestedLabels(labelIndex)), 1);

    if isempty(match)
        error( ...
            'clean_triad_asr:ChannelLabelNotFound', ...
            'Channel label not found: %s', ...
            requestedLabels(labelIndex));
    end

    indices(labelIndex) = match;
end

end


%% ========================================================================
function result = setdiffLabels(firstLabels, secondLabels)
% Case-insensitive stable set difference for channel labels.

firstLabels = string(firstLabels(:));
secondKeys = lower(strtrim(string(secondLabels(:))));
firstKeys = lower(strtrim(firstLabels));
result = firstLabels(~ismember(firstKeys, secondKeys));

end


%% ========================================================================
function result = intersectLabels(firstLabels, secondLabels)
% Case-insensitive stable intersection for channel labels.

firstLabels = string(firstLabels(:));
secondKeys = lower(strtrim(string(secondLabels(:))));
firstKeys = lower(strtrim(firstLabels));
result = firstLabels(ismember(firstKeys, secondKeys));

end


%% ========================================================================
function result = containsLabel(labelList, targetLabel)
% Case-insensitive membership test for one label.

result = any(strcmpi(string(labelList), string(targetLabel)));

end


%% ========================================================================
function triadCode = inferTriadCode(inputNames)
% Infer a shared numerical triad identifier from input dataset names.

codes = strings(3, 1);

for recording = 1:3
    token = regexp( ...
        inputNames{recording}, ...
        '(\d+)_([123])', ...
        'tokens', ...
        'once');

    if ~isempty(token)
        codes(recording) = string(token{1});
    end
end

nonEmptyCodes = codes(codes ~= "");

if numel(nonEmptyCodes) == 3 && numel(unique(nonEmptyCodes)) == 1
    triadCode = char(nonEmptyCodes(1));
else
    triadCode = 'triad';
end

end


%% ========================================================================
function text = eventTypeToText(eventType)
% Convert an EEGLAB event type to a character vector.

if ischar(eventType)
    text = strtrim(eventType);
elseif isstring(eventType)
    text = strtrim(char(eventType));
elseif isnumeric(eventType) || islogical(eventType)
    if isscalar(eventType)
        text = num2str(eventType);
    else
        text = mat2str(eventType);
    end
elseif iscell(eventType) && numel(eventType) == 1
    text = eventTypeToText(eventType{1});
else
    text = char(string(eventType));
end

end
