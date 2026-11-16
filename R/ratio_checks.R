# ============================================================
# Tool:         ratio_checks
# Description:  A gauge's monthly totals against a reference (HadUK-Grid, H19 or its
#               neighbours): typical ratio with a bootstrap interval, spread, winter against
#               summer, trend and change point in the annual ratio
# Flode Module: reach.forcing
# Author:       reach.forcing contributors
# Created:      2026-11-16
# Tier:         1
# Inputs:       Monthly totals (mm) of the gauge and the reference; their water years and months
# Outputs:      A data frame of checks in the catchment_checks layout
# Dependencies: none
# ============================================================

#' Drift and breaks: a gauge against a reference, month by month
#'
#' The month-by-month ratio of a gauge to a reference (its HadUK-Grid cell, its H19 pixel or the
#' mean of its neighbours) should be steady. A typical ratio away from one, a trend or a step in
#' it marks a gauge that has changed, not the weather. Ratios are taken in logs, `r = log(G / R)`,
#' and reported as factors.
#'
#' - `typical_ratio`: `exp(median(r))`, with a bootstrap interval over water years; flagged
#'   when the whole interval lies outside `limits`.
#' - `spread`: the median absolute deviation of `r`; reported, not flagged.
#' - `winter_summer`: the typical ratio in December to February over that in June to August;
#'   flagged below `limits[1]`, as winter under-catch.
#' - `trend`: Sen's slope of the annual log ratio, as per cent a decade; flagged beyond
#'   `trend_limit`.
#' - `change_point`: Pettitt's test on the annual log ratio, giving the step, per cent, at the
#'   year found; flagged when significant at `alpha` with a step beyond `step_limit`.
#'
#' Months where either total is missing or not positive are left out. The annual log ratio is
#' the log of the ratio of annual totals over the months present. Below `min_months` months, or
#' `min_years` years for the trend and change point, a check is reported with its count and not
#' flagged.
#'
#' @param gauge,reference Monthly totals, mm, the same length.
#' @param year Water year of each month.
#' @param month Calendar month of each total, 1 to 12; needed for `winter_summer`.
#' @param limits Range of the typical ratio outside which it is flagged.
#' @param trend_limit Trend, per cent a decade, beyond which it is flagged.
#' @param step_limit Step, per cent, beyond which a significant change point is flagged.
#' @param alpha Significance level of the change point.
#' @param min_months,min_years Fewest months, and water years, needed to raise a flag.
#' @param boot Bootstrap resamples for the typical ratio's interval.
#' @param level Coverage of the interval.
#' @param seed Optional seed, for a repeatable interval; the caller's random state is restored.
#' @return A data frame with one row per check: `check`, `value`, `lower`, `upper` (the
#'   interval, where there is one), `n` (months or years used), `flag` (`"ok"`, `"low"`,
#'   `"high"`, `"flagged"` or `"too_few"`), and `at` (the change point's water year).
#' @examples
#' set.seed(1)
#' year <- rep(2001:2015, each = 12)
#' month <- rep(c(10:12, 1:9), 15)
#' reference <- runif(180, 40, 120)
#' gauge <- reference * 0.88
#' ratio_checks(gauge, reference, year, month, seed = 1)
#' @export
ratio_checks <- function(gauge, reference, year, month = NULL, limits = c(0.9, 1.1),
                         trend_limit = 3, step_limit = 5, alpha = 0.05, min_months = 24L,
                         min_years = 10L, boot = 1000L, level = 0.9, seed = NULL) {
  n <- length(gauge)
  .check(is.numeric(gauge) && is.numeric(reference) && length(reference) == n,
         "gauge and reference must be numeric vectors of the same length")
  .check(length(year) == n, "year needs one value per month")
  .check(is.null(month) || (length(month) == n && all(month %in% 1:12, na.rm = TRUE)),
         "month needs one value, 1 to 12, per total")
  .check(is.numeric(limits) && length(limits) == 2L && limits[1] < limits[2],
         "limits must be two increasing numbers")
  .check(.scalar(boot, 1), "boot must be at least one")
  .check(.scalar(level, 0, strict = TRUE) && level < 1, "level must lie between 0 and 1")
  ok <- is.finite(gauge) & is.finite(reference) & gauge > 0 & reference > 0
  r <- log(gauge[ok] / reference[ok])
  yr <- year[ok]
  mo <- if (is.null(month)) NULL else month[ok]

  rows <- list()
  # Typical ratio, with a bootstrap over water years so months in one year move together
  typical <- if (length(r)) exp(stats::median(r)) else NA_real_
  ci <- if (length(r)) .with_seed(seed, .boot_years(r, yr, boot, level)) else c(NA, NA)
  rows$typical <- .row("typical_ratio", typical, ci[1], ci[2], length(r),
                       if (length(r) < min_months) "too_few" else .interval_flag(ci, limits))
  rows$spread <- .row("spread", if (length(r)) stats::mad(r) else NA_real_, NA, NA, length(r),
                      if (length(r) < min_months) "too_few" else "ok")
  if (!is.null(mo)) {
    winter <- r[mo %in% c(12, 1, 2)]
    summer <- r[mo %in% 6:8]
    ws <- if (length(winter) && length(summer)) {
      exp(stats::median(winter) - stats::median(summer))
    } else {
      NA_real_
    }
    enough <- length(winter) >= min_months / 4 && length(summer) >= min_months / 4
    rows$ws <- .row("winter_summer", ws, NA, NA, length(winter) + length(summer),
                    if (!enough) "too_few" else if (ws < limits[1]) "low" else "ok")
  }

  # Annual log ratio of totals over the months present
  years <- sort(unique(yr))
  annual <- vapply(years, function(y) {
    k <- which(year == y & ok)
    log(sum(gauge[k]) / sum(reference[k]))
  }, numeric(1))
  enough_years <- length(years) >= min_years
  slope <- if (length(years) >= 2L) .sen_slope(as.numeric(years), annual) else NA_real_
  trend <- (exp(10 * slope) - 1) * 100
  rows$trend <- .row("trend", trend, NA, NA, length(years),
                     if (!enough_years) "too_few" else if (abs(trend) > trend_limit) "flagged"
                     else "ok")
  pt <- if (length(years) >= 3L) .pettitt(annual) else list(index = NA, p = NA)
  step <- NA_real_
  if (!is.na(pt$index)) {
    step <- (exp(mean(annual[-seq_len(pt$index)]) - mean(annual[seq_len(pt$index)])) - 1) * 100
  }
  cp_flag <- if (!enough_years) "too_few" else if (pt$p < alpha && abs(step) > step_limit) {
    "flagged"
  } else {
    "ok"
  }
  rows$cp <- .row("change_point", step, NA, NA, length(years), cp_flag,
                  at = if (is.na(pt$index)) NA else years[pt$index + 1L])
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

# One row of checks.
.row <- function(check, value, lower, upper, n, flag, at = NA) {
  data.frame(check = check, value = value, lower = as.numeric(lower), upper = as.numeric(upper),
             n = as.integer(n), flag = flag, at = at)
}

# Flag only when the whole interval lies beyond a limit.
.interval_flag <- function(ci, limits) {
  if (any(!is.finite(ci))) return("too_few")
  if (ci[2] < limits[1]) "low" else if (ci[1] > limits[2]) "high" else "ok"
}

# Bootstrap interval of exp(median(r)), resampling whole water years.
.boot_years <- function(r, yr, boot, level) {
  groups <- split(r, yr)
  stats_b <- vapply(seq_len(boot), function(i) {
    pick <- sample.int(length(groups), length(groups), replace = TRUE)
    exp(stats::median(unlist(groups[pick], use.names = FALSE)))
  }, numeric(1))
  a <- (1 - level) / 2
  unname(stats::quantile(stats_b, c(a, 1 - a)))
}

# Sen's slope: the median of the slopes between every pair of points.
.sen_slope <- function(x, y) {
  pairs <- utils::combn(length(x), 2L)
  dx <- x[pairs[2, ]] - x[pairs[1, ]]
  keep <- dx != 0
  stats::median((y[pairs[2, keep]] - y[pairs[1, keep]]) / dx[keep])
}

# Pettitt's test for one change in level: the index of the last value before the change, and
# the approximate p-value 2 exp(-6 K^2 / (n^3 + n^2)).
.pettitt <- function(x) {
  n <- length(x)
  s <- sign(outer(x, x, "-"))   # row j, column i: the sign of x at j less x at i
  u <- vapply(seq_len(n - 1L), function(t) sum(s[(t + 1L):n, seq_len(t)]), numeric(1))
  k <- max(abs(u))
  list(index = which.max(abs(u)), p = min(1, 2 * exp(-6 * k^2 / (n^3 + n^2))), k = k)
}

# Runs code with a seed when given, restoring the caller's random state afterwards.
.with_seed <- function(seed, code) {
  if (is.null(seed)) return(code)
  had <- exists(".Random.seed", envir = globalenv(), inherits = FALSE)
  if (had) old <- get(".Random.seed", envir = globalenv())
  on.exit(if (had) assign(".Random.seed", old, envir = globalenv())
          else rm(".Random.seed", envir = globalenv()))
  set.seed(seed)
  force(code)
}
