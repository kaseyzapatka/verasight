# utils/weighted_crosstab.R
# Shared helper for the Verasight data-science toolbox.
# Source with: source("utils/weighted_crosstab.R")
#
# Dependencies: survey (weighted estimation), gt (display), tibble/tidyselect (data frames).
# Namespaces are checked at call time rather than on load.

#' Weighted proportion crosstabs for survey outcomes by demographics
#'
#' For every survey question x demographic pair, this builds a table of weighted proportions
#' where each demographic column sums to 100% down the response options. It uses
#' complex-survey weights via the \code{survey} package and attaches each question's wording
#' as the table title.
#'
#' Column roles can be inferred (which columns are questions, which are demographics) or passed
#' explicitly. Running it on a new dataset means changing arguments, not editing the function.
#'
#' @param data A data frame / tibble of survey responses (one row per respondent).
#' @param outcomes Character vector of outcome (question) columns. If \code{NULL} (default),
#'   inferred as columns whose names match \code{outcome_pattern}.
#' @param demographics Character vector of demographic columns. If \code{NULL} (default),
#'   inferred as the categorical (factor/character) columns among those that are not outcomes,
#'   \code{id_col}, or \code{weight_col}; continuous numerics such as a raw \code{age} column
#'   are skipped. Pass explicitly to override.
#' @param weight_col Name of the survey-weight column. Default \code{"weight"}.
#' @param id_col Name of the respondent-id column to exclude from analysis. Default
#'   \code{"respondent_id"}.
#' @param reference Optional data frame mapping question variables to wording. If supplied,
#'   the label for each outcome is shown as its table title.
#' @param ref_var,ref_label Column names in \code{reference} holding the variable name and the
#'   question wording. Defaults \code{"variable"} / \code{"label"}.
#' @param outcome_pattern Regex used to infer outcome columns when \code{outcomes} is
#'   \code{NULL}. Default \code{"^q[0-9]+$"}.
#' @param max_categories Maximum distinct values a demographic may have. Columns exceeding it
#'   are treated as continuous/high-cardinality: skipped during inference, and an error if
#'   passed explicitly (rather than producing a huge table). Default \code{20}.
#' @param na_demographic How to treat respondents with a missing demographic value:
#'   \code{"drop"} (default) removes them from that table; \code{"keep"} shows them as an
#'   explicit \code{"(Missing)"} column.
#' @param digits Decimal places for the displayed percentages. Default \code{0} (whole \%).
#'
#' @details
#' Weighting uses \code{svydesign(ids = ~1, weights = ~<weight_col>)}, appropriate when only a
#' final weight is supplied (no strata/PSU columns are present in these data). Weighted counts
#' come from \code{svytable()} and are normalized within each demographic column. Missing
#' outcome responses are excluded so percentages are taken among those who answered; every
#' defined response level is retained (a level with no responses still shows at 0%). Because
#' each column is rounded independently, a column may sum to 99–101%.
#'
#' @return A named list keyed \code{"<outcome>__<demographic>"}. Each element is a list with
#'   \code{outcome}, \code{demographic}, \code{question} (wording or variable name),
#'   \code{data} (a tibble of proportions in 0–1; rows = response levels, columns =
#'   demographic categories), and \code{gt} (a formatted \code{gt} table for display).
#'
#' @examples
#' \dontrun{
#' source("utils/read_survey.R")
#' resp <- read_survey("data/2024-054_responses.rds")
#' ref  <- read_survey("data/2024-054_reference.rds")
#' tables <- weighted_crosstab(resp, reference = ref)
#' tables[["q28__age_group4"]]$gt     # display one table
#' tables[["q28__age_group4"]]$data   # underlying proportions (0-1)
#' # Works on a different survey by overriding roles, no internals edited:
#' weighted_crosstab(other, outcomes = c("v1", "v2"), demographics = "region",
#'                   weight_col = "wt", id_col = "id")
#' }
weighted_crosstab <- function(data,
                              outcomes = NULL,
                              demographics = NULL,
                              weight_col = "weight",
                              id_col = "respondent_id",
                              reference = NULL,
                              ref_var = "variable",
                              ref_label = "label",
                              outcome_pattern = "^q[0-9]+$",
                              max_categories = 20L,
                              na_demographic = c("drop", "keep"),
                              digits = 0) {

  if (!requireNamespace("survey", quietly = TRUE)) stop("Package 'survey' is required.", call. = FALSE)
  if (!requireNamespace("gt", quietly = TRUE))     stop("Package 'gt' is required.", call. = FALSE)

  na_demographic <- match.arg(na_demographic)
  data <- as.data.frame(data)  # stable [[ ]] extraction regardless of tibble/data.frame

  ## ---- validate weight ----
  if (!weight_col %in% names(data)) {
    stop("Weight column '", weight_col, "' not found in data.", call. = FALSE)
  }
  if (!is.numeric(data[[weight_col]])) {
    stop("Weight column '", weight_col, "' must be numeric.", call. = FALSE)
  }
  if (any(data[[weight_col]] < 0, na.rm = TRUE)) {
    stop("Weight column '", weight_col, "' contains negative values; survey weights must be ",
         ">= 0.", call. = FALSE)
  }

  ## ---- infer variable roles (explicit args always win) ----
  if (is.null(outcomes)) {
    outcomes <- grep(outcome_pattern, names(data), value = TRUE)
  }
  if (is.null(demographics)) {
    candidates <- setdiff(names(data), c(outcomes, id_col, weight_col))
    # A column is a usable demographic only if it is categorical (factor/character) and
    # low-cardinality (<= max_categories distinct values). This skips continuous variables
    # (e.g. a raw `age` column) and high-cardinality columns (free text, IDs), which would
    # otherwise expand into dozens of columns. Override via `demographics`.
    usable <- vapply(candidates, function(v) {
      x <- data[[v]]
      (is.factor(x) || is.character(x)) &&
        length(unique(x[!is.na(x)])) <= max_categories
    }, logical(1))
    demographics <- candidates[usable]
    skipped <- candidates[!usable]
    if (length(skipped) > 0) {
      message("weighted_crosstab(): skipped continuous/high-cardinality column(s) as ",
              "demographics: ", paste(skipped, collapse = ", "),
              " (not categorical or > max_categories = ", max_categories, ").")
    }
  }
  if (length(outcomes) == 0) {
    stop("No outcome columns found (check `outcomes` / `outcome_pattern`).", call. = FALSE)
  }
  if (length(demographics) == 0) {
    stop("No demographic columns found (check `demographics`).", call. = FALSE)
  }
  missing_cols <- setdiff(c(outcomes, demographics), names(data))
  if (length(missing_cols) > 0) {
    stop("Column(s) not found in data: ", paste(missing_cols, collapse = ", "), call. = FALSE)
  }

  ## ---- build every outcome x demographic table ----
  out <- list()
  for (oc in outcomes) {
    question <- .wc_wording(oc, reference, ref_var, ref_label)
    for (dm in demographics) {
      key   <- paste(oc, dm, sep = "__")
      props <- .wc_one(data, oc, dm, weight_col, na_demographic, max_categories)
      out[[key]] <- list(
        outcome     = oc,
        demographic = dm,
        question    = question,
        data        = props,
        gt          = .wc_gt(props, question, dm, digits)
      )
    }
  }
  out
}

