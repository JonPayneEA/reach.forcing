# ============================================================
# Tool:         subdaily_checks
# Description:  Hourly comparisons of a gauge with its H19 pixel: the timing offset, and the
#               ratio in bands of air temperature that tests the cold-weather switch
# Flode Module: reach.forcing
# Author:       reach.forcing contributors
# Created:      2026-11-16
# Tier:         1
# Inputs:       Hourly totals (mm) of the gauge and its H19 pixel; hourly air temperature (C)
# Outputs:      The lag of best agreement; ratios by temperature band
# Dependencies: none
# ============================================================

#' Timing offset between a gauge and a reference
#'
#' The lag, in steps, at which the gauge best correlates with the reference (its H19 pixel,
#' hourly). A positive lag means the gauge records rain later than the reference: a clock or
#' summer-time error when it is an hour or more.
#'
#' @param gauge,reference Totals per step, mm, on the same steps.
#' @param max_lag Largest lag tried in each direction, steps.
#' @param min_pairs Fewest wet steps in common needed to report a lag.
#' @return A one-row data frame: `lag` (steps; `NA` with too few pairs), `correlation` at that
#'   lag, `correlation_zero` at lag zero, and `n`, the steps compared at lag zero.
#' @examples
#' set.seed(3)
#' h19 <- pmax(0, rnorm(2000, -1, 2))
#' gauge <- c(rep(0, 2), head(h19, -2))   # the gauge two hours late
#' timing_offset(gauge, h19)$lag
#' @export
timing_offset <- function(gauge, reference, max_lag = 6L, min_pairs = 50L) {
  n <- length(gauge)
  .check(is.numeric(gauge) && is.numeric(reference) && length(reference) == n,
         "gauge and reference must be numeric vectors of the same length")
  .check(.scalar(max_lag, 0) && max_lag < n, "max_lag must be a nonnegative count below the length")
  lags <- seq(-max_lag, max_lag)
  cors <- vapply(lags, function(k) .lag_cor(gauge, reference, k, min_pairs), numeric(1))
  best <- if (all(is.na(cors))) NA_integer_ else as.integer(lags[which.max(cors)])
  data.frame(lag = best, correlation = if (is.na(best)) NA_real_ else max(cors, na.rm = TRUE),
             correlation_zero = cors[lags == 0],
             n = sum(is.finite(gauge) & is.finite(reference)))
}

# Correlation of the gauge at t with the reference at t - k.
.lag_cor <- function(g, r, k, min_pairs) {
  n <- length(g)
  if (k >= 0) {
    a <- g[(k + 1):n]
    b <- r[1:(n - k)]
  } else {
    a <- g[1:(n + k)]
    b <- r[(1 - k):n]
  }
  ok <- is.finite(a) & is.finite(b)
  if (sum(ok & (a > 0 | b > 0)) < min_pairs || stats::sd(a[ok]) == 0 || stats::sd(b[ok]) == 0) {
    return(NA_real_)
  }
  stats::cor(a[ok], b[ok])
}

#' Gauge against H19 by air temperature
#'
#' The evidence for the cold-weather switch: where gauges and H19 part company as the air
#' cools. For each band of temperature, the median of gauge / H19 over hours when H19 records
#' at least `wet` mm. A ratio that falls away in the cold bands shows gauge under-catch of snow;
#' the band where it falls is the threshold the data support.
#'
#' @param gauge,h19 Hourly totals, mm, on the same hours.
#' @param temperature Hourly air temperature, degrees C.
#' @param breaks Edges of the temperature bands, degrees C.
#' @param wet H19 total, mm, from which an hour counts.
#' @param min_hours Fewest hours needed in a band to report its ratio.
#' @return A data frame with one row per band: `band`, `ratio` (median gauge / H19; `NA` with
#'   fewer than `min_hours`), `hours`.
#' @examples
#' set.seed(4)
#' temperature <- runif(5000, -4, 12)
#' h19 <- rexp(5000, 1)
#' gauge <- h19 * ifelse(temperature < 2, 0.7, 1)
#' temperature_bands(gauge, h19, temperature)
#' @export
temperature_bands <- function(gauge, h19, temperature, breaks = c(-Inf, 0, 2, 4, 6, Inf),
                              wet = 0.2, min_hours = 100L) {
  n <- length(gauge)
  .check(is.numeric(gauge) && is.numeric(h19) && length(h19) == n &&
           is.numeric(temperature) && length(temperature) == n,
         "gauge, h19 and temperature must be numeric vectors of the same length")
  .check(is.numeric(breaks) && length(breaks) >= 2L && !is.unsorted(breaks, strictly = TRUE),
         "breaks must be increasing")
  ok <- is.finite(gauge) & is.finite(h19) & is.finite(temperature) & h19 >= wet
  band <- cut(temperature[ok], breaks, right = FALSE)
  ratio <- gauge[ok] / h19[ok]
  levels_b <- levels(band)
  hours <- as.integer(table(factor(band, levels = levels_b)))
  med <- vapply(levels_b, function(l) {
    k <- which(band == l)
    if (length(k) < min_hours) NA_real_ else stats::median(ratio[k])
  }, numeric(1))
  data.frame(band = levels_b, ratio = unname(med), hours = hours)
}
