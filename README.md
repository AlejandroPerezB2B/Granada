# Triadic EEG Analysis Pipeline

> **Project title:** _ColMem_

This repository contains the MATLAB and EEGLAB code used to import, organise, synchronise, preprocess and analyse EEG data recorded simultaneously from participant triads.

## Authors:

- **Alejandro Pérez** — `@AlejandroPerezB2B`
- **Celia Sissi Stijsiger** — `@CeliaSissi`

## Background

This section should provide sufficient information for a researcher not involved in data collection to understand the experiment and the task.

## Experimental task

_[Describe the task chronologically from the participant's perspective.]_

Suggested information to include:

- instructions given to the participants;
- duration and number of blocks;
- trial structure;
- stimuli;
- response requirements;
- interaction rules;
- breaks;
- counterbalancing;
- condition order;
- any role changes within the triad.

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
| _Study phase_ | _Specific word onset_ | _1-99_ | _both nominal and collaborative conditions have the same study phase_ |
| _Collaborative Recall_ | _Participant 1_ | _101_ | _[Notes]_ |
| _Collaborative Recall_ | _Participant 2_ | _102_ | _[Notes]_ |
| _Collaborative Recall_ | _Participant 3_ | _103_ | _[Notes]_ |
| _Collaborative Recall_ | _Correct Recall_ | _121_ | _[Notes]_ |
| _Collaborative Recall_ | _Omission_ | _120_ | _[Notes]_ |
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
MATLAB [R2025a Alejandro]
```

```text
EEGLAB version: v2026.0.0
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
- extracts the experimental markers while excluding specified event types such as `boundary`;
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
        'IgnoreTypes', {'boundary'}, ...
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