# ---- internal helpers -------------------------------------------------------

#' Look up a question's wording from the reference table (falls back to the variable name).
#' @noRd
.wc_wording <- function(outcome, reference, ref_var, ref_label) {
  if (is.null(reference)) return(outcome)
  reference <- as.data.frame(reference)
  if (!all(c(ref_var, ref_label) %in% names(reference))) return(outcome)
  hit <- reference[[ref_label]][reference[[ref_var]] == outcome]
  if (length(hit) == 0 || is.na(hit[1])) return(outcome)
  as.character(hit[1])
}

#' Compute one weighted column-proportion table (rows = response levels, cols = categories).
#' Returns a tibble of proportions in 0-1. See weighted_crosstab() @details for NA rules.
#' @noRd
.wc_one <- function(data, outcome, demographic, weight_col, na_demographic, max_categories = 20L) {
  d <- data[, c(outcome, demographic, weight_col)]
  names(d) <- c(".out", ".grp", ".w")

  # Outcome must be tabulable: accept factor/ordered, coerce character, else error.
  if (is.character(d$.out)) d$.out <- factor(d$.out)
  if (!is.factor(d$.out)) {
    stop("Outcome '", outcome, "' is type ", class(d$.out)[1],
         "; it must be a factor (or character) to tabulate.", call. = FALSE)
  }

  # Hard guard against a continuous / high-cardinality demographic (e.g. raw `age`), which
  # would explode into dozens of columns. Fires even when the column is passed explicitly.
  n_cat <- length(unique(d$.grp[!is.na(d$.grp)]))
  if (n_cat > max_categories) {
    stop("Demographic '", demographic, "' has ", n_cat, " distinct values (> max_categories = ",
         max_categories, "); it looks continuous/high-cardinality. Bin it first (e.g. an ",
         "age group) or raise `max_categories`.", call. = FALSE)
  }
  if (!is.factor(d$.grp)) d$.grp <- factor(d$.grp)

  # Drop rows with missing weight or missing outcome (percentages among those who answered).
  d <- d[!is.na(d$.w) & !is.na(d$.out), , drop = FALSE]

  # Missing-demographic policy.
  if (na_demographic == "keep") {
    if (anyNA(d$.grp)) {
      d$.grp <- addNA(d$.grp)                                  # NA becomes an explicit level
      levels(d$.grp)[is.na(levels(d$.grp))] <- "(Missing)"
    } else {
      d$.grp <- droplevels(d$.grp)
    }
  } else {                                                     # "drop"
    d <- d[!is.na(d$.grp), , drop = FALSE]
    d$.grp <- droplevels(d$.grp)
  }

  if (nrow(d) == 0) {
    stop("No non-missing rows for outcome '", outcome, "' x demographic '",
         demographic, "'.", call. = FALSE)
  }
  if (nlevels(d$.grp) == 0) {
    stop("Demographic '", demographic, "' has no non-missing categories.", call. = FALSE)
  }

  # Weighted counts, then normalize within each demographic column.
  design <- survey::svydesign(ids = ~1, weights = ~.w, data = d)
  counts <- survey::svytable(~.grp + .out, design)             # rows = groups, cols = responses
  col_props <- prop.table(counts, margin = 1)                  # each group row sums to 1
  m <- t(as.matrix(col_props))                                 # rows = responses, cols = groups

  # Assemble tibble: Response column (in factor order) + one column per demographic category.
  props <- tibble::tibble(Response = factor(rownames(m), levels = levels(d$.out)))
  for (g in colnames(m)) props[[g]] <- as.numeric(m[, g])
  props
}

