# AI-use memo

This memo documents how I used generative AI to complete the case study.

My approach was to using AI was **supervisory and efficient**: I used AI to execute coding, planning, data-processing, and repetitive work (e.g.,implementation of Tasks 1–3, generate tables/figures, build the website, write documentation) so I could dedicate more time on the analytic and judgment-heavy parts — the Task 4 scoping and ranking, the design logic in Task 3, and the interpretation of results. I specifically chose not to use AI in a first pass in Task 4 so you can see my own thinking process. Wherever possible, I ran **multiple agents in parallel** (e.g., letting an adversarial tester stress-test Task 1 and 2 while I worked on Task 4), and I used AI heavily to **copy edit, streamline, and pressure-test what I had already written**. Nothing went in unreviewed — I read all output, verified the numbers independently, and edited for improvements.

### Working style — strategic and efficient use

A few comments on how I used AI to tie the whole approach together:

- **Division of labor.** I pushed the repetitive and mechanical work (implementing functions, generating 48 crosstab tables and the figures, wiring the website) to AI, and reserved my own time for the judgment calls — the Task 4 scoping and ranking, the Task 3 design, and every interpretation. On the judgment tasks I wrote first and used AI to *evaluate my reasoning*, so the logic on display is mine.
- **Parallelism for throughput.** Because agents run in the background, I could launch a stress test or an editorial review and keep working on a different task in the meantime — closer to running a small team than to a single chat.
- **AI in specialized roles.** Rather than one general assistant, I set up distinct agents for building, adversarially testing, editing, and committing — each with a narrow, well-defined job.
- **A verification-first loop.** For every non-trivial piece: plan → build → independently break/verify → fix → re-verify, with the numbers checked against a second method before I accepted anything.
- **Automating the documentation itself.** Tracking models, prompts, and corrections by hand as I worked would have been tedious and error-prone, and a drain on time better spent on the analysis. So I had the harness do it: the prompt-capture hook logged every prompt verbatim, a running `ai_log.md` recorded decisions and corrections in real time, and *this memo* was then drafted from that raw material for me to edit. Meeting the assignment's documentation requirement cost me almost none of my analytic time — I orchestrated it rather than transcribed it.
- **Fittingly, Task 3 asks me to *design* an AI-assisted workflow** — and the harnessing I built for this submission (tiered agents, a human always on the costly call, automatic logging) is a small live demonstration of the same instincts.

## 1. Which model(s) I used, and why

- **Claude Opus 4.8, via Claude Code**, for the coding, data processing, drafting, and harnessing. I chose it because it's the strongest available model for code and reasoning, and the 1M context let me keep the whole project in view at once (data dictionary, many source files, a long thread) instead of re-establishing state each time.
- The **Task 3 design** proposes a *different* model strategy for the system it describes — cheap **Claude Haiku** for first-pass triage, escalating uncertain cases to **Sonnet/Opus**. That's a design recommendation for a production pipeline, not what I used to build this submission.

## 2. How I communicated with the LLM

