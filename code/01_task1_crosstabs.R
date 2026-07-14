# code/01_task1_crosstabs.R
# ---------------------------------------------------------------------------
# Task 1 — weighted proportion crosstabs for survey 2024-054.
# Produces one table per survey outcome (q28-q35) x demographic, with the
# question wording attached above each table, using complex-survey weights.
#
# Runs from anywhere (paths are anchored at the repo root via here::here()):
#   Rscript code/01_task1_crosstabs.R
#   Rscript code/01_task1_crosstabs.R <responses.rds> <reference.rds>   # other survey
# ---------------------------------------------------------------------------

if (!requireNamespace("here", quietly = TRUE)) {
  stop("Package 'here' is required to resolve paths. Install with install.packages('here').",
       call. = FALSE)
}

# ---- CONFIGURATION: point these at the survey to tabulate -------------------
# To run on a different survey, change these two lines OR pass them as CLI args
# (positional: responses first, reference second). Nothing else below changes.
.args <- commandArgs(trailingOnly = TRUE)
responses_file <- if (length(.args) >= 1) .args[[1]] else here::here("data", "2024-054_responses.rds")
reference_file <- if (length(.args) >= 2) .args[[2]] else here::here("data", "2024-054_reference.rds")
output_dir     <- here::here("output", "task1")

# ---- load helpers + libraries ----------------------------------------------
source(here::here("utils", "read_survey.R"))          # read_survey()
source(here::here("utils", "weighted_crosstab.R"))    # weighted_crosstab()

suppressWarnings(suppressMessages({
  library(survey)
  library(gt)
}))

# ---- load data --------------------------------------------------------------
responses <- read_survey(responses_file)
reference <- read_survey(reference_file)

# ---- build all outcome x demographic tables (roles inferred automatically) --
# Outcomes inferred as q##; demographics = categorical cols except respondent_id + weight.
tables <- weighted_crosstab(responses, reference = reference)

n_out <- length(unique(vapply(tables, `[[`, character(1), "outcome")))
n_dem <- length(unique(vapply(tables, `[[`, character(1), "demographic")))
cat(sprintf("Built %d tables (%d outcomes x %d demographics).\n",
            length(tables), n_out, n_dem))

# ---- show a representative table (mirrors the case-study example: q x age) ---
# Pick the q28-by-age table if present, else fall back to the first table so this
# demo never errors when run on a different survey.
example_key <- if ("q28__age_group4" %in% names(tables)) "q28__age_group4" else names(tables)[1]
example <- tables[[example_key]]
cat("\nExample table [", example_key, "]\n", sep = "")
cat("Question:", example$question, "\n\n")
print(as.data.frame(example$data))    # underlying weighted proportions (0-1)
# example$gt                          # rendered gt table (view in RStudio)

# ---- export all tables to HTML for review -----------------------------------
# Writes one styled table per outcome x demographic under output/task1/.
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
invisible(lapply(names(tables), function(k) {
  gt::gtsave(tables[[k]]$gt, file.path(output_dir, paste0(k, ".html")))
}))
cat(sprintf("\nSaved %d styled tables to %s/\n", length(tables), output_dir))
