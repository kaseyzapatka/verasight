# Verasight Data Scientist Case Study

Submission for the Verasight Data Scientist case study. All analysis is in **R**, with code
commented and organized so a teammate could pick it up and reuse it on a different survey.

> **Status:** work in progress — this README will get a final pass once all tasks are complete.

## Overview

The case study spans four tasks using four provided data files:

| Task | What it does |
|---|---|
| **Task 1** | A reusable, documented function that builds **weighted proportion tables** (survey outcome × demographic) with question wording attached. |
| **Task 2** | **Response "density"** analysis — what share of users account for 50% of responses, the same restricted to recent registrants, and a percentile visualization. |
| **Task 3** | A written design for an **AI-assisted workflow to flag potentially fraudulent open-ended responses**. |
| **Task 4** | **Project scoping** questions and a time-intensity **ranking** across four project types. |

## Repository structure

```
verasight/
├── code/                     # analysis scripts (run from repo root)
│   └── 00_explore.R          # read in all four files and look around
├── utils/                    # shared, reusable helpers ("team toolbox")
│   └── read_survey.R         # documented wrapper around readRDS() w/ schema guard
├── data/                     # provided input data (not modified)
│   ├── 2024-054_responses.rds    # Task 1: recent survey responses (968 × 17)
│   ├── 2024-054_reference.rds    # Task 1: question wording for q28–q35
│   ├── full-response-db.rds      # Task 2: aggregate responses (187,803 × 3)
│   └── users.rds                 # Task 2: registered panelists (85,744 × 4)
├── notes/
│   └── style.md              # visualization + write-up style reference
├── CLAUDE.md                 # project guide: data dictionary, conventions, data wrinkles
├── ai_log.md                 # running record of AI use (raw material for the memo)
├── ai_memo.md                # how AI tools were used (per the assignment) — planned
└── README.md
```

Internal working notes (planning, job-ad crosswalk, QA scratch) are kept out of version
control.

## How to run

Requires R (developed on 4.2.3) with `dplyr` and `survey`.

```r
# Install dependencies if needed:
install.packages(c("dplyr", "survey"))
```

```bash
# From the repo root:
Rscript code/00_explore.R        # profile + explore all four data files
```

Analysis scripts source the shared loader, so run them from the repo root (paths are relative):

```r
source("utils/read_survey.R")
responses <- read_survey("data/2024-054_responses.rds")
```

## Data notes

Key data characteristics and assumptions (weight handling, the "all users in the database"
denominator choice for Task 2, the reference date for "last 90 days", and duplicate/orphan
rows) are documented in `CLAUDE.md` and will be summarized in the methods write-up.

## AI use

Generative AI was used to complete this case study; `ai_memo.md` documents the models,
tools, harnessing, prompts, accuracy checks, and corrections, per the assignment.

## Contact

Submitted to careers@verasight.io.
