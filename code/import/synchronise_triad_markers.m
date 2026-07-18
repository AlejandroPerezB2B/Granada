function [EEGsync, syncTable, summary] = ...
    synchronise_triad_markers(setFile1, setFile2, setFile3, varargin)
% SYNCHRONISE_TRIAD_MARKERS Synchronise markers in three EEG recordings.
%
% The function:
%
%   1. Loads three continuous EEGLAB .set datasets.
%   2. Aligns their marker sequences.
%   3. Identifies and reconstructs markers missing from any recording.
%   4. Defines one common marker timeline.
%   5. Cuts each recording so that it starts exactly 2 seconds before the
%      first common marker.
%   6. Assigns exactly the same marker latencies to all three recordings.
%   7. Cuts each recording exactly 10 seconds after the last marker.
%   8. Rebuilds EEG.urevent and EEG.event.urevent.
%   9. Saves the datasets with "_sync" appended to their filenames.
%
% LATENCY SELECTION
%
% For each marker, the function calculates its latency relative to the first
% marker in each recording where that marker was originally present.
%
% The common latency is the median of those relative latencies:
%
%   - Three available recordings: use the middle value.
%   - Two available recordings: use their midpoint.
%   - One available recording: use that recording.
%
% The resulting value is rounded to the nearest sample.
%
% INPUTS
%
%   setFile1, setFile2, setFile3
%       Paths to the three continuous EEGLAB .set datasets.
%
% OPTIONAL INPUT
%
%   'IgnoreTypes'
%       Event types that should not be considered experimental markers.
%
%       Default:
%           {'boundary'}
%
%   'OutputDir'
%       Directory in which the synchronised datasets will be saved.
%
%       Default:
%           ''
%
%       When empty, each dataset is saved beside its original file.
%
% OUTPUTS
%
%   EEGsync
%       Cell array containing the three synchronised EEGLAB datasets.
%
%   syncTable
%       Table containing the common marker sequence, original marker
%       presence, relative timing, and final common latency.
%
%   summary
%       Structure containing the main synchronisation results.
%
% EXAMPLE
%
%   [EEGsync, syncTable, summary] = ...
%       synchronise_triad_markers( ...
%           '303_1_raw.set', ...
%           '303_2_raw.set', ...
%           '303_3_raw.set');
%
% AUTHORS
%
%   Alejandro Pérez
%   Celia Sissi Stijsiger (@CeliaSissi)
%
% -------------------------------------------------------------------------


%% Parse inputs

parser = inputParser;

addRequired(parser, 'setFile1');
addRequired(parser, 'setFile2');
addRequired(parser, 'setFile3');

addParameter(parser, 'IgnoreTypes', {'boundary'});
addParameter(parser, 'OutputDir', '');

parse(parser, setFile1, setFile2, setFile3, varargin{:});

options = parser.Results;

setFiles = {
    char(setFile1)
    char(setFile2)
    char(setFile3)
    };


%% Check EEGLAB availability

if exist('pop_loadset', 'file') ~= 2

    error( ...
        'synchronise_triad_markers:EEGLABNotFound', ...
        'Start EEGLAB before running this function.');

end


%% Load the three datasets

EEGsync = cell(1, 3);
markers = cell(1, 3);

inputFolders = cell(3, 1);
inputNames = cell(3, 1);

for recording = 1:3

    if ~isfile(setFiles{recording})

        error( ...
            'synchronise_triad_markers:FileNotFound', ...
            'Dataset not found:\n%s', ...
            setFiles{recording});

    end

    [inputFolders{recording}, ...
        inputNames{recording}, extension] = ...
        fileparts(setFiles{recording});

    if isempty(inputFolders{recording})
        inputFolders{recording} = pwd;
    end

    EEGsync{recording} = pop_loadset( ...
        'filename', [inputNames{recording} extension], ...
        'filepath', inputFolders{recording});

    EEGsync{recording} = eeg_checkset( ...
        EEGsync{recording}, ...
        'eventconsistency');

    if EEGsync{recording}.trials ~= 1

        error( ...
            'synchronise_triad_markers:EpochedDataset', ...
            ['Recording %d is epoched. This function must be run on ' ...
             'continuous data.'], ...
            recording);

    end

    markers{recording} = extractMarkers( ...
        EEGsync{recording}, ...
        options.IgnoreTypes);

