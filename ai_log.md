# AI-use log

Running record of how AI was used on this case study. Raw material for `ai_memo.md`.
Two parts: (1) verbatim representative prompts (for the memo's prompt-examples section),
(2) an activity log. Activity entries use:
`- [task N] <one-line prompt summary> → <what was produced> | <accepted / corrected: how>`

---

## Representative prompts (verbatim)

### Task 1 — build `weighted_crosstab()`
Crafted collaboratively, then optimized (front-loaded repo context, pinned column-proportion
semantics + the `survey` engine, turned "infer roles" into infer-by-default + overrides,
split definition in `utils/` from execution in `code/`).

```
Task 1 of the Verasight case study. Before writing anything, read CLAUDE.md (data
dictionary, conventions, known data wrinkles), notes/style.md (table styling), and
utils/read_survey.R (use it to load data).

GOAL — write weighted_crosstab() in utils/weighted_crosstab.R (definition; filename matches
the function), and EXECUTE it in code/01_task1_crosstabs.R (sources the function, runs it on
the recent survey). Produces weighted proportion tables — one per survey outcome × demographic
— matching the target example, with each question's wording shown just above its table.

SEMANTICS: rows = response levels, columns = demographic categories; cells = COLUMN
proportions (each demographic column sums to 100%); whole-% rounding; preserve factor order.

WEIGHTING: complex-survey weights (verified: all non-integer, most < 1, sum ≈ n) — use the
survey package; svydesign(ids=~1, weights=~<weight_col>); svyby/svymean; never unweighted.

WORDING: attach each outcome's full question text (join variable->label from the reference
file, taken as an argument) above its table.

REUSABILITY (grading bar — teammate runs it on a DIFFERENT survey without editing internals):
infer roles by default (outcomes = `^q[0-9]+$`; demographics = the rest minus id/weight;
exclude respondent_id + weight), but expose overrides (outcomes, demographics, id_col,
weight_col, reference, pattern) — explicit wins over inference.

ROBUSTNESS: handle NA demographic groups + NA responses explicitly and document the choice;
informative errors on missing weight col / unknown var / empty subgroup / non-factor outcome.

OUTPUT: gt table styled per notes/style.md; ALSO return a named list of tables. roxygen docs
(@param/@return/@examples). Deps: survey + tidyverse + gt. One primary function; no overbuild.

STOP after both files — I'll run the adversarial-tester + an independent weighted.mean()
hand-check before accepting.
```

---

## Activity log

### Setup / Phase 0

- [setup] Read case-study PDF + planned AI strategy → high-level plan (`plan.md`), harnessing
  design, job-ad crosswalk (`jobad.md`) | accepted, iterated over several rounds; steered
  toward the `survey` package, sourced-file utils (not a package), and strict 3-hour optics.
- [setup] Profile all four `.rds` files for structure + planted wrinkles → QA summary |
  accepted; surfaced the Task 2 denominator ambiguity, 3,863 duplicate rows, 1 orphan ID,
  and the "last 90 days" reference-date issue.
- [setup] Fetch Verasight brand style → `style.md` palette | accepted with correction: page
  published no exact hex, so palette is a documented approximation of the navy/gray feel.
- [setup/harnessing] Used the Claude Code **update-config skill** to add a `UserPromptSubmit`
  hook (`.claude/settings.json`) that auto-appends every submitted prompt verbatim to
  `notes/prompt-capture.log` (gitignored) → reliable, model-independent capture of prompt
  examples for this memo (the CLAUDE.md manual logger had drifted). Command pipe-tested and
  schema-validated before install. Fires outside the turn, so verified by construction, not
  in-session.

### Task 1

- [task 1] Drafted the crosstab prompt with the user; verified via R that `weight` is a
  complex-survey weight (968/968 non-integer, 598 < 1, sum ≈ n) not a frequency weight →
  locked the `survey` package. Optimized the prompt (verbatim above). | prompt finalized.
- [task 1] Built `weighted_crosstab()` in utils/ + `code/01_task1_crosstabs.R` (survey pkg,
  svytable column proportions, gt styling, question-wording join, infer-by-default roles). |
  corrected: the prompt's literal inference rule ("all remaining cols except id/weight") would
  sweep in the continuous `age` column as a 70-level demographic. Refined inferred demographics
  to categorical (factor/character) columns only; explicit `demographics=` still overrides.
  Smoke-tested: 48 tables, age excluded, column proportions sum to 1.00. Pending
  adversarial-tester + independent weighted.mean() hand-check.
- [task 1] User feedback: script broke when run from inside `code/` (relative paths), and
  data filenames were buried in the logic. | corrected: anchored all paths with `here::here()`
  so it runs from any cwd; moved data files to a top CONFIG block with optional CLI override
  (no logic edits to retarget a survey). Kept the function's data-as-argument design intact.
- [task 1] User feedback: continuous vars should be *hard*-skipped, not skipped only as a
  side effect of the factor/character rule. | corrected: added `max_categories` (default 20) —
  inference skips continuous/high-cardinality cols with a transparency message; an explicitly
  passed continuous var (e.g. `age`, 70 levels) now errors informatively. Verified both.
- [task 1] Ran the **adversarial-tester** agent on both files (review + colleague-rename
  simulation + edge cases + independent weighted.mean cross-check). | Verdict PASS with issues.
  Confirmed: numbers match base-R to full precision; column proportions sum to 100%; empty
  levels retained; fully reusable on a renamed survey via arguments. Found + FIXED a real bug:
  negative weights silently produced negative percentages → added a non-negativity check.
  Declined the suggested `>=` boundary tweak on `max_categories` (would make inference and the
  guard inconsistent). Fix verified.
- [task 1] Wrote `reports/task1.qmd` — succinct write-up (what/how/verification) with an
  embedded synthetic-colleague demo (renamed cols: user_id/wt/item_*/region2/agegrp) proving
  the function runs on a different survey via arguments only. Rendered to self-contained HTML;
  gt tables render (benign Quarto "raw html table" warnings). | accepted.
- [task 1] Refined the report per user feedback: added the assignment text as a blockquote;
  reduced visual noise (litera theme, github highlight, collapsible code) since it had "a lot
  of different colors"; added a VISIBLE manual-validation section recomputing one cell three
  ways (function vs base-R weighted.mean vs survey::svymean, all equal to 1e-9) which also
  answers "is svy called?" — yes, survey::svydesign + svytable at weighted_crosstab.R:213-214.
  Explained roxygen's purpose (job-ad "well-documented/package-dev" signal; renders to a help
  page only inside a package, which we skipped by design). | accepted.

