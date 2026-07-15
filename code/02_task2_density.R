# code/02_task2_density.R
# ---------------------------------------------------------------------------
# Task 2 — Response "density": how concentrated survey responses are among
# panelists. Answers three questions and saves two concentration-curve figures
# (all responders, and users registered in the last 90 days).
#   Run from the repo root:  Rscript code/02_task2_density.R
#
# KEY ASSUMPTIONS / EDGE CASES (see notes/qa.md):
#   * File: the brief says "response-db.rds"; the actual file is
#     data/full-response-db.rds. Used here.
#   * Universe ("users in the database"): users who APPEAR in the response DB,
#     i.e. have >= 1 response (responders). The all-registered alternative
#     (incl. 59k zero-response users) is reported for contrast in Task 2.1.
#   * NA user IDs: 23% of rows have a MISSING ID — unattributable to any user,
#     so they are DROPPED from per-user counts (they are not a single mega-user).
#   * Duplicates: 3,863 exact-duplicate rows (same ID/survey/response_date) are
#     de-duplicated (treated as one recorded response).
#   * "Last 90 days" (Task 2.2): relative to the latest date in the data
#     (max response_date), not today. Registration date = users$signup_date.
#   * Ties: users are ordered most-active-first; the cumulative curve is
#     monotonic, so the smallest user count reaching a target is well defined.
# ---------------------------------------------------------------------------

source(here::here("utils", "read_survey.R"))
source(here::here("utils", "density.R"))    # clean_responses, concentration_curve,
                                            # min_user_share_for, gini, density_figure
suppressWarnings(suppressMessages({
  library(dplyr)
  library(ggplot2)
}))

# Save a concentration-curve figure as a PNG (static; previews on GitHub and
# embeds cleanly in the report).
save_density_png <- function(fig, path) {
  ggsave(path, fig, width = 8, height = 5, dpi = 150, bg = "white")
}

# ---- load + clean -----------------------------------------------------------
raw <- read_survey(here::here("data", "full-response-db.rds"))

n_raw <- nrow(raw); n_na <- sum(is.na(raw$ID)); n_dupe <- sum(duplicated(raw))
db <- clean_responses(raw)                    # de-dupe + drop NA-ID rows
per_user <- db %>% count(ID, name = "responses")
n_users  <- nrow(per_user)

cat(sprintf("Raw rows: %d | NA-ID (dropped): %d (%.1f%%) | duplicates (dropped): %d\n",
            n_raw, n_na, 100 * n_na / n_raw, n_dupe))
cat(sprintf("Analysis rows: %d | distinct responders: %d\n\n", nrow(db), n_users))

# ===========================================================================
# Task 2.1 — smallest % of users accounting for 50% of responses
# ===========================================================================
share_50 <- min_user_share_for(per_user$responses, 0.50)
cat("=== Task 2.1 — concentration among responders ===\n")
cat(sprintf("Smallest %% of users for 50%% of responses: %.2f%% (%d of %d users)\n",
            100 * share_50, ceiling(share_50 * n_users), n_users))
cat(sprintf("Gini coefficient: %.3f\n", gini(per_user$responses)))

# Alternative universe: all registered users (zero-response users included).
users_all <- read_survey(here::here("data", "users.rds"), quiet = TRUE)
n_zero    <- n_distinct(users_all$ID) - n_users
counts_allreg <- c(per_user$responses, rep(0, max(n_zero, 0)))
cat(sprintf("(For contrast, all %d registered users incl. %d with zero responses: %.2f%%)\n\n",
            n_distinct(users_all$ID), n_zero, 100 * min_user_share_for(counts_allreg, 0.50)))

# ===========================================================================
# Task 2.2 — same metric, restricted to users registered in the last 90 days
# ===========================================================================
ref_date <- as.Date(max(raw$response_date, na.rm = TRUE))   # latest date in the data
cutoff   <- ref_date - 90
users_all$signup <- as.Date(users_all$signup_date, format = "%m/%d/%Y")
recent_ids <- users_all$ID[!is.na(users_all$signup) & users_all$signup >= cutoff]
per_recent <- db %>% filter(ID %in% recent_ids) %>% count(ID, name = "responses")

share_50_recent <- min_user_share_for(per_recent$responses, 0.50)
cat("=== Task 2.2 — restricted to registrations in the last 90 days ===\n")
cat(sprintf("Reference date: %s | 90-day cutoff: %s\n", ref_date, cutoff))
cat(sprintf("Recent registrants: %d | of whom responders: %d (%.0f%%)\n",
            length(recent_ids), nrow(per_recent),
            100 * nrow(per_recent) / length(recent_ids)))
cat(sprintf("Smallest %% of recent responders for 50%% of responses: %.2f%% (%d of %d)\n",
            100 * share_50_recent, ceiling(share_50_recent * nrow(per_recent)), nrow(per_recent)))
cat(sprintf("Gini coefficient: %.3f\n", gini(per_recent$responses)))

# Alternative universe: all recent registrants (incl. those who never responded).
n_recent_zero <- length(recent_ids) - nrow(per_recent)
cat(sprintf("(For contrast, all %d recent registrants incl. %d non-responders: %.2f%%)\n\n",
            length(recent_ids), n_recent_zero,
            100 * min_user_share_for(c(per_recent$responses, rep(0, max(n_recent_zero, 0))), 0.50)))

# ===========================================================================
# Task 2.3 — two concentration curves (10%-90% thresholds, 50% highlighted)
# ===========================================================================
out_dir <- here::here("output", "task2")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

fig_all    <- density_figure(per_user$responses,
                             "Response density — all responders")
fig_recent <- density_figure(per_recent$responses,
                             "Response density — registered in the last 90 days")

save_density_png(fig_all,    file.path(out_dir, "density_curve_all.png"))
save_density_png(fig_recent, file.path(out_dir, "density_curve_recent.png"))
cat(sprintf("Saved 2 concentration curves (PNG) to %s/\n\n", out_dir))

# ---- interpretation ---------------------------------------------------------
cat("=== Interpretation ===\n")
cat(sprintf("* Overall, the most active %.1f%% of responders account for half of all\n",
            100 * share_50))
cat("  responses (Gini ~0.54): heavy-tailed but not extreme (median 3/user, max 35).\n")
cat("* Biggest signal is DATA QUALITY: ~23% of rows have no user ID and were excluded\n")
cat("  (counting them as one 'user' would falsely imply 22% of responses = one account).\n")
cat(sprintf("* Recent registrants look less concentrated (%.1f%% for 50%%, Gini ~0.30), but\n",
            100 * share_50_recent))
cat("  that is largely mechanical: they've had little time to respond (median 1 each),\n")
cat("  which compresses the distribution — not a clear behavioral signal.\n")