end


%% Require the same sampling rate

samplingRates = cellfun( ...
    @(EEG) EEG.srate, ...
    EEGsync);

if any(abs(samplingRates - samplingRates(1)) > 1e-10)

    error( ...
        'synchronise_triad_markers:DifferentSamplingRates', ...
        ['The recordings have different sampling rates:\n' ...
         '%.6f, %.6f and %.6f Hz.\n\n' ...
         'Exact sample-level synchronisation requires the same rate.'], ...
        samplingRates(1), ...
        samplingRates(2), ...
        samplingRates(3));

end

samplingRate = samplingRates(1);


%% Construct the complete common marker sequence

% markerMap has one row per common marker and one column per recording.
%
% A numerical value identifies the original marker position.
% NaN means that the marker was missing from that recording.

[masterTypes, masterKeys, markerMap] = ...
    constructMasterSequence(markers);

numberOfMarkers = numel(masterTypes);

originallyPresent = ~isnan(markerMap);


%% Place the original marker latencies into the common sequence

rawLatencies = nan(numberOfMarkers, 3);

for recording = 1:3

    presentPositions = find( ...
        originallyPresent(:, recording));

    originalIndices = markerMap( ...
        presentPositions, ...
        recording);

    rawLatencies(presentPositions, recording) = ...
        markers{recording}.latencies(originalIndices);

end


%% Estimate latencies for markers that were missing

% These estimates are used to determine the location of the first marker
% and to calculate relative timing. Original events are not moved here.

filledLatencies = rawLatencies;

for recording = 1:3

    workingLatencies = filledLatencies(:, recording);

    for markerIndex = 1:numberOfMarkers

        if isfinite(workingLatencies(markerIndex))
            continue;
        end

        estimatedLatency = estimateMissingLatency( ...
            markerIndex, ...
            recording, ...
            workingLatencies, ...
            rawLatencies);

        estimatedLatency = constrainToNeighbours( ...
            estimatedLatency, ...
            markerIndex, ...
            workingLatencies, ...
            EEGsync{recording}.pnts);

        workingLatencies(markerIndex) = ...
            estimatedLatency;

    end

    filledLatencies(:, recording) = ...
        workingLatencies;

end


%% Calculate relative marker timing in each recording

% The different absolute recording start times are removed by subtracting
% the latency of the first common marker.

relativeLatencies = ...
    filledLatencies - filledLatencies(1, :);


%% Select the common timeline

consensusOffsets = zeros(numberOfMarkers, 1);

for markerIndex = 1:numberOfMarkers

    % Prefer only recordings in which this marker was genuinely recorded.
    availableRecordings = find( ...
        originallyPresent(markerIndex, :));

    % This fallback should normally never be required.
    if isempty(availableRecordings)
        availableRecordings = 1:3;
    end

    consensusOffsets(markerIndex) = round( ...
        median(relativeLatencies( ...
            markerIndex, ...
            availableRecordings)));

end


% The first marker defines time zero in the common marker sequence.
consensusOffsets(1) = 0;


% Ensure chronological ordering after rounding to whole samples.
for markerIndex = 2:numberOfMarkers

    if consensusOffsets(markerIndex) <= ...
            consensusOffsets(markerIndex - 1)

        consensusOffsets(markerIndex) = ...
            consensusOffsets(markerIndex - 1) + 1;

    end

end


%% Define the exact output marker latencies

preMarkerSamples = round( ...
    2 * samplingRate);

postMarkerSamples = round( ...
    10 * samplingRate);


% Because EEGLAB latencies are one-based, a marker exactly 2 seconds after
% the first retained sample has latency 2*srate + 1.
consensusLatencies = ...
    preMarkerSamples + 1 + consensusOffsets;


% All three output datasets will contain exactly this number of samples.
outputPointCount = ...
    consensusLatencies(end) + postMarkerSamples;


%% Trim and reconstruct each recording

outputFiles = cell(3, 1);

