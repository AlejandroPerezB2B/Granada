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
| _[Condition 1]_ | _[Description]_ | _[Marker code]_ | _[Notes]_ |
| _[Condition 2]_ | _[Description]_ | _[Marker code]_ | _[Notes]_ |
| _[Condition 3]_ | _[Description]_ | _[Marker code]_ | _[Notes]_ |
| _[Condition 1]_ | _[Description]_ | _[Marker code]_ | _[Notes]_ |
| _[Condition 2]_ | _[Description]_ | _[Marker code]_ | _[Notes]_ |
| _[Condition 3]_ | _[Description]_ | _[Marker code]_ | _[Notes]_ |
| _[Condition 1]_ | _[Description]_ | _[Marker code]_ | _[Notes]_ |
| _[Condition 2]_ | _[Description]_ | _[Marker code]_ | _[Notes]_ |
| _[Condition 3]_ | _[Description]_ | _[Marker code]_ | _[Notes]_ |

## EEG acquisition

| Parameter | Value |
|---|---|
| EEG system | Neuroscan SynAmps RT 64-channel Amplifier / CURRY _[confirm version]_ | Quik-Cap with Ag/Ag/Cl – sintered electrodes
| Number of EEG systems | 3 |
| Number of channels | 64 |
| Sampling rate | 1000 Hz |
| Online reference | Between Cz and CPz |
| Ground electrode | AFz |
| Electrode montage | 10/20 standard International layout |
| Additional channels | 2 integrated bipolar leads for vertical and horizontal EOG (VEO, HEO) and Trigger |
| Online filters | _[add]_ |
| Impedance criterion | _[add]_ |

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

## MATLAB

The exact MATLAB version used for the project should be recorded here once agreed by both authors.

```text
MATLAB version: [to be added]
```

## EEGLAB

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

# Initial import

The function:

```text
code/import/import_curry_triads.m
```

performs the following operations:

1. identifies participant folders matching `number_1`, `number_2`, or `number_3`;
2. groups participant folders by triad code;
3. checks that each recording contains a `.dat` file and its companion files;
4. rejects ambiguous folders containing more than one complete CURRY dataset;
5. detects the CURRY compressed-data identifier when possible;
6. imports the `.dat` recording using `pop_fileio`;
7. checks the resulting EEGLAB structure;
8. adds triad and participant metadata to `EEG.etc`;
9. saves each imported recording as an EEGLAB `.set` dataset;
10. returns a triad summary and an import log.

## Example

```matlab
rawDataDir = 'D:\TriadicEEG\data_raw';
outputDir  = 'D:\TriadicEEG\data_derivatives\01_imported';

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


