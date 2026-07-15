# code/00_explore.R
# ---------------------------------------------------------------------------
# Interactive exploration of the four Verasight case-study data files.
# Purpose: read everything in and look around before starting the tasks.
# Run from the repo root:  Rscript code/00_explore.R   (or step through in RStudio)
# ---------------------------------------------------------------------------

# Shared loader from the toolbox (documented wrapper around readRDS()).
source("utils/read_survey.R")

suppressWarnings(suppressMessages({
  library(dplyr)
}))

data_dir <- "data"
p <- function(...) cat(..., "\n")

# ---------------------------------------------------------------------------
# 1. Load all four files
# ---------------------------------------------------------------------------
responses <- read_survey(file.path(data_dir, "2024-054_responses.rds"))
reference <- read_survey(file.path(data_dir, "2024-054_reference.rds"))
resp_db   <- read_survey(file.path(data_dir, "full-response-db.rds"))
users     <- read_survey(file.path(data_dir, "users.rds"))

# ---------------------------------------------------------------------------
# 2. Task 1 — recent survey responses (2024-054)
# ---------------------------------------------------------------------------
p("\n=========================== TASK 1: responses ===========================")
glimpse(responses)
print(reference)

p("\n-- question wording (reference) --")
print(as.data.frame(reference), right = FALSE)

p("\n-- survey weight distribution --")
print(summary(responses$weight))
p("sum(weight) =", round(sum(responses$weight), 1), " | n =", nrow(responses))

p("\n-- demographic frequencies --")
demo_vars <- c("age_group4", "education", "raceeth", "gender", "pid_base", "region")
for (v in demo_vars) {
  cat("\n", v, ":\n", sep = "")
  print(table(responses[[v]], useNA = "ifany"))
}

p("\n-- outcome variables q28-q35 (first two shown) --")
for (v in c("q28", "q29")) {
  cat("\n", v, ":\n", sep = "")
  print(table(responses[[v]], useNA = "ifany"))
}

p("\n-- missingness by column --")
print(colSums(is.na(responses)))

# ---------------------------------------------------------------------------
# 3. Task 2 — aggregate response DB + users
# ---------------------------------------------------------------------------
p("\n=========================== TASK 2: response DB =========================")
glimpse(resp_db)
p("\ndate range:", format(min(resp_db$response_date)), "->", format(max(resp_db$response_date)))
p("distinct users in DB:", n_distinct(resp_db$ID), "| surveys:", n_distinct(resp_db$survey))
p("duplicate rows in DB:", sum(duplicated(resp_db)))
resp_db |> 
  #distinct(ID, survey) |> 
  distinct(ID) |> 
  print(n=100)

resp_db |> 
  arrange(ID) |> 
  print(n=10)

resp_db |> 
  arrange(survey) |> 
  print(n=10)


p("\n-- responses-per-user distribution (the 'density' raw material) --")
per_user <- resp_db %>% count(ID, name = "n_responses")
print(summary(per_user$n_responses))

p("\n=========================== TASK 2: users ==============================")
glimpse(users)
p("distinct user IDs:", n_distinct(users$ID))
p("vf_match TRUE/FALSE:")
print(table(users$vf_match, useNA = "ifany"))

# ---------------------------------------------------------------------------
# 4. Join cardinality — the denominator question for Task 2
# ---------------------------------------------------------------------------
p("\n=========================== JOIN CHECK ================================")
db_ids <- unique(resp_db$ID)
u_ids  <- unique(users$ID)
p("users who appear in response DB (>=1 response):", length(db_ids))
p("registered users total:                        ", length(u_ids))
p("registered users with ZERO responses:          ", sum(!u_ids %in% db_ids))
p("DB IDs not found in users file (orphans):       ", sum(!db_ids %in% u_ids))
p("\n>> Note: 'all users in the database' is ambiguous — responders-only vs. all registered.")
p(">> See notes/qa.md for the assumptions to state in methods.md.")

p("\nDone. Objects available: responses, reference, resp_db, users, per_user.")
