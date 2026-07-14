# utils/density.R
# Shared helpers for response-"density" (concentration) analysis.
# Source with: source("utils/density.R")
#
# Dependencies: ggplot2 (only for density_figure); dplyr/tibble. Loaded lazily.

#' Clean a raw response table for per-user analysis
#'
#' De-duplicates exact-duplicate rows and drops rows whose id is missing
#' (unattributable responses can't be assigned to any user).
#'
#' @param df Data frame of survey responses (one row per response).
#' @param id_col Name of the user-id column. Default "ID".
#' @return `df` with duplicates removed and missing-id rows dropped.
clean_responses <- function(df, id_col = "ID") {
  df <- dplyr::distinct(df)
  df[!is.na(df[[id_col]]), , drop = FALSE]
}

#' Validate a per-user counts vector before use
#'
#' Fails loudly rather than silently returning NA/NaN. Counts must be numeric,
#' non-empty, free of NA, non-negative, and sum to more than zero. (In this
#' project NA IDs are already dropped upstream by `clean_responses()`; this is a
#' guard for any other/future caller.)
#' @noRd
.check_counts <- function(counts) {
  if (!is.numeric(counts)) stop("`counts` must be numeric.", call. = FALSE)
  if (length(counts) == 0) stop("`counts` is empty - need at least one user.", call. = FALSE)
  if (anyNA(counts))       stop("`counts` contains NA - drop missing values before calling.", call. = FALSE)
  if (any(counts < 0))     stop("`counts` has negative values.", call. = FALSE)
  if (sum(counts) == 0)    stop("`counts` sum to zero - no responses to distribute.", call. = FALSE)
  invisible(TRUE)
}

#' Concentration (Lorenz-style) curve from per-user response counts
#'
#' Users are ordered most-active-first, so the curve rises as steeply as
#' possible. Point (x, y) reads: "the busiest x of users produced y of responses."
#'
#' @param counts Numeric vector of responses per user.
#' @return Tibble with `cum_users` and `cum_responses` (both 0-1).
concentration_curve <- function(counts) {
  .check_counts(counts)
  counts <- sort(counts, decreasing = TRUE)
  n <- length(counts)
  tibble::tibble(
    cum_users     = seq_len(n) / n,
    cum_responses = cumsum(as.numeric(counts)) / sum(counts)
  )
}

#' Smallest share of users (most active first) reaching `target` of responses
#'
#' The headline "density" metric: e.g. target = 0.5 gives the smallest fraction
#' of users that together account for half of all responses.
#'
#' @param counts Numeric vector of responses per user.
#' @param target Cumulative response share to reach (0-1). Default 0.5.
#' @return A single fraction in 0-1.
min_user_share_for <- function(counts, target = 0.5) {
  if (!is.numeric(target) || length(target) != 1 || is.na(target) || target <= 0 || target > 1) {
    stop("`target` must be a single number in (0, 1].", call. = FALSE)
  }
  cc <- concentration_curve(counts)   # validates `counts`
  cc$cum_users[which(cc$cum_responses >= target)[1]]
}

#' Gini coefficient of a non-negative vector (0 = perfectly even, 1 = all in one).
#' @param x Numeric vector.
gini <- function(x) {
  .check_counts(x)
  x <- sort(as.numeric(x)); n <- length(x)
  2 * sum(seq_len(n) * x) / (n * sum(x)) - (n + 1) / n
}

#' Build a concentration-curve figure (ggplot) for a set of per-user counts
#'
#' Draws the concentration curve, the line of perfect equality, the 10%-90%
#' response thresholds, and a highlighted marker + guide lines at the 50%
#' threshold (the base question). Both axes run 0-100 in steps of 10. The
#' returned ggplot carries a `text` aesthetic, so `plotly::ggplotly(fig,
#' tooltip = "text")` yields clean hover labels.
#'
#' @param counts Numeric vector of responses per user.
#' @param title Optional plot title.
#' @return A ggplot object.
density_figure <- function(counts, title = NULL) {
  navy <- "#1F2A44"; accent <- "#2E6E8E"; gray <- "#B7BEC7"; hi <- "#B23A48"

  # Curve, downsampled for a light figure; prepend the origin so the line starts at (0,0).
  cc  <- concentration_curve(counts)
  idx <- unique(round(seq(1, nrow(cc), length.out = min(nrow(cc), 1500))))
  cp  <- cc[idx, ]
  cp  <- tibble::tibble(
    x = c(0, cp$cum_users * 100),
    y = c(0, cp$cum_responses * 100)
  )
  cp$hover <- sprintf("top %.1f%% of users → %.1f%% of responses", cp$x, cp$y)

  # 10%-90% threshold markers (50% is drawn separately as the highlight).
  thr   <- setdiff(seq(0.1, 0.9, 0.1), 0.5)
  marks <- tibble::tibble(
    x = vapply(thr, function(t) 100 * min_user_share_for(counts, t), numeric(1)),
    y = thr * 100
  )
  marks$hover <- sprintf("%.0f%% of responses ← top %.1f%% of users", marks$y, marks$x)

  x50 <- 100 * min_user_share_for(counts, 0.5)
  hi_pt <- tibble::tibble(
    x = x50, y = 50,
    hover = sprintf("50%% of responses ← top %.1f%% of users", x50)
  )

  ggplot2::ggplot(cp, ggplot2::aes(x, y)) +
    ggplot2::geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = gray) +
    # 50% guide lines (base question)
    ggplot2::annotate("segment", x = 0, xend = x50, y = 50, yend = 50, linetype = "dotted", color = hi) +
    ggplot2::annotate("segment", x = x50, xend = x50, y = 0, yend = 50, linetype = "dotted", color = hi) +
    ggplot2::geom_line(ggplot2::aes(text = hover), color = navy, linewidth = 1) +
    ggplot2::geom_point(data = marks, ggplot2::aes(x, y, text = hover),
                        color = accent, size = 2, inherit.aes = FALSE) +
    ggplot2::geom_point(data = hi_pt, ggplot2::aes(x, y, text = hover),
                        color = hi, size = 3.5, inherit.aes = FALSE) +
    ggplot2::scale_x_continuous(breaks = seq(0, 100, 10), limits = c(0, 100)) +
    ggplot2::scale_y_continuous(breaks = seq(0, 100, 10), limits = c(0, 100)) +
    ggplot2::labs(title = title,
                  x = "Cumulative % of users (most active first)",
                  y = "Cumulative % of responses") +
    ggplot2::theme_minimal(base_family = "sans", base_size = 12) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank(),
                   plot.title = ggplot2::element_text(color = navy, size = 13))
}