Not a browser chat window — I used **Claude Code**, an agentic CLI/IDE harness inside [Positron](https://positron.posit.co) (a VSCode fork developed by Posit for R and Python users), so the model could read/write files, run R (`Rscript`), render the Quarto site, and manage git directly while I reviewed and directed each step. That let me work at the level of *"here's the design — implement it, then stop for my verification"* rather than copy-pasting code back and forth. Because the panel data is already anonymized (respondent IDs are opaque tokens, not names or contact details), processing it locally through the model raised no confidentiality concern.

## 3. Harnessing around the LLM (agents, hooks, toolbox, site)

I used a few skills and agents to harness Claude's power and make the work steerable, checkable, and parallelizable:

- **A project `CLAUDE.md` for persistent context.** Before writing any analysis, I had the AI run a QA/profiling pass over all four data files and used it to build a verified **data dictionary** (columns, types, keys, join cardinality, weight distribution) and a list of **data wrinkles** to watch for (the ~23% missing-ID rows, the duplicate rows, the ambiguous "last 90 days" reference date, demographic NAs). I captured that — together with standing rules (use the `survey` package; portable base-R/tidyverse; house style) — in a `CLAUDE.md` steering file the model automatically reads on every prompt. So the AI started each task already knowing the data and my conventions, and I never had to re-establish that context.
- **Three specialized subagents**, so AI played distinct roles instead of one monolithic chat:
  - `adversarial-tester` — a read-only agent whose job is to *break* my code with synthetic known-answer tests and edge cases, not praise it.
  - `git` — prepares and stages commits to a consistent convention and stops for my approval.
  - `content-editor` — reviews my own Task 3/4 writing for typos, clarity, prompt-coverage, and gaps, while explicitly preserving my voice rather than rewriting into generic prose.
- **A `UserPromptSubmit` hook** (added via the update-config skill) that auto-captures every prompt I submit, verbatim, to `notes/prompt-capture.log` — model-independent, so it can't drift the way a model-maintained log does. It's the source for section 4.
- **A reusable `utils/` toolbox** (`read_survey()`, `weighted_crosstab()`, `density.R`), each roxygen-documented so it could drop into a Verasight analysis package rather than live as one-off scripts.
- **A Quarto website** to present the four write-ups, which I had the AI build quickly by modeling it on the structure of another repo I maintain — so the navigation, layout, and build config came together in minutes rather than from scratch.

## 4. Representative prompts

These are pulled **verbatim** from `notes/prompt-capture.log` (the hook's record of every prompt I submitted); the longer ones are excerpted where marked. They show my usual pattern — *specify the design and the verification plan up front, then hand implementation to the model* — across a few modes of use:

**(a) Directing a build, with the verification plan stated up front (Task 1):**
```
Task 1 of the Verasight case study. Before writing anything, read CLAUDE.md (data dictionary, conventions, known data wrinkles), notes/style.md (table styling), and utils/read_survey.R (use it to load data).

GOAL
Write a single, well-documented, reusable R function (plus small internal helpers if needed) named weighted_crosstab(), and store the FUNCTION DEFINITION in utils/weighted_crosstab.R (filename matches the function; part of the shared toolbox). Then EXECUTE it in code/01_task1_crosstabs.R, which sources the function (source("utils/weighted_crosstab.R")) and runs it on the recent survey to generate the tables. Keep definition (utils/) and execution (code/) separate.

The function produces weighted proportion tables — one for each survey outcome × demographic variable — matching the attached example, with each question's full wording shown just above its table.

SEMANTICS (match the example exactly)
- Rows = outcome response levels; columns = demographic categories.
- Cells = COLUMN proportions: within each demographic category, the response levels sum to 100%. Round to whole percentages. Preserve the outcome's factor-level order for rows (so e.g. a "Don't Know" level still appears even at 0%).

WEIGHTING
- These are complex-survey weights (verified: all non-integer, most < 1, sum ≈ n) — NOT frequency weights. Compute weighted proportions with the `survey` package. No strata/PSU were provided, so build the design as svydesign(ids = ~1, weights = ~<weight_col>, data = ...) and use svyby/svymean. Do not use unweighted counts.

QUESTION WORDING
- Attach each outcome's full question text as a title/subtitle above its table, looked up from the reference file (join variable name -> label). Take the reference as an argument.

REUSABILITY (this is the grading bar — a teammate must run it on a DIFFERENT Verasight survey without editing internals)
- Infer variable roles BY DEFAULT: outcomes = columns matching `^q[0-9]+$`; demographics = all remaining columns except the id and weight columns. Exclude `respondent_id` and `weight` from analysis — they aid analysis, they aren't outcomes.
- But EXPOSE OVERRIDE ARGUMENTS so nothing is hardcoded: outcomes, demographics, id_col = "respondent_id", weight_col = "weight", reference, and the outcome-detection pattern. Explicit args win over inference.

ROBUSTNESS
- Handle NA demographic categories and NA responses explicitly (document the choice — e.g. drop NA demographic groups but keep responses visible — rather than silently dropping).
- Fail with informative errors on: missing weight column, an outcome/demographic not in the data, an empty subgroup, or a non-factor outcome that can't be tabulated.

OUTPUT
- Style per notes/style.md: clean gt table — bold row labels, right-aligned %, subtle row shading, a vertical rule after the "Response" column. Also RETURN the tables as a named list (keyed by outcome × demographic) so they're programmatically accessible, not just printed.

DOCS & PORTABILITY
- roxygen-style header on the function: one-line purpose, @param for every argument, @return, a runnable @examples block. Comment any non-obvious logic.
- Keep deps to survey + tidyverse + gt. Don't over-engineer — one primary function.

code/01_task1_crosstabs.R should: source utils/read_survey.R and utils/weighted_crosstab.R, load data/2024-054_responses.rds and its reference, call weighted_crosstab(), and render the tables for the full set of outcome × demographic pairs (or a clear representative subset).

STOP after writing both files. I'll run them through the adversarial-tester agent and do an independent base-R weighted.mean() hand-check before we accept.
```

**(b) Framing the analysis and naming the assumptions myself (Task 2, full):**
```
Task 2: I have a survey response database in data/response-db.rds. Each row is a survey
response with a user ID and dates (inspect the structure first).

I need to analyze "response density" — how concentrated survey responses
are among panelists. Three tasks:

1. Find the smallest percent of users who account for 50% of all responses.
2. Same metric, restricted to users who registered in the last 90 days
   (use the latest date in the data as the reference point, and state that 
   assumption).
3. Visualize the full concentration curve: cumulative % of responses vs.
   cumulative % of users (most active first), with the 10%–90% thresholds
   marked. Save the output to output/task2/ as .html file since we'll pull this 
   into our write up later.

Use R with tidyverse. Write clean, commented code, report the numeric
answers, and briefly summarize the results — including any assumptions
or edge cases (ties, users with zero responses, etc.). Name the file you create code/02_task2_density.R
```

**(c) A short corrective steer, catching a data-handling problem (full):**
```
I'm confused on how this function is handling NAs or NaNs? Are they only on survey ids? They should be dropped and should not enter the analysis -- I don't want any silent failing here.  
```

**(d) Using AI to critique my *own* work rather than write it (Task 4):**
```
Use the content editor agent on task4.qmd while I work on task3.qmd
```

Here I'd written the Task 4 answers myself and used the content-editor agent to pressure-test them for gaps and consistency while I worked on Task 3 — AI reviewing my reasoning, not producing it.

## 5. How I checked and ensured accuracy

I treated verification as a first-class step. Several of these checks are agents reviewing AI-written code — which carries a correlated-error risk — so I leaned hardest on the checks that *don't* share it: independent code paths, known-answer tests, and my own hand-tracing. Specifically, I traced the density metric by hand on a small example, confirmed the synthetic cases were correct *tests* before trusting them, and spot-checked raw records against the computed figures.

- **Independent recomputation.** For Task 1 I recomputed a table cell three ways — the function, base-R `weighted.mean()`, and `survey::svymean()` on a separate design — and confirmed they matched to floating-point precision (shown live in the Task 1 write-up).
- **Adversarial testing with known answers.** The `adversarial-tester` agent checked the density metric against synthetic cases with known results (e.g., 1 of 10 users holding 50% of responses → 10%) and reproduced the headline numbers via a fully independent code path. These weren't rubber stamps — the synthetic cases surfaced a real bug (negative weights would silently produce negative percentages), which I fixed and re-ran to confirm.
- **A data-profiling pass before any analysis**, which caught several data-quality issues (detailed below).
- **Verifying the specification, not just the arithmetic.** I checked the analytic *choices* as much as the math — that "last 90 days" meant 90 days back from the latest date in the data (not today), how ties and zero-response users were handled in the concentration metric, and which user universe the denominator used — and stated each assumption explicitly, since a correct computation of the wrong quantity is still wrong.
- **Running and rendering everything** — every script executes and every report renders; I read the actual outputs rather than trusting that code "looks right."
- **AI as a critic of my own writing** — the `content-editor` agent for a final accuracy, consistency, and coverage pass over Tasks 3 and 4.

## 6. LLM output I corrected, disagreed with, or steered

Some representative examples of where I overrode or redirected the AI:

- **Task 1 — continuous `age` swept in as a demographic.** The literal inference rule I described in planning would have treated the continuous `age` column as a ~70-category demographic; I had it refined to categorical-only inference plus a guard that errors on continuous variables.
- **Task 1 — a robustness fix I directed.** After the tester surfaced the negative-weight bug (§5), I had a non-negativity guard added so the function errors on invalid weights instead of silently returning nonsense — the kind of edge case a teammate reusing it would eventually hit.
- **Task 2 — the "22% mega-user" that wasn't.** The model's first pass counted responses with a plain `count()`, which lumped **all 43,692 missing-ID rows into a single `NA` "user"** holding 22% of responses. I caught it in the profiling output and directed that unattributable rows be dropped — moving the headline answer from a misleading ~9.9% to the correct **15.67%**. 
- **Task 4 — a factual slip I wrote, caught on review.** The `content-editor` flagged that my ranking assumed the longitudinal waves spanned "6 months to a year," contradicting the prompt's "each a month apart"; I corrected it to ~3–4 months.
- **Disagreeing with the AI critic.** The tester also proposed changing a boundary check to `>=`; I declined it because it would have made the inference and guard logic inconsistent.
- **Tooling steers.** I steered the estimation engine to the `survey` package (not plain weighted means), and when a version mismatch broke `ggplotly()`, I had the package updated rather than accept the silent fallback.
- **This memo.** I'm editing the AI's draft of this document for accuracy and voice — itself an instance of not shipping AI output unchecked.
