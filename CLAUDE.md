# Verasight Data Scientist Case Study — project guide

Working repo for a survey-data take-home. Deliverables in R, ≤3 hours total. See the
(git-ignored) `notes/plan.md` for the phase plan and `notes/jobad.md` for the skills to
showcase. Data lives in `data/`; analysis scripts in `code/`; shared helpers in `utils/`.

## Standing rules

- **Weights matter.** These are complex-survey weights, not frequency weights. Use the
  **`survey` package** (`svydesign` → `svyby`/`svymean`) as the estimation engine for Task 1.
  Use base-R `weighted.mean()` only as an *independent* verification path.
- **Portable & reusable.** Prefer base-R/tidyverse + `survey`; minimize exotic deps. Column
  names, weight var, and question metadata are **arguments**, never hardcoded — a teammate
  must be able to run a function on a different survey without editing internals.
- **Shared helpers** live in `utils/` as plain sourced `.R` files (e.g.
  `source("utils/read_survey.R")`), each with a roxygen-style comment header. Keep it to one
  or two genuinely reusable helpers — not a package.
- **Visual style:** follow `notes/style.md` for every table and plot (navy/gray, minimal,
  sans-serif). Load the `dataviz` skill before writing chart code.
- **Comment code appropriately** (the prompt asks for it) and document assumptions.
- **⏱ Optics:** keep total effort looking ≤3 hours. Don't gold-plate.

## AI-use logger (maintain as you work)

After any exchange where the user accepts, rejects, or modifies code you produced, append one
entry to `ai_log.md`:
`- [task N] <one-line prompt summary> → <what was produced> | <accepted / corrected: how>`
This is the raw material for `ai_memo.md`. Git history + transcript are backstops.

## Data dictionary (verified via profiling pass)

**`2024-054_responses.rds`** — Task 1. Tibble 968×17. One row per respondent.
- `respondent_id` (1 NA), `weight` (num; mean≈1.0, sum≈969≈n, range 0.60–2.87 — normalized).
- Demographics: `age_group4` (18-29/30-49/50-64/65+, 8 NA), `age` (num, 4 NA),
  `education` (3 levels), `raceeth` (White/Black/Hispanic/Other), `gender`
  (Male/Female/Other), `pid_base` (Dem/Rep/Ind/Other or none), `region` (4 Census, 12 NA).
- Outcomes: `q28`–`q35` (ordered categorical, e.g. q28 = accuracy 5-pt scale). No dup IDs.

**`2024-054_reference.rds`** — question wording. Tibble with `variable` (q28..q35) + `label`
(full question text). Join on variable name to attach wording to Task 1 tables.

**`full-response-db.rds`** — Task 2. Tibble 187,803×3. `ID` (user, chr), `survey` (chr, 60
surveys), `response_date` (POSIXct, 2023-12-21 → 2024-09-09).

**`users.rds`** — Task 2. Tibble 85,744×4. `ID` (chr, unique), `utm_source` (chr, many NA),
`vf_match` (logical; 54,137 TRUE / 31,607 FALSE), `signup_date` (chr "M/D/YYYY" — must parse).

## Known data wrinkles (state assumptions explicitly in methods.md)

1. **"All users in the database" is ambiguous (Task 2.1).** `full-response-db` has 26,364
   distinct users; `users.rds` has 85,744, of whom **59,381 have zero responses**. Denominator
   choice (responders-only vs. all registered) changes the density answer dramatically. State
   which universe and why.
2. **3,863 duplicate rows in `full-response-db`** (identical ID/survey/response_date). Decide
   dedupe vs. keep and justify — it affects the density counts.
3. **1 orphan response** — 1 db ID not present in `users.rds`.
4. **"Last 90 days" (Task 2.2)** is relative to the data, not today (2026): max
   `response_date` = 2024-09-09, so 90-day cohort ≈ registered after ~2024-06-11. State it.
5. **Demographic NAs in Task 1** (age_group4, age, region) — function must handle NA
   categories gracefully (`useNA` / explicit level).
