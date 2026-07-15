# Verasight Data Scientist Case Study

Submission for the Verasight Data Scientist case study. All analysis is in **R**, organized so
a teammate could pick it up and reuse it on a different survey. The four write-ups are published
as a small **Quarto website** (`docs/`), with a reusable helper toolbox in `utils/`.

## The four tasks

| Task | What it does |
|---|---|
| **Task 1** | A reusable, roxygen-documented function that builds **weighted proportion tables** (survey outcome × demographic) with question wording attached, using the `survey` package. |
| **Task 2** | **Response "density"** analysis — the smallest share of users accounting for 50% of responses (overall and among recent registrants), plus concentration curves. |
| **Task 3** | A design memo for a tiered **AI-assisted workflow to flag fraudulent open-ended responses** (cheap signals → LLM → human review). |
| **Task 4** | **Project scoping** questions and a time-intensity **ranking** across four project types. |

## Repository structure

```
verasight/
├── index.qmd                  # website home page
├── _quarto.yml                # Quarto website config (renders to docs/)
├── docs/                      # rendered website  ← serve this (GitHub Pages)
├── reports/                   # task write-ups (Quarto source)
│   ├── task1.qmd  task2.qmd  task3.qmd  task4.qmd
├── code/                      # analysis scripts (run from repo root)
│   ├── 00_explore.R           # profile all four data files
│   ├── 01_task1_crosstabs.R   # Task 1 — build tables, export PNGs
│   └── 02_task2_density.R     # Task 2 — density metrics + curve PNGs
├── utils/                     # reusable "team toolbox" (roxygen-documented)
│   ├── read_survey.R          # readRDS() wrapper with a schema guard
│   ├── weighted_crosstab.R    # Task 1 function
│   └── density.R              # Task 2 concentration helpers
├── output/                    # generated figures/tables (PNG, browsable on GitHub)
│   ├── task1/                 # 48 crosstab tables (one per outcome × demographic)
│   └── task2/                 # 2 concentration curves
├── notes/style.md             # visualization + write-up style reference
├── CLAUDE.md                  # project guide: data dictionary, conventions, data wrinkles
├── ai_log.md                  # running record of AI use (raw material for the memo)
└── ai_memo.md                 # how AI tools were used, per the assignment
```

**Not in version control:** the provided `data/` files (git-ignored — supplied separately) and
internal working notes (planning, job-ad crosswalk, QA scratch).

## How to run

Requires R (developed on 4.2.3) and [Quarto](https://quarto.org). Packages:

```r
install.packages(c("here", "dplyr", "survey", "gt", "ggplot2", "ggpubr", "tibble"))
```

With the provided data in `data/`, from the repo root:

```bash
Rscript code/00_explore.R          # profile the four data files
Rscript code/01_task1_crosstabs.R  # Task 1 tables  -> output/task1/*.png
Rscript code/02_task2_density.R    # Task 2 metrics + curves -> output/task2/*.png
quarto render                      # build the website into docs/
```

Scripts and reports resolve paths with `here::here()`, so they run from any working directory.
The rendered site (`docs/`) is committed, so the write-ups are viewable without re-running R.

## Methods & assumptions

Key data characteristics and the decisions they forced — weight handling (complex-survey, not
frequency), the "all users in the database" denominator choice and the ~23% missing-ID rows in
Task 2, the "last 90 days" reference date, and duplicate/orphan rows — are documented in
`CLAUDE.md` and in each task's write-up.

## AI use

Generative AI was used throughout; `ai_memo.md` documents the models, tools, harnessing (custom
agents, a prompt-capture hook), representative prompts, accuracy checks, and corrections, per the
assignment.

## Contact

Submitted to careers@verasight.io.