for recording = 1:3

    EEG = EEGsync{recording};


    %% Determine the raw-data segment to retain

    firstMarkerSample = round( ...
        filledLatencies(1, recording));

    startSample = ...
        firstMarkerSample - preMarkerSamples;

    endSample = ...
        startSample + outputPointCount - 1;


    if startSample < 1

        error( ...
            'synchronise_triad_markers:InsufficientDataBeforeFirstMarker', ...
            ['Recording %d does not contain two full seconds before ' ...
             'the first common marker.'], ...
            recording);

    end


    if endSample > EEG.pnts

        error( ...
            'synchronise_triad_markers:InsufficientDataAfterLastMarker', ...
            ['Recording %d does not contain enough data to retain ten ' ...
             'seconds after the final common marker.\n\n' ...
             'Required endpoint: %d\n' ...
             'Available endpoint: %d'], ...
            recording, ...
            endSample, ...
            EEG.pnts);

    end


    %% Retain the required continuous-data segment

    EEG = pop_select( ...
        EEG, ...
        'point', ...
        [startSample endSample]);


    %% Preserve only ignored events such as boundary events

    % All experimental markers will be reconstructed from the common
    % sequence, ensuring that their types and latencies are identical.

    eventTemplate = EEG.event(1);

    keepEvent = false( ...
        1, ...
        numel(EEG.event));

    ignoreKeys = lower( ...
        strtrim(string(options.IgnoreTypes)));

    for eventIndex = 1:numel(EEG.event)

        currentKey = lower(strtrim(string( ...
            eventTypeToText(EEG.event(eventIndex).type))));

        keepEvent(eventIndex) = ...
            ismember(currentKey, ignoreKeys);

    end

    EEG.event = EEG.event(keepEvent);


    %% Add the complete common marker sequence

    for markerIndex = 1:numberOfMarkers

        newEvent = createEvent( ...
            eventTemplate, ...
            masterTypes{markerIndex}, ...
            consensusLatencies(markerIndex));

        EEG.event(end + 1) = newEvent;

    end


    %% Sort events chronologically

    [~, eventOrder] = sort( ...
        [EEG.event.latency]);

    EEG.event = EEG.event(eventOrder);


    %% Rebuild urevent from the final event structure

    % Remove all previous links because event latencies and marker counts
    % have now changed.

    if isfield(EEG.event, 'urevent')
        EEG.event = rmfield(EEG.event, 'urevent');
    end

    EEG.urevent = [];

    EEG = eeg_checkset( ...
        EEG, ...
        'eventconsistency');

    EEG = eeg_checkset( ...
        EEG, ...
        'makeur');

    EEG = eeg_checkset( ...
        EEG, ...
        'checkur');


    %% Store synchronisation metadata

    EEG.etc.triad_synchronisation.function = ...
        mfilename;

    EEG.etc.triad_synchronisation.date = ...
        datestr(now, 30);

    EEG.etc.triad_synchronisation.firstMarkerType = ...
        masterTypes{1};

    EEG.etc.triad_synchronisation.firstMarkerLatency = ...
        consensusLatencies(1);

    EEG.etc.triad_synchronisation.lastMarkerType = ...
        masterTypes{end};

    EEG.etc.triad_synchronisation.lastMarkerLatency = ...
        consensusLatencies(end);

    EEG.etc.triad_synchronisation.secondsBeforeFirstMarker = ...
        2;

    EEG.etc.triad_synchronisation.secondsAfterLastMarker = ...
        10;

    EEG.etc.triad_synchronisation.markersInserted = ...
        sum(~originallyPresent(:, recording));

    EEG.etc.triad_synchronisation.latencyMethod = ...
        'Median relative latency across recordings';


    %% Verify marker identity and exact latency

    finalMarkers = extractMarkers( ...
        EEG, ...
        options.IgnoreTypes);

    sequenceMatches = ...
        numel(finalMarkers.keys) == numberOfMarkers && ...
        all(strcmp(finalMarkers.keys(:), masterKeys(:)));

    latencyMatches = ...
        numel(finalMarkers.latencies) == numberOfMarkers && ...
        isequal( ...
            finalMarkers.latencies(:), ...
            consensusLatencies(:));

    if ~sequenceMatches || ~latencyMatches

        error( ...
            'synchronise_triad_markers:VerificationFailed', ...
            ['Recording %d failed the final marker-sequence or latency ' ...
             'verification.'], ...
            recording);

    end


    %% Verify the urevent links

    for markerIndex = 1:numberOfMarkers

        eventIndex = finalMarkers.eventIndices(markerIndex);

        ureventIndex = ...
            EEG.event(eventIndex).urevent;

        if EEG.urevent(ureventIndex).latency ~= ...
                EEG.event(eventIndex).latency

            error( ...
                'synchronise_triad_markers:UreventMismatch', ...
                ['The urevent latency does not match the event latency ' ...
                 'for recording %d, marker %d.'], ...
                recording, ...
                markerIndex);

        end

    end


    %% Save with "_sync" appended to the original name

    if isempty(options.OutputDir)

        outputFolder = ...
            inputFolders{recording};

    else

        outputFolder = ...
            char(options.OutputDir);

        if ~isfolder(outputFolder)
            mkdir(outputFolder);
        end

    end

    outputName = [
        inputNames{recording} ...
        '_sync.set'
        ];

    EEG.setname = [
        inputNames{recording} ...
        '_sync'
        ];

    EEG = pop_saveset( ...
        EEG, ...
        'filename', outputName, ...
        'filepath', outputFolder);

    outputFiles{recording} = ...
        fullfile(outputFolder, outputName);

    EEGsync{recording} = EEG;