### Task 2

- [task 2] Built `code/02_task2_density.R` (Lorenz-style concentration metric + interactive
  HTML curve). Numbers verified against an independent scratch computation. | accepted with
  key corrections/decisions:
  - **Major data-quality find:** 23.3% of rows (43,692) have a **missing user ID**. `count(ID)`
    lumped them into one NA "user" with 40,464 responses = a spurious 22%-of-all-responses
    "mega-account." Excluded NA-ID rows as unattributable (can't assign to a panelist). This
    single fix moved the 2.1 answer from ~9.9% to 15.67%.
  - Filename: brief said `response-db.rds`; actual is `data/full-response-db.rds`.
  - De-duplicated 3,863 exact-duplicate rows; stated the responders vs. all-registered
    denominator choice (reported both). "Last 90 days" = relative to max response_date
    (2024-09-09), stated.
  - Results: 2.1 = 15.67% (Gini 0.54); 2.2 = 28.31% among recent registrants (Gini 0.30);
    all-registered universe = 4.82%.
  - Viz: `ggplotly()` failed on an installed plotly/ggplot2 version mismatch
    (`scales_transform_df`); rebuilt the figure in **native `plot_ly`** instead. Added cleanup
    of the leftover `_files` libdir so the HTML stays a clean single self-contained file.
- [task 2] User edits after review: (1) committed checkpoint first; (2) **updated plotly
  4.10.1 → 4.12.0** so `ggplotly()` works, then switched back to ggplot2+ggplotly to stay in
  the tidyverse (user preference); (3) refactored the metric + figure code into a reusable
  `utils/density.R` (clean_responses, concentration_curve, min_user_share_for, gini,
  density_figure); (4) built **two** figures (all responders + last-90-day registrants) with
  axes stepping by 10 and the **50% threshold highlighted** (red marker + guide lines);
  (5) wrote `reports/task2.qmd` explainer (assignment quote, answers table, both figures
  inline, assumptions). Rendered + verified: tickvals 0..100 by 10, highlight present, both
  answers (15.7% / 28.3%). | accepted.
- [task 2] Ran the **adversarial-tester** on utils/density.R + code/02. Verdict PASS, no
  material defects. Confirmed: synthetic known-answers (1-of-10 holds 50% → 10%; one-holds-all
  → 1/N; even → 50%); headline numbers reproduce exactly via an independent code path
  (15.6697%, 28.3070%); Gini sane; NA-drop/dedupe/ties/90-day-relative logic all correct;
  figures have step-10 axes, a distinct red 50% highlight, and are self-contained. Only
  non-triggered nits: empty/all-zero input → silent NA/NaN and NA-in-vector silently dropped
  by sort() (not reachable from the count()-based pipeline).
- [task 2] User follow-ups: (1) clarified NA handling — confirmed the only relevant NAs are on
  survey IDs (43,692), dropped up front by clean_responses (cleaned data is fully NA-free); on
  the user's preference for no silent behavior, added a `.check_counts` guard so the density
  helpers error loudly on empty/NA/negative/zero-sum input. (2) Fixed report captions — chunk
  labels `fig-*` made Quarto expect a caption; missing `fig-cap` rendered `?(caption)`. Added
  proper fig-cap to both figures. (3) Rewrote the "universe/denominator" paragraph for clarity
  and made the 90-day cohort statement explicit (on/after cutoff through the reference date).

### Task 3

- [task 3] Drafted `reports/task3.qmd` — a design memo for a fraud-detection workflow on
  open-ended responses (per user's detailed spec): 3-tier funnel (cheap deterministic signals →
  LLM classifier on flagged subset → human adjudication + audit of both classes), R/Python tool
  table per signal, mermaid architecture diagram, "why tier vs LLM-everything", closed-ended +
  paradata corroboration, validation (labeled data, cost-asymmetric precision/recall, seeded
  fraud for recall, calibration), iteration loop (active learning, drift, shadow-testing), risks
  (AI-detection unreliable), and an appendix sample LLM prompt + JSON schema. Claude model
  tiering (Haiku triage → Sonnet/Opus escalation). | accepted (user-directed design; AI drafted
  prose + the sample rubric artifact).
- [setup/harnessing] Built a `content-editor` subagent (`.claude/agents/content-editor.md`,
  read-only) to review the user's OWN Task 3 & 4 writing on four axes — typos/grammar, clarity
  (minimal edits **in the author's voice**, no genericizing), prompt-consistency (did they
  answer each ask?), and comprehensiveness (gaps vs. the PDF prompt). Reports suggestions; never
  edits files. | accepted.

### Task 4

- [task 4] Ran the **content-editor** agent on the user's OWN `reports/task4.qmd` answers. It
  preserved voice and caught a factual slip (P4 "6 months to a year" vs. the prompt's monthly
  waves), an empty assumptions callout, and typo clusters. | Per user direction: fixed all
  typos; corrected the P4 timeline to ~3-4 months; removed the empty assumptions callout
  (assumptions already live in the ranking cells) and the scaffold banner; added short mentions
  **in the user's voice** per project (questionnaire length P1; voter-contact mode P2 + a
  ranking caveat; developer sourcing P3; sample source P4). Re-rendered. AI = editor under
  direction, not author; user's judgment/voice preserved.
- [task 2] interactive plotly figures 404'd on ../site_libs/htmlwidgets.js. Root cause: this is
  a `type: website` Quarto project, and (a) rendering the single file (`quarto render
  reports/task2.qmd`) writes broken ../site_libs/ widget links without creating the folder, while
  (b) the global `embed-resources: true` conflicts with website widget handling. Fix: removed
  `embed-resources` from _quarto.yml (added an explanatory comment) and rebuilt with a FULL
  `quarto render`, which inlines the plotly/htmlwidgets deps into the page. Verified: task2.html
  self-contained (inline lib + hover text, zero external refs); all 5 pages' local assets resolve.
  Workflow rule: always `quarto render` (whole project), never single-file, for widget pages.
