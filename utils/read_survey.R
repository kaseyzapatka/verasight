# utils/read_survey.R
# Shared helper for the Verasight data-science toolbox.
# Source with: source("utils/read_survey.R")

#' Read a Verasight survey data file
#'
#' Thin, documented wrapper around \code{readRDS()} for the survey \code{.rds} files used
#' across projects. Centralizing file reads keeps loading consistent for teammates and gives
#' one place to add validation, logging, or an alternate backend (e.g. an API pull) later
#' without touching analysis code.
#'
#' @param path Character. Path to a \code{.rds} file.
#' @param expect_cols Optional character vector of column names that must be present. If any
#'   are missing the function stops with an informative error. Defaults to \code{NULL}
#'   (no check).
#' @param quiet Logical. If \code{FALSE} (default) prints a one-line summary (dims + object
#'   class) after reading. Set \code{TRUE} to silence.
#'
#' @return The object stored in the \code{.rds} file (typically a tibble/data.frame).
#'
#' @examples
#' \dontrun{
#' responses <- read_survey("data/2024-054_responses.rds")
#' users     <- read_survey("data/users.rds", expect_cols = c("ID", "signup_date"))
#' }
read_survey <- function(path, expect_cols = NULL, quiet = FALSE) {
  if (!is.character(path) || length(path) != 1) {
    stop("`path` must be a single file path (character).", call. = FALSE)
  }
  if (!file.exists(path)) {
    stop("File not found: ", path, call. = FALSE)
  }

  obj <- readRDS(path)

  # Optional schema guard: fail early and informatively if expected columns are absent.
  if (!is.null(expect_cols)) {
    have <- colnames(obj)
    missing <- setdiff(expect_cols, have)
    if (length(missing) > 0) {
      stop("Missing expected column(s) in ", basename(path), ": ",
           paste(missing, collapse = ", "), call. = FALSE)
    }
  }

  if (!quiet) {
    dims <- if (!is.null(dim(obj))) paste(dim(obj), collapse = " x ") else length(obj)
    message(sprintf("Read %s  [%s, %s]", basename(path), dims, class(obj)[1]))
  }

  obj
}
