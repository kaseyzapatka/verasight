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
  library(ggplot2)
  library(ggpubr)
}))

# Render one crosstab (its proportions tibble) as a PNG image, no browser needed.
# (A gt -> PNG export would require a headless browser via webshot2; ggpubr renders
# the table through the grid graphics device, so ggsave() writes a PNG directly.)
save_table_png <- function(tbl, path) {
  df <- tbl$data
  num_cols <- setdiff(names(df), "Response")
  df[num_cols] <- lapply(df[num_cols], function(x) paste0(round(100 * x), "%"))   # 0-1 -> "NN%"
  title <- paste(strwrap(tbl$question, width = 70), collapse = "\n")
  n_title <- length(strsplit(title, "\n", fixed = TRUE)[[1]])
  g <- ggtexttable(df, rows = NULL, theme = ttheme("light", base_size = 10))
  g <- annotate_figure(g, top = text_grob(title, face = "bold", size = 11, color = "#1F2A44"))
  ggsave(path, g, width = 2 + 1.25 * length(num_cols),
         height = 1 + 0.32 * nrow(df) + 0.3 * n_title, dpi = 150, bg = "white", limitsize = FALSE)
}

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

# ---- export all tables as PNG for review / GitHub browsing ------------------
# One PNG per outcome x demographic under output/task1/ (previews inline on GitHub).
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
invisible(lapply(names(tables), function(k) {
  save_table_png(tables[[k]], file.path(output_dir, paste0(k, ".png")))
}))
cat(sprintf("\nSaved %d table PNGs to %s/\n", length(tables), output_dir))
