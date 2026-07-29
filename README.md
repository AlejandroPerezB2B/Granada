# Triadic EEG Analysis Pipeline

> **Project title:** _ColMem_

This repository contains the MATLAB and EEGLAB code used to import, organise, synchronise, preprocess and analyse EEG data recorded simultaneously from participant triads.

## Authors:

- **Alejandro Pérez** — `@AlejandroPerezB2B`
- **Celia Sissi Stijsiger** — `@CeliaSissi`

## Background

This section should provide sufficient information for a researcher not involved in data collection to understand the experiment and the task.

## Experimental task

Participants were Spanish–English bilinguals who completed the Michigan English Language Institute College English Test (MELICET) as part of the pre-screening procedure. A minimum score of 25 out of 50 was required for inclusion. Upon arrival, participants were asked whether they knew either of the other individuals assigned to the same session. Previously acquainted participants were not included in the collaborative condition and were instead tested individually or rescheduled. All participants provided written informed consent and completed the Language Experience and Proficiency Questionnaire (LEAP-Q) to assess their language history, proficiency, and patterns of language use.

Each experimental session lasted approximately 130 minutes and comprised four sequential phases: (1) individual encoding in the participants’ second language (L2; English), (2) a 5-minute retention interval, (3) oral free recall performed either collaboratively or individually and in either the first language (L1; Spanish) or L2, and (4) individual written free recall in L2.

Participants were assigned to one of four conditions defined by the combination of recall format and recall language:

| Condition | Study Phase | Recall 1 (Oral) | Recall 2 (On paper) |
|---|---|---|---|
| _Condition 1 (nominal, same language)_ | _Individual L2_ | _Individual L2_ | _Individual L2_ |
| _Condition 2 (nominal, different language)_ | _Individual L2_ | _Individual L1_ | _Individual L2_ |
| _Condition 3 (collaborative, same language)_ | _Collaborative L2_ | _Collaborative L2_ | _Collaborative L2_ |
| _Condition 4 (collaborative, different language)_ | _Collaborative L2_ | _Collaborative L1_ | _Collaborative L2_ |

**Study Phase:**
The experiment begins with the study phase, which is completed individually by all participants. Participants studied items individually in 2 cycles in their L2 (English). Each cycle consists of 90 words in total, divided into 6 blocks of 15 words (1 sec for fixation point, 6 sec for word presentation). Each block includes one word from each category, with a randomised order of word presentation with respect to category membership. The study list also includes 9 filler words in total (2 filler words at the beginning and end of the list and 1 filler word presented between each block). For each word, participants are asked to rate its pleasantness on a 5-point scale ranging from 1 (very unpleasant) to 5 (very pleasant) by pressing the corresponding key on the keyboard. Participants will be instructed to continue with the task even if they miss a response and informed that there are no correct or incorrect answers. Furthermore, instructions did not mention the following memory tests or the possibility of working alone versus working in groups later. EEG activity will be recorded continuously throughout this phase.

**5-minute delay:**
Following the study phase, participants will complete a 5-minute delay period, during which they will rest while the researcher checks the EEG equipment. No memory-related material will be presented during this interval.

**Recall 1 (Oral):**
After the delay, participants will complete either a collaborative or an individual oral recall task in either their L1 or L2, depending on their assigned experimental condition. In the collaborative condition, groups of three participants will take turns recalling one previously studied word at a time. In the nominal conditions, participants will recall words individually. In both conditions, the recall process involved a total of 99 turns, each lasting 6 seconds, with a 1-second fixation dot interval between each turn. The sequence of turns was determined randomly, ensuring that each participant was prompted an equal number of turns. Computer screen prompts provided guidance to participants regarding their respective turns, such as using labels like "Participant 1", "Participant 2", "Participant 3", for those in the collaborative condition and a simple "Please recall" for individuals in the nominal condition. Participants were instructed to recall one word out loud during each turn, avoid repeating words already mentioned, and remain silent when unable to recall a word during their assigned turn. If a participant was unable to remember within the allocated time limit, in the collaborative condition, the next group member's turn was prompted automatically, whereas in the nominal condition, the individual's following turn was commenced. After each turn in both experimental conditions, the researcher typed the recalled words for participants as a reference. The experimental setting involved participants seated together around a single table, with their attention directed towards two computer screens. One monitor indicated whose turn it is to recall, while the other presented the sequentially recalled words, ensuring that participants can see the previously remembered words as a reference. Both collaborative and nominal recall phases will end either after 99 turns or after nine consecutive turns in which no new words are recalled. EEG activity will be recorded continuously throughout this recall phase.

