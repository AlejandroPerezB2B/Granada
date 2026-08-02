function [EEGout, summaryTable, componentTable, rankTable] = ...
    run_ica_dipfit_iclabel(setFile, varargin)
% RUN_ICA_DIPFIT_ICLABEL Prepare one ASR-cleaned dataset for IC inspection.
%
% DIPFIT revision:
%   The standard MNI BEM files and the standard_1005-to-BEM coordinate
%   transform are now supplied explicitly to pop_dipfit_settings. This
%   removes the previous ambiguity in electrode/head-model coregistration.
%
% The function performs the following operations on one continuous EEGLAB
% dataset:
%
%   1. Loads an ASR-cleaned .set dataset.
%   2. Removes M1, M2, HEO, and VEO permanently.
%   3. Restores participant-specific missing scalp channels using spherical
%      interpolation and the original channel locations stored by
%      clean_triad_asr.
%   4. Computes an arithmetic average reference across scalp EEG channels
%      only. The Trigger channel remains unchanged.
%   5. Looks up MNI channel coordinates associated with the standard DIPFIT
%      BEM model.
%   6. Creates a scalp-only ICA-training copy and resamples that copy to
%      250 Hz by default.
%   7. Estimates the effective data rank and runs extended Infomax ICA with
%      explicit PCA dimensionality reduction.
%   8. Transfers the ICA decomposition to the full-rate dataset.
%   9. Fits one equivalent dipole per IC using the standard BEM model.
%  10. Runs ICLabel.
%  11. Saves the dataset without flagging or removing any components.
%
% The dedicated acquisition reference between Cz and CPz is not restored as
% a zero-valued channel.
%
% INPUT
%
%   setFile
%       Path to one continuous ASR-cleaned EEGLAB .set dataset.
%
% OPTIONAL NAME-VALUE INPUTS
%
%   'OutputDir'                    Default: ''
%       Output folder. When empty, the output is saved beside the input.
%
%   'SaveOutput'                   Default: true
%       Save the final .set file and QC reports.
%
%   'RemoveLabels'                 Default: {'M1','M2','HEO','VEO'}
%       Channels removed permanently before interpolation and rereferencing.
%
%   'EOGLabels'                    Default: {'HEO','VEO'}
%   'TriggerLabels'                Default: {'Trigger'}
%
%   'InterpolationMethod'          Default: 'spherical'
%       Method passed to eeg_interp.
%
%   'ICAResampleRate'              Default: 250 Hz
%       Sampling rate of the temporary ICA-training copy. The saved dataset
%       remains at its original post-ASR sampling rate.
%
%   'ICAMethod'                    Default: 'runica'
%   'ExtendedICA'                  Default: true
%
%   'RankTolerance'                Default: 1e-7
%       Absolute covariance-eigenvalue threshold used in the Makoto-style
%       rank estimate.
%
%   'RankSampleCount'              Default: 100000
%       Maximum number of evenly distributed ICA-training samples used for
%       numerical rank estimation.
%
%   'RandomSeed'                   Default: 1
%       Random seed used for reproducible ICA initialisation.
%
%   'RunDIPFIT'                    Default: true
%   'DIPFITModel'                  Default: 'standardBEM'
%       Retained for compatibility. This function explicitly uses the
%       standard MNI boundary-element model and rejects other model names.
%
%   'DIPFITThresholdPercent'       Default: 100
%       Setting this to 100 retains all fitted dipole models, irrespective
%       of residual variance.
%
%   'DIPFITCoordTransform'
%       Default: [0 0 0 0 0 -pi/2 1 1 1]
%       Explicit standard_1005-to-MNI-BEM coregistration:
%       [shiftX shiftY shiftZ pitch roll yaw scaleX scaleY scaleZ].
%
%   'PlotDIPFITAlignment'          Default: false
%
%   'RunICLabel'                   Default: true
%
% OUTPUTS
%
%   EEGout
%       Full-rate dataset containing the ICA decomposition, DIPFIT models,
%       and ICLabel probabilities. No ICs are removed.
%
%   summaryTable
%       One-row participant-level processing summary.
%
%   componentTable
%       One row per IC with ICLabel probabilities and DIPFIT results.
%
%   rankTable
%       One-row table containing theoretical and numerical rank estimates.
%
% EXAMPLE
%
%   [EEGout, summaryTable, componentTable, rankTable] = ...
%       run_ica_dipfit_iclabel( ...
%           '303_1_raw_sync_asr.set', ...
%           'OutputDir', ...
%           'E:\Granada\data_derivatives\04_ica\triad_303');
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

labelListValidator = @(x) ischar(x) || isstring(x) || iscellstr(x); %#ok<ISCLSTR>
logicalScalar = @(x) islogical(x) && isscalar(x);
positiveScalar = @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x > 0;
nonnegativeInteger = @(x) isnumeric(x) && isscalar(x) && ...
    isfinite(x) && x >= 0 && x == round(x);

addRequired(parser, 'setFile', pathValidator);

addParameter(parser, 'OutputDir', '', pathValidator);
addParameter(parser, 'SaveOutput', true, logicalScalar);

addParameter(parser, 'RemoveLabels', ...
    {'M1', 'M2', 'HEO', 'VEO'}, labelListValidator);
addParameter(parser, 'EOGLabels', {'HEO', 'VEO'}, labelListValidator);
addParameter(parser, 'TriggerLabels', {'Trigger'}, labelListValidator);

addParameter(parser, 'InterpolationMethod', 'spherical', pathValidator);

addParameter(parser, 'ICAResampleRate', 250, positiveScalar);
addParameter(parser, 'ICAMethod', 'runica', pathValidator);
addParameter(parser, 'ExtendedICA', true, logicalScalar);
addParameter(parser, 'RankTolerance', 1e-7, positiveScalar);
addParameter(parser, 'RankSampleCount', 100000, positiveScalar);
addParameter(parser, 'RandomSeed', 1, nonnegativeInteger);

