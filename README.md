# Triadic EEG Analysis Pipeline

> **Project title:** _[Replace this line with the final experiment title]_

This repository contains the MATLAB and EEGLAB code used to organise, import, preprocess, synchronise, and analyse EEG data recorded simultaneously from participant triads.

The project is currently under active development. Processing decisions, software versions, and changes to the data structure should be documented in this README as the pipeline develops.

## Authors

- **Alejandro Pérez** — `@AlejandroPerezB2B`
- **Celia Sissi Stijsiger** — `@CeliaSissi`

## Repository status

The current development stage focuses on:

1. documenting the experimental design and raw-data structure;
2. importing the three EEG recordings belonging to each triad;
3. checking the event markers recorded in the three systems;
4. identifying markers that can be used to align the recordings;
5. developing the subsequent preprocessing and analysis pipeline.

---

# Experiment rationale

> **Section to be completed by Celia**

This section should provide enough information for a researcher who was not involved in data collection to understand the experiment, the task, the hypotheses, and the meaning of the EEG markers.

## Background

_[Briefly describe the theoretical background and the scientific problem addressed by the experiment.]_

## Research questions

1. _[Primary research question]_
2. _[Secondary research question]_
3. _[Additional exploratory question, if applicable]_

## Hypotheses

### Primary hypothesis

_[State the main directional or non-directional hypothesis.]_

### Secondary hypotheses

- _[Hypothesis 2]_
- _[Hypothesis 3]_

## Participants and triadic structure

_[Describe the participant population, inclusion and exclusion criteria, recruitment procedure, and intended sample size.]_

Each experimental unit consists of a triad:

- participant `xxx_1`;
- participant `xxx_2`;
- participant `xxx_3`.

Here, `xxx` is the numerical code assigned to the triad. For example, triad `303` comprises participants `303_1`, `303_2`, and `303_3`.

### Meaning of participant positions

_[Explain whether `_1`, `_2`, and `_3` identify different experimental roles, seating positions, EEG systems, task roles, or merely participant order.]_

### Triad-code assignment

_[Explain how triad codes are assigned and whether the numerical sequence has any experimental meaning.]_

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

## Experimental conditions

| Condition | Description | Expected marker(s) | Notes |
|---|---|---|---|
| _[Condition 1]_ | _[Description]_ | _[Marker code]_ | _[Notes]_ |
| _[Condition 2]_ | _[Description]_ | _[Marker code]_ | _[Notes]_ |
| _[Condition 3]_ | _[Description]_ | _[Marker code]_ | _[Notes]_ |

## EEG acquisition

Complete the following table using the acquisition settings.

| Parameter | Value |
|---|---|
| EEG system | Neuroscan / CURRY _[confirm version]_ |
| Number of EEG systems | 3 |
| Number of channels | _[add]_ |
| Sampling rate | _[add]_ Hz |
| Online reference | _[add]_ |
| Ground electrode | _[add]_ |
| Electrode montage | _[add]_ |
| Additional channels | _[EOG, ECG, trigger, auxiliary channels, etc.]_ |
| Online filters | _[add]_ |
| Impedance criterion | _[add]_ |
| Recording software version | _[add]_ |

## Event markers and synchronisation

The three EEG recordings contain event markers that were introduced with intended temporal synchrony. These markers will be used as reference points when aligning the recordings.

Document all markers in the following table.

| Marker | Meaning | Sent to all systems? | Expected timing | Used for alignment? |
|---|---|---:|---|---:|
| _[code]_ | _[description]_ | Yes / No | _[task stage]_ | Yes / No |
| _[code]_ | _[description]_ | Yes / No | _[task stage]_ | Yes / No |

Please also describe:

- how the markers were generated;
- how they were transmitted to each EEG system;
- whether there may be hardware or software delays;
- whether any marker can be missing or duplicated;
- whether the three recordings started and stopped at different times;
- the expected precision of the apparent synchrony;
- which marker or marker sequence should define the initial alignment point.