**Recall 2 (On paper):**
Finally, all participants will complete an individual written free recall task (in their L2, English). They will receive a response sheet labelled with their participant identification number and will be instructed to write down as many words as they can remember from the initial study phase within 7 minutes. This final recall task will be completed individually without EEG recording.

# Data organisation

## Raw-data structure

Each experimental unit consists of a triad:

- participant `xxx_1`;
- participant `xxx_2`;
- participant `xxx_3`.

Here, `xxx` is the numerical code assigned to the triad. For example, triad `303` comprises participants `303_1`, `303_2`, and `303_3`.

All participant folders are expected to be located immediately within a single raw-data directory.

```text
data_raw/
├── 303_1/
│   ├── recording_name.dat
│   ├── recording_name.dap
│   ├── recording_name.rs3
│   └── recording_name.ceo
├── 303_2/
│   ├── recording_name.dat
│   ├── recording_name.dap
│   ├── recording_name.rs3
│   └── recording_name.ceo
├── 303_3/
│   ├── recording_name.dat
│   ├── recording_name.dap
│   ├── recording_name.rs3
│   └── recording_name.ceo
└── ...
```

The expected participant-folder naming rule is:

```text
<triad code>_<triad member>
```

where:

- `<triad code>` is a numerical identifier such as `303`;
  _[Explain how triad codes are assigned and whether the numerical sequence has any experimental meaning.]_
- `<triad member>` is `1`, `2`, or `3`.
  _[Explain whether `_1`, `_2`, and `_3` identify different experimental roles, seating positions, task roles, or merely participant order.]_

The four CURRY files for a single recording must share the same base filename. For example:

```text
recording_name.dat
recording_name.dap
recording_name.rs3
recording_name.ceo
```

## Experimental conditions

| Condition | Description | Expected marker(s) | Notes |
|---|---|---|---|
| _Recall Phase_ | _Number of the turn_ | _1-99_ | _the same for nominal and collaborative, both have 99 turns in total_ |
| _Collaborative Recall_ | _Collaborative condition_ | _210_ | _code to indicate the collaborative condition_ |
| _Collaborative Recall_ | _Participant 1_ | _101_ | _[Notes]_ |
| _Collaborative Recall_ | _Participant 2_ | _102_ | _[Notes]_ |
| _Collaborative Recall_ | _Participant 3_ | _103_ | _[Notes]_ |
| _Collaborative Recall_ | _Correct Recall_ | _121_ | _[Notes]_ |
| _Collaborative Recall_ | _Omission_ | _120_ | _[Notes]_ |
| _Nominal Recall_ | _Nominal condition_ | _100_ | _code to indicate the nominal condition_ |
| _Nominal Recall_ | _Participant code_ | _101_ | _[Notes]_ |
| _Nominal Recall_ | _Correct Recall_ | _121_ | _[Notes]_ |
| _Nominal Recall_ | _Description_ | _120_ | _[Notes]_ |

## EEG acquisition

| Parameter | Value |
|---|---|
| EEG system | Neuroscan SynAmps2 64-channel Amplifier / CURRY _[confirm version]_ | Quik-Cap with Ag/Ag/Cl – sintered electrodes
| Number of EEG systems | 3 |
| Number of channels | 64 |
| Sampling rate | 1000 Hz |
| Online reference | Between Cz and CPz |
| Ground electrode | AFz |
| Electrode montage | 10/20 standard International layout |
| Additional channels | 2 integrated bipolar leads for vertical and horizontal EOG (VEO, HEO) and Trigger |
| Online filters | high-pass filter at 0.5 Hz and a low-pass filter at 70 Hz |
| Impedance criterion | below 10 kΩ at the beginning of the recording |

## Event markers and synchronisation