end


%% Create the synchronisation table

syncTable = table( ...
    (1:numberOfMarkers)', ...
    string(masterTypes), ...
    originallyPresent(:, 1), ...
    originallyPresent(:, 2), ...
    originallyPresent(:, 3), ...
    relativeLatencies(:, 1), ...
    relativeLatencies(:, 2), ...
    relativeLatencies(:, 3), ...
    consensusLatencies, ...
    consensusLatencies / samplingRate, ...
    'VariableNames', ...
    { ...
        'MarkerIndex', ...
        'MarkerType', ...
        'OriginallyPresent_1', ...
        'OriginallyPresent_2', ...
        'OriginallyPresent_3', ...
        'RelativeSamples_1', ...
        'RelativeSamples_2', ...
        'RelativeSamples_3', ...
        'FinalLatencySamples', ...
        'FinalLatencySeconds' ...
    });


%% Create the summary

summary.inputFiles = ...
    setFiles;

summary.outputFiles = ...
    outputFiles;

summary.samplingRate = ...
    samplingRate;

summary.originalMarkerCounts = [
    numel(markers{1}.types)
    numel(markers{2}.types)
    numel(markers{3}.types)
    ];

summary.finalMarkerCount = ...
    numberOfMarkers;

summary.insertedPerRecording = ...
    sum(~originallyPresent, 1)';

summary.firstMarkerType = ...
    masterTypes{1};

summary.firstMarkerLatencySamples = ...
    consensusLatencies(1);

summary.firstMarkerLatencySeconds = ...
    (consensusLatencies(1) - 1) / samplingRate;

summary.lastMarkerType = ...
    masterTypes{end};

summary.lastMarkerLatencySamples = ...
    consensusLatencies(end);

summary.outputDurationSeconds = ...
    (outputPointCount - 1) / samplingRate;

summary.exactlySynchronised = ...
    true;


%% Print the main result

fprintf('\nTriad marker synchronisation completed\n');
fprintf('--------------------------------------\n');

fprintf( ...
    'Original marker counts: %d, %d, %d\n', ...
    summary.originalMarkerCounts(1), ...
    summary.originalMarkerCounts(2), ...
    summary.originalMarkerCounts(3));

fprintf( ...
    'Final marker count:     %d\n', ...
    summary.finalMarkerCount);

fprintf( ...
    'Markers inserted:       %d, %d, %d\n', ...
    summary.insertedPerRecording(1), ...
    summary.insertedPerRecording(2), ...
    summary.insertedPerRecording(3));

fprintf( ...
    'First marker:           %s at %.3f seconds\n', ...
    summary.firstMarkerType, ...
    summary.firstMarkerLatencySeconds);

fprintf( ...
    'Exact shared latencies: YES\n');

fprintf( ...
    'Saved files:\n%s\n%s\n%s\n\n', ...
    outputFiles{1}, ...
    outputFiles{2}, ...
    outputFiles{3});

end


%% ========================================================================
function markers = extractMarkers(EEG, ignoreTypes)
% Extract experimental markers in chronological order.