## Behavioural and additional data

_[Describe any behavioural, audio, video, physiological, questionnaire, or task-log data associated with each triad.]_

Include the expected filenames and explain how these files can be linked to the triad and participant identifiers.

## Exclusion criteria

### Participant-level criteria

- _[Criterion 1]_
- _[Criterion 2]_

### Recording-level criteria

- _[Criterion 1]_
- _[Criterion 2]_

### Trial- or segment-level criteria

- _[Criterion 1]_
- _[Criterion 2]_

## Figures

Store figures used by this README in:

```text
docs/figures/
```

### Figure 1: Experimental setup

```markdown
![Experimental setup](docs/figures/figure01_experimental_setup.png)

*Figure 1. [Describe the physical arrangement of the participants, EEG systems, displays, response devices, and any other relevant equipment.]*
```

### Figure 2: Trial structure

```markdown
![Trial structure](docs/figures/figure02_trial_structure.png)

*Figure 2. [Describe the sequence and duration of the trial events and identify the relevant EEG markers.]*
```

### Figure 3: Synchronisation scheme

```markdown
![Synchronisation scheme](docs/figures/figure03_synchronisation.png)

*Figure 3. [Describe how common markers are delivered to the three EEG recordings and how they will be used during offline alignment.]*
```

Additional figures may be added when useful.

---

# Data organisation

## Raw-data structure

All participant folders are expected to be located immediately inside one raw-data directory.

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
- `<triad member>` is `1`, `2`, or `3`.

The four CURRY files belonging to one recording must have the same base filename. For example:

```text
recording_name.dat
recording_name.dap
recording_name.rs3
recording_name.ceo
```

The `.dat` file is selected for import. The associated `.dap`, `.rs3`, and `.ceo` files contain information required to interpret the recording, including acquisition parameters, channel information, sensor positions, and event information.

The importer also accepts `.cef` as the event file when it is present instead of `.ceo`.

## Imported-data structure

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

## Files that must not be committed

Raw EEG files and derived datasets should normally remain outside version control. A project `.gitignore` should include at least:

```gitignore
# Raw and derived data
data_raw/
data_derivatives/

# EEGLAB datasets
*.set
*.fdt

# MATLAB temporary and autosave files
*.asv
*.m~
```

Only analysis code, documentation, small configuration files, and non-identifying example metadata should be committed to GitHub.

---

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

Suggested responsibilities:

- `code/import/`: conversion of proprietary raw files to EEGLAB datasets;
- `code/preprocessing/`: filtering, channel handling, artifact correction, ICA, and related procedures;
- `code/synchronisation/`: alignment of the three recordings using common markers;
- `code/analysis/`: experiment-specific EEG analyses;
- `code/utilities/`: reusable helper functions;
- `config/`: channel lists, marker dictionaries, condition definitions, and processing parameters;
- `tests/`: tests using small or synthetic datasets that do not contain identifiable participant data.

---

# Software requirements

## MATLAB

The exact MATLAB version used for the project should be recorded here once agreed by both authors.

```text
MATLAB version: [to be added]
```

## EEGLAB

A stable EEGLAB release is required.

```text
EEGLAB version: [to be added]
```

Do not recursively add every EEGLAB subfolder to the MATLAB path. Add only the EEGLAB root directory and start EEGLAB normally so that it can manage its own paths and plug-ins.

## Required EEGLAB plug-ins

### FileIO

The initial import function uses:

```matlab
EEG = pop_fileio(datFile);
```

The FileIO plug-in provides access to FieldTrip's file-reading interface. Its CURRY reader recognises the `.dat` recording and uses the associated `.dap`, `.rs3`, and `.ceo` or `.cef` files.

The current reader does not support compressed CURRY recordings. Compressed recordings must first be converted in CURRY to a raw floating-point format.