The three EEG recordings contain event markers that were introduced with intended temporal synchrony. These markers will be used as reference points when aligning the recordings.

Please also describe:

- how the markers were generated;
- how they were transmitted to each EEG system;
- whether there may be hardware or software delays; YES
- whether any marker can be missing or duplicated; YES
- whether the three recordings started and stopped at different times; NO
- the expected precision of the apparent synchrony;
- The first marker defines the initial alignment point.

## Saved data structure

The initial importer saves the EEGLAB datasets using the following structure:

```text
data_derivatives/
└── 01_imported/
    ├── triad_303/
    │   ├── 303_1_raw.set
    │   ├── 303_2_raw.set
    │   └── 303_3_raw.set
    └── ...
```

This structure keeps the three members of a triad together while preserving a separate EEGLAB dataset for each recording.

# Proposed repository structure

```text
repository/
├── README.md
├── .gitignore
├── code/
│   ├── import/
│   │   └── import_curry_triads.m
│   ├── preprocessing/
│   ├── synchronisation/
│   ├── analysis/
│   └── utilities/
├── config/
│   └── README.md
├── docs/
│   └── figures/
└── tests/
```

# Software requirements

```text
MATLAB R2025a or newer
```

```text
EEGLAB v2026.0.0
```

Add only the EEGLAB root directory, then start EEGLAB normally so it can manage its own paths and plug-ins.

## Required EEGLAB plug-ins

### FileIO

The initial import function uses:

```matlab
EEG = pop_fileio(datFile);
```

## Plug-ins expected during later preprocessing

| Plug-in | Purpose | Required version |
|---|---|---|
| Clean Rawdata | Automated channel and high-amplitude artifact handling, including ASR | _[add]_ |
| ICLabel | Automated classification of independent components | _[add]_ |
| DIPFIT | Dipole fitting and source-related metadata | _[add]_ |
| FIRfilt | EEGLAB FIR filtering functions, when required | _[add]_ |
| _[Other plug-in]_ | _[Purpose]_ | _[add]_ |

---

# The functions:

To be used in the same order presented here.

### `import_curry_triads.m`

```text
code/import/import_curry_triads.m
```

The `import_curry_triads` function imports raw CURRY/Neuroscan EEG recordings organised by participant triads. It:

- identifies participant folders named `<triad code>_1`, `<triad code>_2`, and `<triad code>_3`;
- groups participant recordings by triad code;
- checks that each folder contains one complete CURRY dataset, including the `.dat` file and its companion files;
- rejects folders containing missing or ambiguous recordings;
- checks for unsupported compressed CURRY data when possible;
- imports each recording into EEGLAB using `pop_fileio`;
- validates the resulting EEGLAB dataset;
- assigns standard channel locations after temporarily mapping `CB1` and `CB2` to `I1` and `I2`;
- adds participant, triad, and import information to `EEG.etc`;
- saves each imported recording as an EEGLAB `.set` dataset;
- returns a triad-level summary and an import log describing the outcome of each recording.

#### Example

```matlab
rawDataDir = 'D:\TriadicEEG\data_raw';
outputDir  = 'D:\TriadicEEG\data_derivatives';

[triads, importLog] = import_curry_triads( ...
    rawDataDir, ...
    outputDir, ...
    'Overwrite', false, ...
    'ContinueOnError', true, ...
    'KeepEEGInMemory', false);
```

Inspect the import log with:

```matlab
disp(importLog);
```
---

### `synchronise_triad_markers`

```text
code/import/synchronise_triad_markers.m
```

The `synchronise_triad_markers` function synchronises the event markers and duration of three continuous EEGLAB recordings belonging to the same participant triad. It:

