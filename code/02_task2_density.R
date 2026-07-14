# code/02_task2_density.R
# ---------------------------------------------------------------------------
# Task 2 — Response "density": how concentrated survey responses are among
# panelists. Answers three questions and saves a concentration-curve figure.
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

suppressWarnings(suppressMessages({
  library(dplyr)
  library(plotly)
  library(htmlwidgets)
}))

# ---- reusable density helpers ----------------------------------------------

#' Concentration (Lorenz-style) curve from per-user response counts.
#' Users are ordered most-active-first, so the curve rises as fast as possible.
#' @return tibble with cumulative share of users and of responses (both 0-1).
concentration_curve <- function(counts) {
  counts <- sort(counts, decreasing = TRUE)
  n <- length(counts)
  tibble(
    cum_users     = seq_len(n) / n,
    cum_responses = cumsum(as.numeric(counts)) / sum(counts)
  )
}

#' Smallest share of users (most active first) whose responses reach `target`
#' of all responses. This is the headline "density" metric.
min_user_share_for <- function(counts, target = 0.5) {
  cc <- concentration_curve(counts)
  cc$cum_users[which(cc$cum_responses >= target)[1]]
}

#' Gini coefficient of a non-negative vector (0 = perfectly even, 1 = all in one).
gini <- function(x) {
  x <- sort(as.numeric(x)); n <- length(x)
  2 * sum(seq_len(n) * x) / (n * sum(x)) - (n + 1) / n
}

# ---- load + clean -----------------------------------------------------------
raw <- read_survey(here::here("data", "full-response-db.rds"))

n_raw  <- nrow(raw)
n_na   <- sum(is.na(raw$ID))
n_dupe <- sum(duplicated(raw))

# De-duplicate exact rows, then drop unattributable (NA-ID) responses.
db <- raw %>% distinct() %>% filter(!is.na(ID))

cat(sprintf("Raw rows: %d | NA-ID (dropped): %d (%.1f%%) | exact duplicates (dropped): %d\n",
            n_raw, n_na, 100 * n_na / n_raw, n_dupe))
cat(sprintf("Analysis rows: %d | distinct responders: %d\n\n",
            nrow(db), n_distinct(db$ID)))

# Responses per user (the raw material for every metric below).
per_user <- db %>% count(ID, name = "responses")

# ===========================================================================
# Task 2.1 — smallest % of users accounting for 50% of responses
# ===========================================================================
share_50 <- min_user_share_for(per_user$responses, 0.50)
n_users  <- nrow(per_user)

cat("=== Task 2.1 — concentration among responders ===\n")
cat(sprintf("Smallest %% of users for 50%% of responses: %.2f%% (%d of %d users)\n",
            100 * share_50, ceiling(share_50 * n_users), n_users))
cat(sprintf("Gini coefficient: %.3f\n", gini(per_user$responses)))

# Alternative universe: ALL registered users (zero-response users included).
users_all   <- read_survey(here::here("data", "users.rds"), quiet = TRUE)
n_zero      <- n_distinct(users_all$ID) - n_users
counts_allreg <- c(per_user$responses, rep(0, max(n_zero, 0)))
cat(sprintf("(For contrast, counting all %d registered users incl. %d with zero responses: %.2f%%)\n\n",
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
cat(sprintf("Recent registrants: %d | of whom responders: %d\n",
            length(recent_ids), nrow(per_recent)))
cat(sprintf("Smallest %% of recent responders for 50%% of their responses: %.2f%% (%d of %d)\n",
            100 * share_50_recent, ceiling(share_50_recent * nrow(per_recent)), nrow(per_recent)))
cat(sprintf("Gini coefficient: %.3f\n\n", gini(per_recent$responses)))

# ===========================================================================
# Task 2.3 — concentration curve with 10%-90% thresholds, saved as HTML
# ===========================================================================
curve <- concentration_curve(per_user$responses)

# Threshold markers: min % of users for each 10%..90% of responses.
thresholds <- seq(0.10, 0.90, 0.10)
marks <- tibble(
  target    = thresholds,
  user_pct  = vapply(thresholds, function(t) 100 * min_user_share_for(per_user$responses, t), numeric(1)),
  resp_pct  = 100 * thresholds
) %>%
  mutate(hover = sprintf("%.0f%% of responses come from the top %.1f%% of users",
                         resp_pct, user_pct))

# Downsample the 26k-point line for a light, smooth figure (metrics use full data).
idx <- unique(round(seq(1, nrow(curve), length.out = 2000)))
curve_plot <- curve[idx, ] %>%
  mutate(hover = sprintf("top %.1f%% of users -> %.1f%% of responses",
                         100 * cum_users, 100 * cum_responses))

navy <- "#1F2A44"; accent <- "#2E6E8E"; gray <- "#B7BEC7"
curve_plot$x <- curve_plot$cum_users * 100
curve_plot$y <- curve_plot$cum_responses * 100

# Built directly in plotly (native) for a self-contained, interactive HTML figure.
widget <- plot_ly() %>%
  add_segments(x = 0, xend = 100, y = 0, yend = 100,                 # line of perfect equality
               line = list(color = gray, dash = "dash"),
               hoverinfo = "skip", showlegend = FALSE) %>%
  add_lines(data = curve_plot, x = ~x, y = ~y,                       # the concentration curve
            line = list(color = navy, width = 2),
            text = ~hover, hoverinfo = "text", showlegend = FALSE) %>%
  add_markers(data = marks, x = ~user_pct, y = ~resp_pct,            # 10%-90% threshold markers
              marker = list(color = accent, size = 8),
              text = ~hover, hoverinfo = "text", showlegend = FALSE) %>%
  layout(
    title = list(text = "Response density: a minority of panelists drives most responses",
                 font = list(color = navy, size = 15), x = 0),
    xaxis = list(title = "Cumulative % of users (most active first)", range = c(0, 100), zeroline = FALSE),
    yaxis = list(title = "Cumulative % of responses", range = c(0, 100), zeroline = FALSE),
    plot_bgcolor = "white", paper_bgcolor = "white",
    font = list(family = "Helvetica, Arial, sans-serif", color = navy),
    hovermode = "closest"
  )

out_dir <- here::here("output", "task2")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
saveWidget(widget, file.path(out_dir, "density_curve.html"),
           selfcontained = TRUE, title = "Task 2 - Response density curve")
unlink(file.path(out_dir, "density_curve_files"), recursive = TRUE)   # drop leftover libdir
cat(sprintf("Saved concentration curve to %s/density_curve.html\n\n", out_dir))

# ---- interpretation ---------------------------------------------------------
cat("=== Interpretation ===\n")
cat(sprintf(
"* Responses are moderately concentrated: the most active %.1f%% of responders\n",
  100 * share_50))
cat("  account for half of all responses (Gini ~0.54) - a heavy-tailed but not\n")
cat("  extreme distribution (median 3 responses/user; max 35).\n")
cat("* The single biggest concentration signal is a DATA-QUALITY one: ~23% of\n")
cat("  rows have no user ID and cannot be attributed to a panelist; they were\n")
cat("  excluded (counting them as one 'user' would spuriously imply 22% of all\n")
cat("  responses come from a single account).\n")
cat(sprintf(
"* New panelists are much LESS concentrated: among users registered in the last\n  90 days, it takes %.1f%% of them to reach 50%% (Gini ~0.30) - concentration\n  builds with tenure as heavy responders accumulate history.\n",
  100 * share_50_recent))
cat("* Universe choice matters: on all registered users (incl. zero-response),\n")
cat("  the same 50% is reached by an even smaller share - state the denominator.\n")