## Plug-ins expected during later preprocessing

The definitive list will depend on the agreed pipeline. Likely components should be documented here when introduced.

| Plug-in | Purpose | Required version |
|---|---|---|
| Clean Rawdata | Automated channel and high-amplitude artifact handling, including ASR | _[add]_ |
| ICLabel | Automated classification of independent components | _[add]_ |
| DIPFIT | Dipole fitting and source-related metadata | _[add]_ |
| FIRfilt | EEGLAB FIR filtering functions, when required | _[add]_ |
| _[Other plug-in]_ | _[Purpose]_ | _[add]_ |

Each analysis release should report the exact MATLAB, EEGLAB, and plug-in versions used.

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

To test the importer while retaining the datasets in MATLAB:

```matlab
[triads, importLog] = import_curry_triads( ...
    rawDataDir, ...
    outputDir, ...
    'KeepEEGInMemory', true);
```

Keeping every raw dataset in memory may require substantial RAM. The default behaviour therefore saves each dataset and clears its EEG data before proceeding to the next participant.

---

# Synchronisation plan

The synchronisation implementation will be developed after the event structure has been inspected in several triads.

The planned stages are:

1. extract the imported marker sequences from all three members;
2. identify markers or marker sequences shared by the three recordings;
3. quantify sample-level timing differences between corresponding markers;
4. detect missing, duplicated, or reordered markers;
5. estimate the temporal offset between recordings;
6. determine whether a single offset is sufficient or whether clock drift must also be modelled;
7. align or trim the three recordings using the agreed method;
8. retain a synchronisation quality-control report for every triad.

No resampling, trimming, or marker-based temporal correction is performed by the initial import function.

---

# Coding conventions

All project functions should:

- contain a detailed function header;
- describe inputs, outputs, assumptions, and dependencies;
- explain the rationale for important processing decisions;
- validate inputs before modifying data;
- produce informative errors and warnings;
- avoid hard-coded computer-specific paths;
- store relevant processing parameters in the output;
- preserve a clear distinction between raw, imported, preprocessed, and analysed data;
- use deterministic settings where random operations are involved;
- be suitable for batch processing;
- avoid silently excluding participants, channels, trials, or events.

Experiment-specific constants such as marker codes, channel groups, and condition labels should eventually be stored in configuration files rather than repeated across functions.

---

# GitHub collaboration

The repository is jointly maintained by Alejandro Pérez and Celia Sissi Stijsiger (`@CeliaSissi`).

Recommended workflow:

1. create a branch for each feature or correction;
2. use descriptive commit messages;
3. open a pull request before merging substantial changes;
4. document changes that affect preprocessing decisions;
5. avoid committing raw or identifiable participant data;
6. tag analysis versions used for manuscripts, reports, or archived results.

Example branch names:

```text
feature/curry-import
feature/event-synchronisation
feature/preprocessing
fix/import-event-types
docs/experiment-rationale
```

---

# Reproducibility record

Complete this table whenever an analysis version is frozen.

| Component | Version or commit |
|---|---|
| Repository commit | _[add]_ |
| MATLAB | _[add]_ |
| EEGLAB | _[add]_ |
| FileIO | _[add]_ |
| Clean Rawdata | _[add]_ |
| ICLabel | _[add]_ |
| DIPFIT | _[add]_ |
| Operating system | _[add]_ |
| Date | _[add]_ |

---

# To be confirmed

- final project and repository name;
- logic used to assign triad codes;
- meaning of participant suffixes `_1`, `_2`, and `_3`;
- whether each participant folder always contains exactly one recording;
- whether `.ceo` is always present or `.cef` may also occur;
- CURRY and Neuroscan software versions;
- sampling rate and channel montage;
- expected common marker codes;
- whether the recording clocks exhibit measurable drift;
- preprocessing steps and their order;
- criteria for excluding incomplete triads or recordings.