- loads the three `.set` datasets and checks that they have the same sampling rate;
- extracts the experimental markers while excluding specified event types such as `boundary`, `100008`, `249` (the last two we don't know what they are);
- aligns the three marker sequences and identifies markers missing from individual recordings;
- reconstructs a complete marker sequence shared by all three recordings;
- calculates a common marker timeline using the median relative latency across the recordings in which each marker was originally present;
- trims each recording so that it begins exactly 2 seconds before the first common marker;
- assigns identical marker types and sample latencies to all three datasets;
- trims each recording 10 seconds after the final common marker;
- rebuilds `EEG.event`, `EEG.urevent`, and their corresponding links;
- verifies that the final marker sequences and latencies are identical;
- saves the synchronised datasets with `_sync` appended to their original filenames;
- returns the three synchronised datasets, a marker synchronisation table, and a summary of the procedure.

  #### Example

```matlab
% Define the paths to the three recordings belonging to one triad.
setFile1 = 'D:\TriadicEEG\303_1_raw.set';
setFile2 = 'D:\TriadicEEG\303_2_raw.set';
setFile3 = 'D:\TriadicEEG\303_3_raw.set';

% Define where the synchronised datasets will be saved.
outputDir = 'D:\TriadicEEG\synchronised';

% Synchronise the marker sequences and latencies.
[EEGsync, syncTable, summary] = ...
    synchronise_triad_markers( ...
        setFile1, ...
        setFile2, ...
        setFile3, ...
        'IgnoreTypes', {'boundary', '100008', '249'}, ...
        'OutputDir', outputDir);
```

The function saves the following datasets:

```text
303_1_raw_sync.set
303_2_raw_sync.set
303_3_raw_sync.set
```

The synchronisation results can be inspected using:

```matlab
disp(syncTable);
disp(summary);
```

The three synchronised datasets are also returned in:

```matlab
EEGsync{1}
EEGsync{2}
EEGsync{3}
```

### `run_all_triad_synchronisation`

The `run_all_triad_synchronisation` function (it is a wrapper) applies `synchronise_triad_markers` to every participant triad contained in a root directory. It:

- identifies folders named `triad_<code>`, such as `triad_303`;
- locates the three corresponding datasets:
  - `<code>_1_raw.set`;
  - `<code>_2_raw.set`;
  - `<code>_3_raw.set`;
- checks that all three recordings are available before processing the triad;
- excludes non-experimental events such as `boundary`, `100008`, and `249` from marker synchronisation;
- runs `synchronise_triad_markers` separately for every complete triad;
- saves the synchronised recordings inside corresponding output folders;
- continues processing the remaining triads when an error occurs, when requested;
- produces a triad-level summary containing file information, marker counts, inserted markers, sampling rate, duration, and processing status;
- combines the marker-level synchronisation tables from all successfully processed triads;
- saves the complete report as both an Excel file and a MATLAB `.mat` file.

#### Expected input structure

```text
L2L1_data_derivatives/
├── triad_303/
│   ├── 303_1_raw.set
│   ├── 303_2_raw.set
│   └── 303_3_raw.set
├── triad_306/
│   ├── 306_1_raw.set
│   ├── 306_2_raw.set
│   └── 306_3_raw.set
└── ...
```

#### Output structure

```text
L2L1_data_derivatives_synchronised/
├── triad_303/
│   ├── 303_1_raw_sync.set
│   ├── 303_2_raw_sync.set
│   └── 303_3_raw_sync.set
├── triad_306/
│   ├── 306_1_raw_sync.set
│   ├── 306_2_raw_sync.set
│   └── 306_3_raw_sync.set
├── triad_synchronisation_report.xlsx
└── triad_synchronisation_report.mat
```

The Excel report contains two worksheets:

- **Triad summary:** one row per triad, including processing status, marker counts, inserted markers, sampling rate, output duration, and any error messages;
- **Marker details:** one row per marker and triad, including its presence in each original recording and its final synchronised latency.

#### Example

```matlab
% Folder containing triad_303, triad_306, triad_319, etc.
inputRootDir = ...
    'E:\Granada\data_derivatives\01_imported';

% Folder where the synchronised datasets and reports will be saved.
outputRootDir = ...
    'E:\Granada\data_derivatives\02_synchronised';

% Run marker synchronisation for every available triad.
[batchSummary, allSyncTable] = ...
    run_all_triad_synchronisation( ...
        inputRootDir, ...
        outputRootDir, ...
        'IgnoreTypes', ...
        {'boundary', '100008', '249'}, ...
        'ContinueOnError', ...
        true);
```

Triads that produced an error can be inspected using:

```matlab
batchSummary(batchSummary.Status == "Error", :)
```

Triads in which one or more markers were reconstructed can be inspected using:

```matlab
batchSummary( ...
    batchSummary.InsertedMarkers1 > 0 | ...
    batchSummary.InsertedMarkers2 > 0 | ...
    batchSummary.InsertedMarkers3 > 0, :)
```

Marker-level information for a specific triad can be inspected using:

```matlab
allSyncTable(allSyncTable.TriadCode == "303", :)
```

## ASR cleaning of synchronised triads

### `clean_triad_asr`

The `clean_triad_asr` function performs conservative artefact cleaning on the three synchronised EEG recordings belonging to one triad.

The function is intentionally restricted to preprocessing up to the removal of unusable temporal periods. It does **not** interpolate rejected channels, rereference the data, run ICA, or apply ICLabel. These operations will be implemented separately so that ASR cleaning and ICA preparation remain modular and can be independently inspected or repeated.

The central requirement of this function is to preserve exact temporal correspondence across the three participants. ASR is applied independently to each recording, but any temporal period classified as unusable in one participant is subsequently removed from all three datasets.

### Processing overview

For each triad, the function:

1. loads the three synchronised EEGLAB `.set` datasets;
2. verifies that the recordings have the same sampling rate and number of samples;
3. verifies that experimental event types and latencies are identical across recordings;
4. identifies EEG, EOG, mastoid, and Trigger channels;
5. high-pass filters the EEG and EOG channels once at 1 Hz;
6. leaves the Trigger channel unfiltered;
7. identifies flat-lined and persistently noisy EEG channels;
8. protects frontal EEG channels from correlation-only rejection;
9. uses the EOG channels diagnostically when evaluating frontal channels;
10. runs Artefact Subspace Reconstruction independently for each participant;
11. identifies temporal periods that remain severely contaminated after ASR;
12. combines the three participant-specific bad-period masks;
13. removes the union of unusable periods from all three recordings;
14. confirms that the cleaned datasets retain identical sample counts and event timing;
15. saves the cleaned datasets and detailed quality-control reports.

### Preprocessing decisions

#### High-pass filtering

The EEG and EOG channels are high-pass filtered once at 1 Hz before bad-channel detection and ASR.

A separate low-frequency analysis copy is not created because the planned analyses do not include event-related potentials and activity below 1 Hz is not required.

The Trigger channel is not filtered.

#### Line-noise processing

No line-noise correction is performed.

The function does not apply:

- CleanLine;
- Zapline-plus;
- notch filtering;
- line-noise-based channel rejection.

This decision was made after inspection of the recordings indicated that line noise was not a relevant problem.

#### Auxiliary channels

The datasets contain the following non-scalp channels:

- `HEO`;
- `VEO`;
- `Trigger`.

These channels are preserved in the datasets but excluded from:

- bad-EEG-channel detection;
- ASR calibration;
- ASR reconstruction;
- residual-window rejection.

The Trigger channel remains unchanged apart from the later removal of temporal periods shared across the triad.

`M1` and `M2` contain normal EEG-like activity and are treated as EEG channels during the cleaning procedure.

### Protection of frontal channels

Frontal and frontopolar electrodes frequently contain strong ocular activity. Such activity can reduce their correlation with neighbouring electrodes and cause otherwise functioning channels to be rejected by automatic channel-correlation procedures.

The function therefore defines a set of protected frontal channels:

```matlab
{
    'Fp1'
    'Fpz'
    'Fp2'
    'AF7'
    'AF3'
    'AFz'
    'AF4'
    'AF8'
    'F7'
    'F8'
}
```

Protected frontal channels are not removed solely because they fail the channel-correlation criterion.

They may still be removed when they show strong evidence of electrode failure, such as a sustained flat line.

The `HEO` and `VEO` channels are used diagnostically to determine whether unusual frontal activity is consistent with ocular contamination. The original EEG data are not modified through EOG regression at this stage.

This approach preserves ocular activity that can later be separated using ICA while reducing the risk of systematically removing electrodes close to the eyes.

### Bad-channel detection

Bad-channel detection is performed independently for each participant.

The default channel-correlation threshold is:

```matlab
ChannelCriterion = 0.75;
```

Flat-lined channels are identified using:

```matlab
FlatlineCriterion = 5;
```

This corresponds to a continuous flat period of at least 5 seconds.

Line-noise-based channel detection is disabled.

Each participant may retain a different number of EEG channels. Temporal correspondence across participants does not require identical channel sets.

The function stores the complete original channel-location structure before removing any channel:

```matlab
EEG.etc.triad_asr_cleaning.originalChanlocs
```

This information will later be used to interpolate rejected scalp channels before ICA.

### Artefact Subspace Reconstruction

ASR is run separately for each participant using a conservative burst criterion:

```matlab
BurstCriterion = 20;
```

ASR is configured to reconstruct contaminated subspaces rather than automatically reject every affected temporal period.

The internal high-pass stage of `clean_rawdata` is disabled because the datasets have already been explicitly filtered at 1 Hz.

No line-noise processing is performed within ASR.

The principal settings are equivalent to:

```matlab
'BurstCriterion', 20
'BurstRejection', 'off'
'WindowCriterion', 'off'
'Highpass', 'off'
'LineNoiseCriterion', 'off'
```

ASR reconstruction preserves the original number of samples. A sample altered by ASR is therefore not automatically considered unusable.

### Residual bad-period detection

After ASR reconstruction, each recording is evaluated to identify periods that remain severely contaminated.

Protected frontal channels are excluded from this residual-window assessment by default so that blinks and eye movements do not independently cause the removal of otherwise usable data.

The default residual-window criterion is:

```matlab
WindowCriterion = 0.30;
```

This means that a temporal window is classified as unusable only when a substantial proportion of the evaluated EEG channels remains contaminated after ASR.

Each participant produces an individual logical mask:

```matlab
participantBadMask1
participantBadMask2
participantBadMask3
```

The common triad-level bad-period mask is calculated as:

```matlab
sharedBadMask = ...
    participantBadMask1 | ...
    participantBadMask2 | ...
    participantBadMask3;
```

The retained mask is:

```matlab
sharedKeepMask = ~sharedBadMask;
```

The same rejected intervals are then removed from all three complete recordings, including their EEG, EOG, and Trigger channels.

This guarantees:

```matlab
EEGclean{1}.pnts == EEGclean{2}.pnts
EEGclean{2}.pnts == EEGclean{3}.pnts
```

and preserves exact temporal correspondence across participants.

### Acquisition reference

The acquisition is assumed to have used the dedicated Quik-Cap reference located between Cz and CPz.

The reference signal was not stored as one of the 67 imported channels and is not restored as a zero-valued channel.

This assumption is stored as dataset metadata but does not otherwise affect this function because rereferencing is not performed at this stage.

```text
Dedicated Quik-Cap reference between Cz and CPz;
not stored and not restored
```

### Function syntax

```matlab
[EEGclean, ...
 participantTable, ...
 intervalTable, ...
 channelTable, ...
 triadSummary] = ...
    clean_triad_asr( ...
        setFile1, ...
        setFile2, ...
        setFile3, ...
        'OutputDir', outputDir);
```

### Example

```matlab
% Three synchronised recordings belonging to one triad.
setFile1 = ...
    'E:\Granada\data_derivatives\02_synchronised\triad_303\303_1_raw_sync.set';

setFile2 = ...
    'E:\Granada\data_derivatives\02_synchronised\triad_303\303_2_raw_sync.set';

setFile3 = ...
    'E:\Granada\data_derivatives\02_synchronised\triad_303\303_3_raw_sync.set';

% Output folder for the ASR-cleaned datasets and QC reports.
outputDir = ...
    'E:\Granada\data_derivatives\03_asr_cleaned\triad_303';

[EEGclean, ...
 participantTable, ...
 intervalTable, ...
 channelTable, ...
 triadSummary] = ...
    clean_triad_asr( ...
        setFile1, ...
        setFile2, ...
        setFile3, ...
        'OutputDir', outputDir);
```

### Changing the protected frontal channels

The protected frontal-channel list can be modified using the `ProtectedFrontalLabels` option:

```matlab
[EEGclean, ...
 participantTable, ...
 intervalTable, ...
 channelTable, ...
 triadSummary] = ...
    clean_triad_asr( ...
        setFile1, ...
        setFile2, ...
        setFile3, ...
        'OutputDir', outputDir, ...
        'ProtectedFrontalLabels', ...
        { ...
            'Fp1', ...
            'Fpz', ...
            'Fp2', ...
            'AF7', ...
            'AF3', ...
            'AFz', ...
            'AF4', ...
            'AF8' ...
        });
```

### Output datasets

For triad `303`, the function produces:

```text
303_1_raw_sync_asr.set
303_2_raw_sync_asr.set
303_3_raw_sync_asr.set
```

The files contain:

- EEG data high-pass filtered at 1 Hz;
- participant-specific bad EEG channels removed;
- transient artefacts reconstructed by ASR;
- the same unusable temporal periods removed from all three recordings;
- preserved EOG and Trigger channels;
- original channel-location information stored in `EEG.etc`;
- metadata describing the cleaning settings and results.

The files are not yet interpolated or rereferenced and do not contain an ICA decomposition.

### Quality-control reports

The function also generates:

```text
303_asr_qc.xlsx
303_asr_qc.mat
```

The Excel report contains four worksheets.

#### `Participants`

One row is included for each participant. The table records information such as:

- input filename;
- output filename;
- sampling rate;
- original number of samples;
- final number of samples;
- original recording duration;
- final recording duration;
- original number of EEG channels;
- final number of EEG channels;
- number of rejected EEG channels;
- percentage of rejected EEG channels;
- number of samples modified by ASR;
- percentage of samples modified by ASR;
- number of samples independently flagged as unusable;
- number of samples removed by the shared triad mask;
- percentage of shared time removed;
- percentage of data retained.

#### `Channels`

One row is included for each original EEG channel and participant. The table records:

- participant;
- channel label;
- whether the channel was protected as frontal;
- whether it was detected as flat-lined;
- whether it failed the channel-correlation criterion;
- whether it was retained or removed;
- EOG-related diagnostic information;
- the final channel decision.

Possible channel decisions include:

```text
Retained_standard
Retained_protected_frontal
Retained_after_EOG_QC
Rejected_flatline
Rejected_persistent_noise
Requires_review
```

#### `Removed intervals`

One row is included for each shared rejected interval. The table records:

- triad identifier;
- original starting sample;
- original ending sample;
- starting time in seconds;
- ending time in seconds;
- interval duration;
- whether participant 1 flagged the interval;
- whether participant 2 flagged the interval;
- whether participant 3 flagged the interval.

#### `Triad summary`

This worksheet records the principal triad-level results, including:

- total number of original samples;
- total number of removed samples;
- percentage of data removed;
- final number of samples;
- final duration;
- number of samples flagged by each participant;
- overlap between participant masks;
- confirmation of identical final sample counts;
- confirmation of identical event sequences and latencies.

### MATLAB quality-control variables

The `.mat` report stores the summary tables and the complete logical masks:

```matlab
qcMasks.asrChangedMasks
qcMasks.participantBadMasks
qcMasks.sharedBadMask
qcMasks.sharedKeepMask
qcMasks.sharedRemovedIntervals
qcMasks.sharedRetainedIntervals
```

These variables allow the cleaning decisions to be inspected or visualised without rerunning ASR.

### Interpretation of ASR statistics

The function distinguishes between:

1. samples modified by ASR;
2. samples classified as irrecoverable after ASR;
3. samples removed from the complete triad.

A sample modified by ASR is not necessarily rejected.

Only samples that remain severely contaminated after ASR contribute to a participant-specific bad-period mask. The union of these masks determines the time removed from all three recordings.

This distinction should be retained when reporting the preprocessing procedure.

### Subsequent preprocessing

The output of `clean_triad_asr` is intended to be passed to a separate ICA-preparation procedure.

The subsequent pipeline will include:

1. interpolation of participant-specific rejected scalp channels;
2. arithmetic average rereferencing;
3. exclusion of EOG and Trigger channels from the reference calculation;
4. estimation of the effective data rank;
5. ICA decomposition using explicit dimensionality reduction where required;
6. ICLabel classification;
7. manual inspection and rejection of artifactual independent components.

Interpolation and rereferencing are deliberately not implemented in `clean_triad_asr`.