addParameter(parser, 'RunDIPFIT', true, logicalScalar);
addParameter(parser, 'DIPFITModel', 'standardBEM', pathValidator);
addParameter(parser, 'DIPFITThresholdPercent', 100, ...
    @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x >= 0 && x <= 100);
addParameter(parser, 'DIPFITCoordTransform', ...
    [0 0 0 0 0 -pi/2 1 1 1], ...
    @(x) isnumeric(x) && isvector(x) && numel(x) == 9 && ...
    all(isfinite(x)));
addParameter(parser, 'PlotDIPFITAlignment', false, logicalScalar);

addParameter(parser, 'RunICLabel', true, logicalScalar);

parse(parser, setFile, varargin{:});
options = parser.Results;

setFile = char(setFile);
options.OutputDir = char(options.OutputDir);
options.RemoveLabels = cellstr(string(options.RemoveLabels));
options.EOGLabels = cellstr(string(options.EOGLabels));
options.TriggerLabels = cellstr(string(options.TriggerLabels));
options.InterpolationMethod = char(options.InterpolationMethod);
options.ICAMethod = char(options.ICAMethod);
options.DIPFITModel = char(options.DIPFITModel);
options.DIPFITCoordTransform = ...
    double(options.DIPFITCoordTransform(:).');
options.RankSampleCount = round(options.RankSampleCount);

if options.RunDIPFIT && ...
        ~strcmpi(options.DIPFITModel, 'standardBEM')

    error( ...
        'run_ica_dipfit_iclabel:UnsupportedDIPFITModel', ...
        ['This pipeline now uses an explicit standard MNI BEM ' ...
         'coregistration. DIPFITModel must be ''standardBEM''.']);

end


%% Check dependencies

requiredFunctions = { ...
    'pop_loadset', ...
    'pop_saveset', ...
    'pop_select', ...
    'pop_resample', ...
    'pop_runica', ...
    'pop_chanedit', ...
    'eeg_interp', ...
    'eeg_checkset'};

if options.RunDIPFIT
    requiredFunctions = [requiredFunctions, { ...
        'pop_dipfit_settings', ...
        'pop_multifit'}];
end

if options.RunICLabel
    requiredFunctions = [requiredFunctions, {'iclabel'}];
end

missingFunctions = requiredFunctions( ...
    cellfun(@(x) exist(x, 'file') ~= 2, requiredFunctions));

if ~isempty(missingFunctions)
    error( ...
        'run_ica_dipfit_iclabel:MissingDependencies', ...
        ['The following EEGLAB or plugin functions were not found:\n%s'], ...
        strjoin(missingFunctions, ', '));
end

% Resolve the installed standard MNI BEM files before starting the
% computationally expensive ICA. This prevents discovering a missing
% DIPFIT installation only after ICA has completed.
standardBEM = struct( ...
    'headModelFile', "", ...
    'mriFile', "", ...
    'channelFile', "", ...
    'coordFormat', "MNI");

if options.RunDIPFIT
    standardBEM = resolveStandardBEMFiles();
end


%% Load the ASR-cleaned dataset

if ~isfile(setFile)
    error( ...
        'run_ica_dipfit_iclabel:FileNotFound', ...
        'Dataset not found:\n%s', ...
        setFile);
end

[inputFolder, inputName, inputExtension] = fileparts(setFile);

if isempty(inputFolder)
    inputFolder = pwd;
end

if isempty(options.OutputDir)
    outputDir = inputFolder;
else
    outputDir = options.OutputDir;
end

if options.SaveOutput && ~isfolder(outputDir)
    mkdir(outputDir);
end

processingTimer = tic;

EEG = pop_loadset( ...
    'filename', [inputName inputExtension], ...
    'filepath', inputFolder);

EEG = eeg_checkset(EEG, 'eventconsistency');

if EEG.trials ~= 1
    error( ...
        'run_ica_dipfit_iclabel:EpochedDataset', ...
        'The input dataset is epoched. Continuous data are required.');
end

if ~isfield(EEG, 'etc') || ...
        ~isfield(EEG.etc, 'triad_asr_cleaning') || ...
        ~isfield(EEG.etc.triad_asr_cleaning, 'originalChanlocs')

    error( ...
        'run_ica_dipfit_iclabel:MissingOriginalChanlocs', ...
        ['The original channel locations saved by clean_triad_asr were ' ...
         'not found in EEG.etc.triad_asr_cleaning.originalChanlocs.']);
end

originalSamplingRate = double(EEG.srate);
originalPointCount = double(EEG.pnts);
originalChannelCount = double(EEG.nbchan);

originalChanlocs = ...
    EEG.etc.triad_asr_cleaning.originalChanlocs;

if isempty(originalChanlocs)
    error( ...
        'run_ica_dipfit_iclabel:EmptyOriginalChanlocs', ...
        'The stored original channel-location structure is empty.');
end


%% Remove any previous ICA or source-model results

EEG = clearICAFields(EEG);

if isfield(EEG, 'dipfit')
    EEG.dipfit = [];
end

if isfield(EEG.etc, 'ic_classification')
    EEG.etc = rmfield(EEG.etc, 'ic_classification');
end


%% Remove mastoid and EOG channels permanently

labelsBeforeRemoval = string({EEG.chanlocs.labels});
removeIndices = findLabels(labelsBeforeRemoval, options.RemoveLabels);
removedPermanentLabels = labelsBeforeRemoval(removeIndices);

if ~isempty(removeIndices)
    EEG = pop_select(EEG, 'nochannel', removeIndices);
end

EEG = eeg_checkset(EEG);


%% Identify the target and retained scalp montages

targetGroups = classifyChanlocs( ...
    originalChanlocs, ...
    options.EOGLabels, ...
    options.TriggerLabels, ...
    options.RemoveLabels);

targetScalpChanlocs = originalChanlocs(targetGroups.scalpIndices);
targetScalpLabels = string({targetScalpChanlocs.labels});

if isempty(targetScalpChanlocs)
    error( ...
        'run_ica_dipfit_iclabel:NoTargetScalpChannels', ...
        'No target scalp EEG channels were identified.');
end

currentGroups = classifyChanlocs( ...
    EEG.chanlocs, ...
    options.EOGLabels, ...
    options.TriggerLabels, ...
    options.RemoveLabels);

if isempty(currentGroups.scalpIndices)
    error( ...
        'run_ica_dipfit_iclabel:NoRetainedScalpChannels', ...
        'No retained scalp EEG channels were identified.');
end

goodScalpBeforeInterpolation = ...
    numel(currentGroups.scalpIndices);

currentScalpLabels = ...
    string({EEG.chanlocs(currentGroups.scalpIndices).labels});

interpolatedLabels = setdiff( ...
    targetScalpLabels, ...
    currentScalpLabels, ...
    'stable');


%% Interpolate missing scalp channels only

auxiliaryIndices = currentGroups.auxiliaryIndices;
auxiliaryData = EEG.data(auxiliaryIndices, :, :);
auxiliaryChanlocs = EEG.chanlocs(auxiliaryIndices);

scalpEEG = pop_select( ...
    EEG, ...
    'channel', ...
    currentGroups.scalpIndices);

scalpEEG = eeg_interp( ...
    scalpEEG, ...
    targetScalpChanlocs, ...
    options.InterpolationMethod);

scalpEEG = eeg_checkset(scalpEEG);

if scalpEEG.nbchan ~= numel(targetScalpChanlocs)
    error( ...
        'run_ica_dipfit_iclabel:InterpolationChannelCountMismatch', ...
        ['Interpolation returned %d scalp channels, but %d target scalp ' ...
         'channels were expected.'], ...
        scalpEEG.nbchan, ...
        numel(targetScalpChanlocs));
end

EEG = scalpEEG;

if ~isempty(auxiliaryIndices)
    EEG.data = cat(1, EEG.data, auxiliaryData);
    EEG.chanlocs = [EEG.chanlocs auxiliaryChanlocs];
    EEG.nbchan = size(EEG.data, 1);
end

EEG = eeg_checkset(EEG, 'eventconsistency');

scalpIndices = 1:numel(targetScalpChanlocs);
auxiliaryIndices = (numel(targetScalpChanlocs) + 1):EEG.nbchan;

finalScalpLabels = string({EEG.chanlocs(scalpIndices).labels});
auxiliaryLabels = string({EEG.chanlocs(auxiliaryIndices).labels});

if ~isequal(upper(finalScalpLabels(:)), upper(targetScalpLabels(:)))
    error( ...
        'run_ica_dipfit_iclabel:ScalpOrderMismatch', ...
        'The interpolated scalp-channel order does not match the target montage.');
end


%% Arithmetic average reference across scalp channels only

dataClass = class(EEG.data);

scalpDataDouble = double(EEG.data(scalpIndices, :, :));
scalpAverage = mean(scalpDataDouble, 1);
scalpDataDouble = scalpDataDouble - scalpAverage;

EEG.data(scalpIndices, :, :) = ...
    castLike(scalpDataDouble, dataClass);

EEG.ref = 'averef';
EEG = eeg_checkset(EEG);


%% Replace scalp locations with standard_1005 MNI coordinates

bemChannelFile = "";

if options.RunDIPFIT

    bemChannelFile = standardBEM.channelFile;

    EEG = lookupMNIForStandardBEM( ...
        EEG, ...
        scalpIndices, ...
        char(standardBEM.channelFile));

end


%% Create the scalp-only ICA-training copy

EEGica = pop_select( ...
    EEG, ...
    'channel', ...
    scalpIndices);

EEGica = clearICAFields(EEGica);

if options.ICAResampleRate < EEGica.srate

    EEGica = pop_resample( ...
        EEGica, ...
        options.ICAResampleRate);

elseif options.ICAResampleRate > EEGica.srate

    warning( ...
        'run_ica_dipfit_iclabel:NoUpsamplingForICA', ...
        ['ICAResampleRate is higher than the dataset sampling rate. ' ...
         'The ICA-training copy will remain at %.6f Hz.'], ...
        EEGica.srate);

end

icaTrainingRate = double(EEGica.srate);

if any(~isfinite(EEGica.data(:)))
    error( ...
        'run_ica_dipfit_iclabel:NonfiniteICAData', ...
        'The ICA-training data contain NaN or Inf values.');
end


%% Estimate the effective ICA rank

expectedRank = max( ...
    1, ...
    goodScalpBeforeInterpolation - 1);

rankInfo = estimateICARank( ...
    EEGica.data, ...
    expectedRank, ...
    options.RankTolerance, ...
    options.RankSampleCount);

icaRank = rankInfo.FinalRank;

if icaRank < 2
    error( ...
        'run_ica_dipfit_iclabel:InsufficientRank', ...
        'The estimated ICA rank is %d; at least 2 is required.', ...
        icaRank);
end


%% Run extended Infomax ICA

previousRandomState = rng;
randomStateCleanup = onCleanup(@() rng(previousRandomState)); %#ok<NASGU>
rng(options.RandomSeed, 'twister');

icaArguments = { ...
    'icatype', options.ICAMethod, ...
    'pca', icaRank};

if strcmpi(options.ICAMethod, 'runica')
    icaArguments = [icaArguments, { ...
        'extended', double(options.ExtendedICA)}];
end

EEGica = pop_runica( ...
    EEGica, ...
    icaArguments{:});

EEGica = eeg_checkset(EEGica, 'ica');

numberOfComponents = size(EEGica.icaweights, 1);

if numberOfComponents ~= icaRank
    warning( ...
        'run_ica_dipfit_iclabel:UnexpectedComponentCount', ...
        ['ICA returned %d components although an effective rank of %d ' ...
         'was requested.'], ...
        numberOfComponents, ...
        icaRank);
end


%% Transfer ICA weights to the full-rate dataset

EEG.icaweights = EEGica.icaweights;
EEG.icasphere = EEGica.icasphere;
EEG.icawinv = EEGica.icawinv;
EEG.icachansind = scalpIndices;
EEG.icaact = [];

if isfield(EEGica, 'chaninfo') && ...
        isfield(EEGica.chaninfo, 'icachansind')
    EEG.chaninfo.icachansind = scalpIndices;
end

EEG = eeg_checkset(EEG, 'ica');


%% Configure and run DIPFIT using explicit MNI-BEM coregistration

if options.RunDIPFIT

    % Remove only a previous source model, if one exists. The EEG data,
    % ICA decomposition, and all other metadata remain unchanged.
    EEG.dipfit = struct;

    % Configure the installed standard MNI BEM model explicitly rather than
    % relying on a model-name shortcut. The transform rotates standard_1005
    % electrode coordinates into the coordinate convention used by the BEM.
    EEG = pop_dipfit_settings( ...
        EEG, ...
        'hdmfile', char(standardBEM.headModelFile), ...
        'coordformat', char(standardBEM.coordFormat), ...
        'mrifile', char(standardBEM.mriFile), ...
        'chanfile', char(standardBEM.channelFile), ...
        'coord_transform', options.DIPFITCoordTransform, ...
        'chansel', scalpIndices, ...
        'plotalignment', onOff(options.PlotDIPFITAlignment));

    % Fit one equivalent dipole to every independent component. A threshold
    % of 100 retains all successfully fitted models for later manual review.
    EEG = pop_multifit( ...
        EEG, ...
        1:numberOfComponents, ...
        'dipoles', 1, ...
        'threshold', options.DIPFITThresholdPercent, ...
        'rmout', 'off', ...
        'dipplot', 'off');

end


%% Run ICLabel

if options.RunICLabel

    EEG = iclabel(EEG);

end

EEG = eeg_checkset(EEG, 'ica');


%% Store processing metadata

[triadCode, participantNumber, participantID] = ...
    inferParticipantIdentifiers(inputName);

EEG.etc.ica_dipfit_iclabel.function = mfilename;
EEG.etc.ica_dipfit_iclabel.date = datestr(now, 30);
EEG.etc.ica_dipfit_iclabel.stage = ...
    'ICA, DIPFIT, and ICLabel completed; no ICs removed';
EEG.etc.ica_dipfit_iclabel.permanentlyRemovedLabels = ...
    cellstr(removedPermanentLabels);
EEG.etc.ica_dipfit_iclabel.interpolatedLabels = ...
    cellstr(interpolatedLabels);
EEG.etc.ica_dipfit_iclabel.interpolationMethod = ...
    options.InterpolationMethod;
EEG.etc.ica_dipfit_iclabel.averageReference = true;
EEG.etc.ica_dipfit_iclabel.referenceChannelRestored = false;
EEG.etc.ica_dipfit_iclabel.referenceChannels = ...
    cellstr(finalScalpLabels);
EEG.etc.ica_dipfit_iclabel.auxiliaryChannelsUnreferenced = ...
    cellstr(auxiliaryLabels);
EEG.etc.ica_dipfit_iclabel.fullRateSamplingRate = ...
    originalSamplingRate;
EEG.etc.ica_dipfit_iclabel.icaTrainingSamplingRate = ...
    icaTrainingRate;
EEG.etc.ica_dipfit_iclabel.rank = rankInfo;
EEG.etc.ica_dipfit_iclabel.icaMethod = options.ICAMethod;
EEG.etc.ica_dipfit_iclabel.extendedICA = options.ExtendedICA;
EEG.etc.ica_dipfit_iclabel.randomSeed = options.RandomSeed;
EEG.etc.ica_dipfit_iclabel.dipfitModel = ...
    stringOrEmpty('standard MNI BEM', options.RunDIPFIT);
EEG.etc.ica_dipfit_iclabel.bemHeadModelFile = ...
    stringOrEmpty(standardBEM.headModelFile, options.RunDIPFIT);
EEG.etc.ica_dipfit_iclabel.bemMRIFile = ...
    stringOrEmpty(standardBEM.mriFile, options.RunDIPFIT);
EEG.etc.ica_dipfit_iclabel.bemChannelFile = ...
    stringOrEmpty(bemChannelFile, options.RunDIPFIT);
EEG.etc.ica_dipfit_iclabel.dipfitCoordFormat = ...
    stringOrEmpty(standardBEM.coordFormat, options.RunDIPFIT);
EEG.etc.ica_dipfit_iclabel.dipfitCoordTransform = ...
    conditionalNumeric(options.DIPFITCoordTransform, options.RunDIPFIT);
EEG.etc.ica_dipfit_iclabel.dipfitLookupAliases = ...
    {'CB1', 'I1'; 'CB2', 'I2'};
EEG.etc.ica_dipfit_iclabel.iclabelRun = options.RunICLabel;
EEG.etc.ica_dipfit_iclabel.componentsFlagged = false;
EEG.etc.ica_dipfit_iclabel.componentsRemoved = false;


%% Define and save the processed dataset before creating QC tables

outputName = [inputName '_ica.set'];
outputFile = fullfile(outputDir, outputName);

EEG.setname = [inputName '_ica'];

% Save the completed ICA/DIPFIT/ICLabel dataset before report generation.
% This preserves the expensive processing result even if an Excel or table
% reporting operation fails later.
if options.SaveOutput

    EEG = pop_saveset( ...
        EEG, ...
        'filename', outputName, ...
        'filepath', outputDir);

end


%% Create output tables

componentTable = buildComponentTable( ...
    EEG, ...
    triadCode, ...
    participantNumber, ...
    participantID);

[dipolesFitted, medianResidualVariance] = ...
    summariseDipfit(componentTable);

processingSeconds = toc(processingTimer);

summaryTable = table( ...
    string(triadCode), ...
    participantNumber, ...
    string(participantID), ...
    string(setFile), ...
    string(outputFile), ...
    originalSamplingRate, ...
    icaTrainingRate, ...
    originalPointCount, ...
    originalChannelCount, ...
    strjoin(removedPermanentLabels, '; '), ...
    goodScalpBeforeInterpolation, ...
    numel(interpolatedLabels), ...
    strjoin(interpolatedLabels, '; '), ...
    numel(scalpIndices), ...
    strjoin(auxiliaryLabels, '; '), ...
    expectedRank, ...
    rankInfo.MatlabRank, ...
    rankInfo.EigenvalueRank, ...
    rankInfo.FinalRank, ...
    numberOfComponents, ...
    options.RunDIPFIT, ...
    dipolesFitted, ...
    medianResidualVariance, ...
    options.RunICLabel, ...
    false, ...
    processingSeconds, ...
    'VariableNames', { ...
        'TriadCode', ...
        'Participant', ...
        'ParticipantID', ...
        'InputFile', ...
        'OutputFile', ...
        'FullRateSamplingHz', ...
        'ICATrainingSamplingHz', ...
        'Samples', ...
        'InputChannels', ...
        'PermanentlyRemovedLabels', ...
        'GoodScalpChannelsBeforeInterpolation', ...
        'InterpolatedChannelCount', ...
        'InterpolatedLabels', ...
        'FinalScalpChannelCount', ...
        'AuxiliaryLabels', ...
        'ExpectedRank', ...
        'MatlabRank', ...
        'EigenvalueRank', ...
        'FinalICARank', ...
        'ICAComponentCount', ...
        'DIPFITRun', ...
        'DipolesFitted', ...
        'MedianResidualVariance', ...
        'ICLabelRun', ...
        'ComponentsRemoved', ...
        'ProcessingSeconds'});

rankTable = table( ...
    string(triadCode), ...
    participantNumber, ...
    string(participantID), ...
    rankInfo.ChannelCount, ...
    rankInfo.SamplesAvailable, ...
    rankInfo.SamplesUsed, ...
    rankInfo.ExpectedRank, ...
    rankInfo.MatlabRank, ...
    rankInfo.EigenvalueRank, ...
    rankInfo.FinalRank, ...
    rankInfo.EigenvalueTolerance, ...
    rankInfo.MinimumEigenvalue, ...
    rankInfo.MaximumEigenvalue, ...
    'VariableNames', { ...
        'TriadCode', ...
        'Participant', ...
        'ParticipantID', ...
        'ChannelCount', ...
        'SamplesAvailable', ...
        'SamplesUsed', ...
        'ExpectedRank', ...
        'MatlabRank', ...
        'EigenvalueRank', ...
        'FinalRank', ...
        'EigenvalueTolerance', ...
        'MinimumEigenvalue', ...
        'MaximumEigenvalue'});


%% Save QC reports

if options.SaveOutput

    reportBase = [inputName '_ica_qc'];
    excelFile = fullfile(outputDir, [reportBase '.xlsx']);
    matlabFile = fullfile(outputDir, [reportBase '.mat']);

    if isfile(excelFile)
        delete(excelFile);
    end

    writetable(summaryTable, excelFile, 'Sheet', 'Summary');
    writetable(rankTable, excelFile, 'Sheet', 'Rank');
    writetable(componentTable, excelFile, 'Sheet', 'Components');

    save( ...
        matlabFile, ...
        'summaryTable', ...
        'rankTable', ...
        'componentTable', ...
        'rankInfo', ...
        'options');

end

EEGout = EEG;


%% Print main result

fprintf('\nICA, DIPFIT, and ICLabel completed\n');
fprintf('----------------------------------\n');
fprintf('Dataset:                    %s\n', inputName);
fprintf('Full-rate sampling:         %.6f Hz\n', originalSamplingRate);
fprintf('ICA-training sampling:      %.6f Hz\n', icaTrainingRate);
fprintf('Channels removed:           %s\n', ...
    char(strjoin(removedPermanentLabels, ', ')));
fprintf('Scalp channels interpolated:%d\n', numel(interpolatedLabels));
fprintf('Final scalp channels:       %d\n', numel(scalpIndices));
fprintf('Expected rank:              %d\n', expectedRank);
fprintf('Numerical ICA rank:         %d\n', rankInfo.FinalRank);
fprintf('ICA components:             %d\n', numberOfComponents);
fprintf('DIPFIT performed:           %s\n', yesNo(options.RunDIPFIT));
fprintf('ICLabel performed:          %s\n', yesNo(options.RunICLabel));
fprintf('Components removed:         NO\n');

if options.SaveOutput
    fprintf('Saved dataset:\n%s\n\n', outputFile);
else
    fprintf('Output was not saved.\n\n');
end

end


%% ========================================================================
function EEG = clearICAFields(EEG)
% Remove a previous ICA decomposition without altering the channel data.

fields = { ...
    'icaact', ...
    'icawinv', ...
    'icasphere', ...
    'icaweights', ...
    'icachansind'};

for fieldIndex = 1:numel(fields)
    if isfield(EEG, fields{fieldIndex})
        EEG.(fields{fieldIndex}) = [];
    end
end

if isfield(EEG, 'reject') && isfield(EEG.reject, 'gcompreject')
    EEG.reject.gcompreject = [];
end

end


%% ========================================================================
function groups = classifyChanlocs( ...
    chanlocs, eogLabels, triggerLabels, removeLabels)
% Classify scalp and auxiliary channels using labels and channel types.

labels = string({chanlocs.labels});
upperLabels = upper(strtrim(labels));

types = strings(size(labels));

if isfield(chanlocs, 'type')
    types = lower(strtrim(string({chanlocs.type})));
end

eogKeys = upper(strtrim(string(eogLabels)));
triggerKeys = upper(strtrim(string(triggerLabels)));
removeKeys = upper(strtrim(string(removeLabels)));

isEOG = ismember(upperLabels, eogKeys) | contains(types, "eog");
isTrigger = ismember(upperLabels, triggerKeys) | ...
    contains(types, "trig") | ...
    contains(types, "event");
isRemoved = ismember(upperLabels, removeKeys);

isAuxiliary = isEOG | isTrigger;
isScalp = ~isAuxiliary & ~isRemoved;

groups.labels = labels;
groups.scalpIndices = find(isScalp);
groups.eogIndices = find(isEOG);
groups.triggerIndices = find(isTrigger);
groups.auxiliaryIndices = find(isAuxiliary);
groups.removeIndices = find(isRemoved);

end


%% ========================================================================
function indices = findLabels(labels, targetLabels)
% Find channel indices using case-insensitive exact label matching.

labels = upper(strtrim(string(labels)));
targets = upper(strtrim(string(targetLabels)));

indices = find(ismember(labels, targets));

end


%% ========================================================================
function converted = castLike(data, targetClass)
% Cast numerical data back to the original EEGLAB storage class.

switch targetClass
    case 'single'
        converted = single(data);
    case 'double'
        converted = double(data);
    otherwise
        converted = cast(data, targetClass);
end

end


%% ========================================================================
function EEG = lookupMNIForStandardBEM( ...
    EEG, scalpIndices, bemChannelFile)
% Look up standard_1005 coordinates used by the explicit MNI BEM model.

if ~isfile(bemChannelFile)
    error( ...
        'run_ica_dipfit_iclabel:MissingBEMChannelFile', ...
        'The standard BEM channel file was not found:\n%s', ...
        bemChannelFile);
end

cachedLabels = string({EEG.chanlocs.labels});
cachedTypes = strings(size(cachedLabels));

if isfield(EEG.chanlocs, 'type')
    cachedTypes = string({EEG.chanlocs.type});
end

% CB1 and CB2 are legacy inferior-cerebellar labels that are not present
% in the standard MNI BEM lookup file used by DIPFIT. Temporarily use their
% corresponding 10-5 labels I1 and I2 for coordinate lookup, then restore
% the original labels. Channel order and data are not changed.
lookupLabels = cachedLabels;

lookupLabels(strcmpi(cachedLabels, "CB1")) = "I1";
lookupLabels(strcmpi(cachedLabels, "CB2")) = "I2";

for channelIndex = 1:numel(lookupLabels)
    EEG.chanlocs(channelIndex).labels = ...
        char(lookupLabels(channelIndex));
end

EEG = pop_chanedit( ...
    EEG, ...
    'lookup', ...
    char(bemChannelFile));

if EEG.nbchan ~= numel(cachedLabels)

    error( ...
        'run_ica_dipfit_iclabel:LookupChangedChannelCount', ...
        ['The MNI coordinate lookup changed the number of channels ' ...
         'from %d to %d.'], ...
        numel(cachedLabels), ...
        EEG.nbchan);

end

% Restore the original labels and channel types by channel position.
% pop_chanedit performs a lookup but does not reorder the channels.
for channelIndex = 1:numel(cachedLabels)

    EEG.chanlocs(channelIndex).labels = ...
        char(cachedLabels(channelIndex));

    if isfield(EEG.chanlocs, 'type')
        EEG.chanlocs(channelIndex).type = ...
            char(cachedTypes(channelIndex));
    end

end

for channelIndex = scalpIndices

    coordinates = [ ...
        numericChanlocField(EEG.chanlocs(channelIndex), 'X'), ...
        numericChanlocField(EEG.chanlocs(channelIndex), 'Y'), ...
        numericChanlocField(EEG.chanlocs(channelIndex), 'Z')];

    if any(~isfinite(coordinates))
        error( ...
            'run_ica_dipfit_iclabel:MissingMNILocation', ...
            ['MNI coordinates could not be assigned to scalp channel %s.'], ...
            EEG.chanlocs(channelIndex).labels);
    end

end

EEG = eeg_checkset(EEG);

end


%% ========================================================================
function standardBEM = resolveStandardBEMFiles()
% Resolve and validate the standard MNI BEM files installed with DIPFIT.

dipfitPath = fileparts(which('pop_dipfit_settings'));

if isempty(dipfitPath)
    error( ...
        'run_ica_dipfit_iclabel:DIPFITPathNotFound', ...
        'The installed DIPFIT folder could not be resolved.');
end

standardBEM = struct;
standardBEM.headModelFile = string(fullfile( ...
    dipfitPath, ...
    'standard_BEM', ...
    'standard_vol.mat'));
standardBEM.mriFile = string(fullfile( ...
    dipfitPath, ...
    'standard_BEM', ...
    'standard_mri.mat'));
standardBEM.channelFile = string(fullfile( ...
    dipfitPath, ...
    'standard_BEM', ...
    'elec', ...
    'standard_1005.elc'));
standardBEM.coordFormat = "MNI";

requiredFiles = [ ...
    standardBEM.headModelFile, ...
    standardBEM.mriFile, ...
    standardBEM.channelFile];

missingFiles = requiredFiles(~isfile(requiredFiles));

if ~isempty(missingFiles)
    error( ...
        'run_ica_dipfit_iclabel:MissingStandardBEMFiles', ...
        ['The following standard MNI BEM files were not found:\n%s'], ...
        strjoin(missingFiles, newline));
end

end


%% ========================================================================
function value = numericChanlocField(chanloc, fieldName)
% Return one numeric channel-location field or NaN.

value = NaN;

if isfield(chanloc, fieldName)

    candidate = chanloc.(fieldName);

    if isnumeric(candidate) && isscalar(candidate) && isfinite(candidate)
        value = double(candidate);
    end

end

end


%% ========================================================================
function rankInfo = estimateICARank( ...
    data, expectedRank, eigenvalueTolerance, maximumSamples)
% Estimate effective rank using theoretical, MATLAB, and covariance methods.

numberOfChannels = size(data, 1);
numberOfSamples = size(data, 2) * size(data, 3);

maximumSamples = min(numberOfSamples, maximumSamples);

sampleIndices = unique(round(linspace( ...
    1, ...
    numberOfSamples, ...
    maximumSamples)));

flatData = reshape(data, numberOfChannels, numberOfSamples);
sampledData = double(flatData(:, sampleIndices));

sampledData = sampledData - mean(sampledData, 2);

matlabRank = rank(sampledData);

covarianceMatrix = ...
    (sampledData * sampledData.') / size(sampledData, 2);

covarianceMatrix = ...
    (covarianceMatrix + covarianceMatrix.') / 2;

eigenvalues = real(eig(covarianceMatrix));
eigenvalues = sort(eigenvalues, 'ascend');

eigenvalueRank = nnz(eigenvalues > eigenvalueTolerance);

finalRank = min([ ...
    expectedRank, ...
    matlabRank, ...
    eigenvalueRank, ...
    numberOfChannels]);

rankInfo = struct;
rankInfo.ChannelCount = numberOfChannels;
rankInfo.SamplesAvailable = numberOfSamples;
rankInfo.SamplesUsed = numel(sampleIndices);
rankInfo.ExpectedRank = expectedRank;
rankInfo.MatlabRank = matlabRank;
rankInfo.EigenvalueRank = eigenvalueRank;
rankInfo.FinalRank = finalRank;
rankInfo.EigenvalueTolerance = eigenvalueTolerance;
rankInfo.MinimumEigenvalue = min(eigenvalues);
rankInfo.MaximumEigenvalue = max(eigenvalues);
rankInfo.Eigenvalues = eigenvalues;

if numel(unique([expectedRank matlabRank eigenvalueRank])) > 1

    warning( ...
        'run_ica_dipfit_iclabel:RankEstimatesDiffer', ...
        ['Rank estimates differ: expected=%d, MATLAB=%d, ' ...
         'eigenvalue=%d. ICA rank set to %d.'], ...
        expectedRank, ...
        matlabRank, ...
        eigenvalueRank, ...
        finalRank);

end

end


%% ========================================================================
function componentTable = buildComponentTable( ...
    EEG, triadCode, participantNumber, participantID)
% Build one row per independent component.

numberOfComponents = size(EEG.icaweights, 1);

componentNumber = (1:numberOfComponents)';

brainProbability = nan(numberOfComponents, 1);
muscleProbability = nan(numberOfComponents, 1);
eyeProbability = nan(numberOfComponents, 1);
heartProbability = nan(numberOfComponents, 1);
lineNoiseProbability = nan(numberOfComponents, 1);
channelNoiseProbability = nan(numberOfComponents, 1);
otherProbability = nan(numberOfComponents, 1);
mostLikelyClass = strings(numberOfComponents, 1);
maximumProbability = nan(numberOfComponents, 1);

if isfield(EEG, 'etc') && ...
        isfield(EEG.etc, 'ic_classification') && ...
        isfield(EEG.etc.ic_classification, 'ICLabel') && ...
        isfield(EEG.etc.ic_classification.ICLabel, 'classifications')

    probabilities = double( ...
        EEG.etc.ic_classification.ICLabel.classifications);

    % ICLabel normally stores class names as a 1-by-7 cell array. Convert
    % them explicitly to a column vector so indexed class labels have one
    % row per component and can be inserted safely into a MATLAB table.
    classNames = string( ...
        EEG.etc.ic_classification.ICLabel.classes);
    classNames = classNames(:);
    classes = lower(classNames);

    if size(probabilities, 1) ~= numberOfComponents

        error( ...
            'run_ica_dipfit_iclabel:ICLabelComponentCountMismatch', ...
            ['ICLabel returned %d classification rows for %d ICA ' ...
             'components.'], ...
            size(probabilities, 1), ...
            numberOfComponents);

    end

    if size(probabilities, 2) ~= numel(classNames)

        error( ...
            'run_ica_dipfit_iclabel:ICLabelClassCountMismatch', ...
            ['ICLabel returned %d probability columns but %d class ' ...
             'labels.'], ...
            size(probabilities, 2), ...
            numel(classNames));

    end

    brainProbability = extractClassProbability( ...
        probabilities, classes, "brain");
    muscleProbability = extractClassProbability( ...
        probabilities, classes, "muscle");
    eyeProbability = extractClassProbability( ...
        probabilities, classes, "eye");
    heartProbability = extractClassProbability( ...
        probabilities, classes, "heart");
    lineNoiseProbability = extractClassProbability( ...
        probabilities, classes, "line noise");
    channelNoiseProbability = extractClassProbability( ...
        probabilities, classes, "channel noise");
    otherProbability = extractClassProbability( ...
        probabilities, classes, "other");

    [maximumProbability, classIndices] = ...
        max(probabilities, [], 2);

    maximumProbability = maximumProbability(:);
    mostLikelyClass = classNames(classIndices);
    mostLikelyClass = mostLikelyClass(:);

end

dipoleX = nan(numberOfComponents, 1);
dipoleY = nan(numberOfComponents, 1);
dipoleZ = nan(numberOfComponents, 1);
residualVariance = nan(numberOfComponents, 1);
dipoleFitted = false(numberOfComponents, 1);

if isfield(EEG, 'dipfit') && ...
        isfield(EEG.dipfit, 'model') && ...
        ~isempty(EEG.dipfit.model)

    numberOfModels = min( ...
        numberOfComponents, ...
        numel(EEG.dipfit.model));

    for component = 1:numberOfModels

        model = EEG.dipfit.model(component);

        if isfield(model, 'posxyz') && ...
                ~isempty(model.posxyz) && ...
                size(model.posxyz, 2) >= 3

            dipoleX(component) = model.posxyz(1, 1);
            dipoleY(component) = model.posxyz(1, 2);
            dipoleZ(component) = model.posxyz(1, 3);
            dipoleFitted(component) = true;

        end

        if isfield(model, 'rv') && ...
                ~isempty(model.rv) && ...
                isfinite(model.rv)

            residualVariance(component) = double(model.rv);

        end

    end

end

% Enforce one row per independent component. This avoids MATLAB table
% construction errors caused by row-oriented class-name arrays.
componentNumber = componentNumber(:);
mostLikelyClass = mostLikelyClass(:);
maximumProbability = maximumProbability(:);
brainProbability = brainProbability(:);
muscleProbability = muscleProbability(:);
eyeProbability = eyeProbability(:);
heartProbability = heartProbability(:);
lineNoiseProbability = lineNoiseProbability(:);
channelNoiseProbability = channelNoiseProbability(:);
otherProbability = otherProbability(:);
dipoleFitted = dipoleFitted(:);
dipoleX = dipoleX(:);
dipoleY = dipoleY(:);
dipoleZ = dipoleZ(:);
residualVariance = residualVariance(:);

componentVariableNames = { ...
    'Component', ...
    'MostLikelyClass', ...
    'MaximumClassProbability', ...
    'BrainProbability', ...
    'MuscleProbability', ...
    'EyeProbability', ...
    'HeartProbability', ...
    'LineNoiseProbability', ...
    'ChannelNoiseProbability', ...
    'OtherProbability', ...
    'DipoleFitted', ...
    'DipoleX', ...
    'DipoleY', ...
    'DipoleZ', ...
    'ResidualVariance'};

componentVariables = { ...
    componentNumber, ...
    mostLikelyClass, ...
    maximumProbability, ...
    brainProbability, ...
    muscleProbability, ...
    eyeProbability, ...
    heartProbability, ...
    lineNoiseProbability, ...
    channelNoiseProbability, ...
    otherProbability, ...
    dipoleFitted, ...
    dipoleX, ...
    dipoleY, ...
    dipoleZ, ...
    residualVariance};

componentRowCounts = cellfun( ...
    @(variable) size(variable, 1), ...
    componentVariables);

if any(componentRowCounts ~= numberOfComponents)

    badVariables = string(componentVariableNames( ...
        componentRowCounts ~= numberOfComponents));

    error( ...
        'run_ica_dipfit_iclabel:ComponentTableRowMismatch', ...
        ['The following component variables do not contain exactly %d ' ...
         'rows: %s'], ...
        numberOfComponents, ...
        strjoin(badVariables, ', '));

end

componentTable = table( ...
    repmat(string(triadCode), numberOfComponents, 1), ...
    repmat(participantNumber, numberOfComponents, 1), ...
    repmat(string(participantID), numberOfComponents, 1), ...
    componentNumber, ...
    mostLikelyClass, ...
    maximumProbability, ...
    brainProbability, ...
    muscleProbability, ...
    eyeProbability, ...
    heartProbability, ...
    lineNoiseProbability, ...
    channelNoiseProbability, ...
    otherProbability, ...
    dipoleFitted, ...
    dipoleX, ...
    dipoleY, ...
    dipoleZ, ...
    residualVariance, ...
    'VariableNames', { ...
        'TriadCode', ...
        'Participant', ...
        'ParticipantID', ...
        'Component', ...
        'MostLikelyClass', ...
        'MaximumClassProbability', ...
        'BrainProbability', ...
        'MuscleProbability', ...
        'EyeProbability', ...
        'HeartProbability', ...
        'LineNoiseProbability', ...
        'ChannelNoiseProbability', ...
        'OtherProbability', ...
        'DipoleFitted', ...
        'DipoleX', ...
        'DipoleY', ...
        'DipoleZ', ...
        'ResidualVariance'});

end


%% ========================================================================
function classProbability = extractClassProbability( ...
    probabilities, classes, targetClass)
% Extract one ICLabel probability column by class name.

classProbability = nan(size(probabilities, 1), 1);

classIndex = find(strcmpi(classes, targetClass), 1, 'first');

if ~isempty(classIndex)
    classProbability = probabilities(:, classIndex);
    classProbability = classProbability(:);
end

end


%% ========================================================================
function [numberFitted, medianRV] = summariseDipfit(componentTable)
% Summarise fitted dipoles without rejecting any component.

numberFitted = nnz(componentTable.DipoleFitted);

validRV = componentTable.ResidualVariance( ...
    isfinite(componentTable.ResidualVariance));

if isempty(validRV)
    medianRV = NaN;
else
    medianRV = median(validRV);
end

end


%% ========================================================================
function [triadCode, participantNumber, participantID] = ...
    inferParticipantIdentifiers(inputName)
% Infer identifiers from filenames such as 303_1_raw_sync_asr.

tokens = regexp( ...
    inputName, ...
    '(\d+)_([123])', ...
    'tokens', ...
    'once');

if isempty(tokens)
    triadCode = "";
    participantNumber = NaN;
    participantID = inputName;
else
    triadCode = string(tokens{1});
    participantNumber = str2double(tokens{2});
    participantID = sprintf('%s_%s', tokens{1}, tokens{2});
end

end


%% ========================================================================
function text = onOff(value)
% Convert a logical value to an EEGLAB on/off string.

if value
    text = 'on';
else
    text = 'off';
end

end


%% ========================================================================
function text = yesNo(value)
% Convert a logical value to YES/NO text.

if value
    text = 'YES';
else
    text = 'NO';
end

end


%% ========================================================================
function value = stringOrEmpty(text, enabled)
% Return a string value only when the corresponding procedure was enabled.

if enabled
    value = string(text);
else
    value = "";
end

end


%% ========================================================================
function value = conditionalNumeric(numberVector, enabled)
% Return numerical metadata only when the corresponding procedure was run.

if enabled
    value = double(numberVector);
else
    value = [];
end

end
