# ============================================================
# Tool:         operational_rain
# Description:  Catchment rainfall rebuilt as the operational forecasting system makes it:
#               fixed Thiessen weights scaled up over the gauges that report, a radar
#               fallback at a small standing weight, and radar alone below a temperature
#               threshold
# Flode Module: reach.forcing
# Author:       reach.forcing contributors
# Created:      2026-11-16
# Tier:         1
# Inputs:       Gauge depths per step (mm), operational weights, catchment H19 (mm),
#               temperature (C)
# Outputs:      A data frame: catchment rain per step with the rule that made it
# Dependencies: none
# ============================================================

#' Catchment rainfall built the operational way
#'
#' Rebuilds catchment rainfall exactly as the operational forecasting system makes it, so a
#' calibration of record uses the inputs forecasters will use. At each step:
#'
#' 1. **Below the temperature threshold**, the catchment takes H19 alone, since unheated gauges
#'    under-catch snow or freeze. With `cold_fallback = "gauges"`, a cold step with no H19 falls
#'    back to the gauges; with `"missing"` it is missing.
#' 2. **Otherwise**, the rain is the weighted mean of the inputs that report: each gauge with its
#'    fixed weight, and H19 with its standing weight (0.01 by default). Weights are scaled up
#'    over whatever reports, so a failed gauge's share is spread across the others in
#'    proportion to their own weights, and when every gauge fails H19 carries the catchment:
#'
#'    `rain = (sum(w_g * g) + w_h * h) / (sum(w_g) + w_h)`, over the inputs present.
#'
#' The weights are used as given: they need not sum to one, since the scaling divides by the
#' weight present. Whether the operational system includes H19's weight in that division is
#' one of the things the comparison with logged operational inputs (data build step 5.6)
#' confirms.
#'
#' @param gauge_rain Numeric matrix of gauge depths, mm per step: one row per step, one column
#'   per gauge, with column names matching `names(weights)`. `NA` marks a gauge that did not
#'   report.
#' @param weights Named numeric vector of operational gauge weights, nonnegative.
#' @param h19 Optional numeric vector of catchment-average H19, mm per step, one per row of
#'   `gauge_rain`; `NA` where missing.
#' @param temperature Optional numeric vector of air temperature, degrees C, one per row; `NA`
#'   where missing (the step is then treated as warm).
#' @param h19_weight The standing weight of H19 beside the gauges.
#' @param threshold Temperature below which the catchment takes H19 alone, degrees C.
#' @param cold_fallback What a cold step does with no H19: `"gauges"` uses the warm rule,
#'   `"missing"` leaves it missing.
#' @return A data frame with one row per step: `rain_mm`; `source`, one of `"blend"` (at least
#'   one gauge reported), `"h19_fallback"` (no gauge, H19 alone), `"h19_cold"` (below the
#'   threshold), `"cold_gauges"` (below the threshold with no H19, falling back to the gauges)
#'   or `"missing"`; `gauges_reporting`; and `weight_present`, the share of the total gauge
#'   weight that reported.
#' @examples
#' rain <- cbind(A = c(1, 2, NA, NA), B = c(3, NA, 2, NA))
#' operational_rain(rain, weights = c(A = 0.6, B = 0.4), h19 = c(2, 2, 2, 5),
#'                  temperature = c(10, 10, 10, 10))
#' @export
operational_rain <- function(gauge_rain, weights, h19 = NULL, temperature = NULL,
                             h19_weight = 0.01, threshold = 4,
                             cold_fallback = c("gauges", "missing")) {
  cold_fallback <- match.arg(cold_fallback)
  .check(is.matrix(gauge_rain) && is.numeric(gauge_rain) && !is.null(colnames(gauge_rain)),
         "gauge_rain must be a numeric matrix with one named column per gauge")
  .check(is.numeric(weights) && !is.null(names(weights)) && all(is.finite(weights)) &&
           all(weights >= 0) && any(weights > 0),
         "weights must be a named numeric vector, nonnegative, with at least one above zero")
  missing_cols <- setdiff(names(weights), colnames(gauge_rain))
  .check(length(missing_cols) == 0L,
         paste("gauge_rain has no column for:", paste(missing_cols, collapse = ", ")))
  .check(.scalar(h19_weight, 0), "h19_weight must be one nonnegative number")
  .check(.scalar(threshold), "threshold must be one number, degrees C")
  n <- nrow(gauge_rain)
  h19 <- .as_series(h19, n)
  temperature <- .as_series(temperature, n)
  .check(is.numeric(h19) && length(h19) == n, "h19 needs one value per row of gauge_rain")
  .check(is.numeric(temperature) && length(temperature) == n,
         "temperature needs one value per row of gauge_rain")
  .check(all(h19 >= 0, na.rm = TRUE) && all(gauge_rain >= 0, na.rm = TRUE),
         "rain depths must be nonnegative")

  g <- gauge_rain[, names(weights), drop = FALSE]
  present <- is.finite(g)
  w <- matrix(weights, nrow = n, ncol = length(weights), byrow = TRUE)
  w[!present] <- 0
  g[!present] <- 0
  gauge_weight <- rowSums(w)
  gauge_sum <- rowSums(w * g)
  has_h19 <- is.finite(h19)
  h19_w <- ifelse(has_h19, h19_weight, 0)
  h19_part <- ifelse(has_h19, h19_weight * h19, 0)
  denominator <- gauge_weight + h19_w
  warm <- ifelse(denominator > 0, (gauge_sum + h19_part) / denominator, NA_real_)
  n_gauges <- rowSums(present)

  source <- ifelse(n_gauges > 0, "blend", ifelse(has_h19, "h19_fallback", "missing"))
  rain <- warm
  cold <- is.finite(temperature) & temperature < threshold
  cold_h19 <- cold & has_h19
  rain[cold_h19] <- h19[cold_h19]
  source[cold_h19] <- "h19_cold"
  cold_none <- cold & !has_h19
  if (cold_fallback == "missing") {
    rain[cold_none] <- NA_real_
    source[cold_none] <- "missing"
  } else {
    source[cold_none & n_gauges > 0] <- "cold_gauges"
  }
  source[!is.finite(rain)] <- "missing"

  data.frame(rain_mm = rain, source = source, gauges_reporting = as.integer(n_gauges),
             weight_present = gauge_weight / sum(weights))
}

# NULL as all missing; an all-NA logical vector (as c(NA, NA) arrives) as missing numbers.
.as_series <- function(x, n) {
  if (is.null(x)) return(rep(NA_real_, n))
  if (is.logical(x) && all(is.na(x))) return(as.numeric(x))
  x
}