#' Format one proportion table as a styled gt table.
#' @noRd
.wc_gt <- function(props, question, demographic, digits) {
  navy       <- "#1F2A44"
  stripe     <- "#F2F4F6"
  cat_cols   <- setdiff(names(props), "Response")
  title_text <- gsub("[\r\n]+", " ", question)                 # labels can contain newlines

  gt::gt(props) |>
    gt::tab_header(title = gt::md(paste0("**", title_text, "**"))) |>
    gt::tab_spanner(label = demographic, columns = tidyselect::all_of(cat_cols)) |>
    gt::fmt_percent(columns = tidyselect::all_of(cat_cols), decimals = digits) |>
    gt::cols_align("right", columns = tidyselect::all_of(cat_cols)) |>
    gt::cols_align("left", columns = "Response") |>
    gt::cols_label(Response = "Response") |>
    gt::opt_row_striping() |>
    gt::tab_style(
      style = gt::cell_text(weight = "bold"),
      locations = gt::cells_body(columns = "Response")
    ) |>
    gt::tab_style(                                             # vertical rule after Response
      style = gt::cell_borders(sides = "right", color = navy, weight = gt::px(1.5)),
      locations = list(
        gt::cells_body(columns = "Response"),
        gt::cells_column_labels(columns = "Response")
      )
    ) |>
    gt::tab_options(
      table.font.names            = c("Helvetica", "Arial", "sans-serif"),
      table.font.color            = navy,
      column_labels.font.weight   = "bold",
      row.striping.background_color = stripe,
      table.border.top.style      = "none",
      heading.align               = "left",
      heading.title.font.size     = gt::px(15)
    )
}