if ischar(ignoreTypes)
    ignoreTypes = {ignoreTypes};
end

ignoreKeys = lower( ...
    strtrim(string(ignoreTypes)));

types = {};
keys = {};
latencies = [];
eventIndices = [];

for eventIndex = 1:numel(EEG.event)

    markerType = eventTypeToText( ...
        EEG.event(eventIndex).type);

    markerKey = lower(strtrim(markerType));

    if ismember(string(markerKey), ignoreKeys)
        continue;
    end

    if isempty(EEG.event(eventIndex).latency) || ...
            ~isfinite(EEG.event(eventIndex).latency)
        continue;
    end

    types{end + 1, 1} = markerType; %#ok<AGROW>
    keys{end + 1, 1} = markerKey; %#ok<AGROW>

    latencies(end + 1, 1) = ... %#ok<AGROW>
        double(EEG.event(eventIndex).latency);

    eventIndices(end + 1, 1) = ... %#ok<AGROW>
        eventIndex;

end

[latencies, order] = sort(latencies);

markers.types = types(order);
markers.keys = keys(order);
markers.latencies = latencies;
markers.eventIndices = eventIndices(order);

end


%% ========================================================================
function [masterTypes, masterKeys, markerMap] = ...
    constructMasterSequence(markers)
% Construct the ordered union of the three marker sequences.

markerCounts = cellfun( ...
    @(x) numel(x.keys), ...
    markers);

% Start with the recording containing the largest number of markers.
[~, baseRecording] = max(markerCounts);

mergeOrder = [
    baseRecording, ...
    setdiff(1:3, baseRecording, 'stable')
    ];

masterTypes = markers{baseRecording}.types;
masterKeys = markers{baseRecording}.keys;

markerMap = nan(numel(masterKeys), 3);

markerMap(:, baseRecording) = ...
    (1:numel(masterKeys))';


for orderIndex = 2:3

    recording = mergeOrder(orderIndex);

    [masterIndices, recordingIndices] = ...
        alignSequences( ...
            masterKeys, ...
            markers{recording}.keys);

    alignedLength = numel(masterIndices);

    newTypes = cell(alignedLength, 1);
    newKeys = cell(alignedLength, 1);
    newMap = nan(alignedLength, 3);

    for alignedIndex = 1:alignedLength

        if ~isnan(masterIndices(alignedIndex))

            oldIndex = ...
                masterIndices(alignedIndex);

            newTypes{alignedIndex} = ...
                masterTypes{oldIndex};

            newKeys{alignedIndex} = ...
                masterKeys{oldIndex};

            newMap(alignedIndex, :) = ...
                markerMap(oldIndex, :);

        else

            recordingIndex = ...
                recordingIndices(alignedIndex);

            newTypes{alignedIndex} = ...
                markers{recording}.types{recordingIndex};

            newKeys{alignedIndex} = ...
                markers{recording}.keys{recordingIndex};

        end

        if ~isnan(recordingIndices(alignedIndex))

            newMap(alignedIndex, recording) = ...
                recordingIndices(alignedIndex);

        end

    end

    masterTypes = newTypes;
    masterKeys = newKeys;
    markerMap = newMap;

end

end


%% ========================================================================
function [map1, map2] = alignSequences(sequence1, sequence2)
% Align two sequences using their longest common subsequence.
%
% A gap represents a marker missing from one recording.

number1 = numel(sequence1);
number2 = numel(sequence2);

score = zeros(number1 + 1, number2 + 1);

for index1 = 1:number1

    for index2 = 1:number2

        if strcmp(sequence1{index1}, sequence2{index2})

            score(index1 + 1, index2 + 1) = ...
                score(index1, index2) + 1;

        else

            score(index1 + 1, index2 + 1) = max( ...
                score(index1, index2 + 1), ...
                score(index1 + 1, index2));

        end

    end

end


index1 = number1;
index2 = number2;

map1 = [];
map2 = [];

while index1 > 0 || index2 > 0

    if index1 > 0 && ...
            index2 > 0 && ...
            strcmp(sequence1{index1}, sequence2{index2})

        map1(end + 1, 1) = index1; %#ok<AGROW>
        map2(end + 1, 1) = index2; %#ok<AGROW>

        index1 = index1 - 1;
        index2 = index2 - 1;

    elseif index1 > 0 && ...
            (index2 == 0 || ...
             score(index1, index2 + 1) >= ...
             score(index1 + 1, index2))

        map1(end + 1, 1) = index1; %#ok<AGROW>
        map2(end + 1, 1) = NaN; %#ok<AGROW>

        index1 = index1 - 1;

    else

        map1(end + 1, 1) = NaN; %#ok<AGROW>
        map2(end + 1, 1) = index2; %#ok<AGROW>

        index2 = index2 - 1;

    end

end

map1 = flipud(map1);
map2 = flipud(map2);

end


%% ========================================================================
function estimatedLatency = estimateMissingLatency( ...
    markerIndex, targetRecording, targetLatencies, allLatencies)
% Estimate a missing marker using neighbouring markers from donor recordings.

otherRecordings = ...
    setdiff(1:3, targetRecording);


%% Prefer the closest preceding marker

for previousIndex = markerIndex - 1:-1:1

    if ~isfinite(targetLatencies(previousIndex))
        continue;
    end

    donors = otherRecordings( ...
        isfinite(allLatencies(previousIndex, otherRecordings)) & ...
        isfinite(allLatencies(markerIndex, otherRecordings)));

    if isempty(donors)
        continue;
    end

    donorIntervals = ...
        allLatencies(markerIndex, donors) - ...
        allLatencies(previousIndex, donors);

    estimatedLatency = ...
        targetLatencies(previousIndex) + ...
        median(donorIntervals);

    estimatedLatency = round(estimatedLatency);

    return;

end


%% Use the closest following marker when the beginning is missing

for nextIndex = markerIndex + 1:size(allLatencies, 1)

    if ~isfinite(targetLatencies(nextIndex))
        continue;
    end

    donors = otherRecordings( ...
        isfinite(allLatencies(markerIndex, otherRecordings)) & ...
        isfinite(allLatencies(nextIndex, otherRecordings)));

    if isempty(donors)
        continue;
    end

    donorIntervals = ...
        allLatencies(nextIndex, donors) - ...
        allLatencies(markerIndex, donors);

    estimatedLatency = ...
        targetLatencies(nextIndex) - ...
        median(donorIntervals);

    estimatedLatency = round(estimatedLatency);

    return;

end


error( ...
    'synchronise_triad_markers:CannotEstimateMarker', ...
    ['No suitable temporal anchor was found for marker %d in ' ...
     'recording %d.'], ...
    markerIndex, ...
    targetRecording);

end


%% ========================================================================
function latency = constrainToNeighbours( ...
    latency, markerIndex, existingLatencies, numberOfSamples)
% Ensure that an estimated marker remains between neighbouring markers.

previousIndex = find( ...
    isfinite(existingLatencies(1:markerIndex - 1)), ...
    1, ...
    'last');

nextRelativeIndex = find( ...
    isfinite(existingLatencies(markerIndex + 1:end)), ...
    1, ...
    'first');


if isempty(previousIndex)
    minimumLatency = 1;
else
    minimumLatency = ...
        floor(existingLatencies(previousIndex)) + 1;
end


if isempty(nextRelativeIndex)

    maximumLatency = ...
        numberOfSamples;

else

    nextIndex = ...
        markerIndex + nextRelativeIndex;

    maximumLatency = ...
        ceil(existingLatencies(nextIndex)) - 1;

end


if minimumLatency > maximumLatency

    error( ...
        'synchronise_triad_markers:NoSpaceBetweenMarkers', ...
        ['No sample is available between the neighbouring markers at ' ...
         'marker position %d.'], ...
        markerIndex);

end


latency = round(latency);

latency = min( ...
    max(latency, minimumLatency), ...
    maximumLatency);

end


%% ========================================================================
function newEvent = createEvent(templateEvent, markerType, markerLatency)
% Create a clean event with the same fields as the existing event structure.

newEvent = templateEvent;

eventFields = fieldnames(newEvent);

for fieldIndex = 1:numel(eventFields)

    newEvent.(eventFields{fieldIndex}) = [];

end

newEvent.type = markerType;
newEvent.latency = markerLatency;

if isfield(newEvent, 'duration')
    newEvent.duration = 0;
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