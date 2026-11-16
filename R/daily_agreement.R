# ============================================================
# Tool:         daily_agreement
# Description:  A gauge's daily totals against its neighbours and H19: wet-day agreement,
#               dry-while-wet and wet-while-dry days, and bias in bands of daily total
# Flode Module: reach.forcing
# Author:       reach.forcing contributors
# Created:      2026-11-16
# Tier:         1
# Inputs:       Daily totals (mm, 09:00 rain day) of the gauge, its neighbours' median and,
#               optionally, its H19 pixel; the month of each day
# Outputs:      A data frame of checks in the catchment_checks layout
# Dependencies: none
# ============================================================

#' Daily agreement with neighbours and H19
#'
#' At daily scale a gauge, its neighbours and its H19 pixel should agree on which days are wet
#' and roughly how wet. Use totals on the same rain day as HadUK-Grid (09:00 to 09:00 UTC).
#'
#' - `hit_rate`: the share of days the neighbours call wet that the gauge calls wet; flagged
#'   below `min_hit`.
#' - `false_alarm`: the share of the gauge's wet days the neighbours call dry; flagged above
#'   `max_false`.
#' - `dry_while_wet`: days the gauge records 0 while the neighbours (and H19) exceed `heavy`;
#'   flagged for any month with more than `per_month`.
#' - `wet_while_dry`: days the gauge exceeds `heavy` while the neighbours (and H19) record
#'   under `dry`; flagged likewise.
#' - `bias_<band>`: the median ratio of gauge to neighbours on days in each band of the
#'   neighbours' total; flagged outside `band_limits`.
#'
#' A day is wet at `wet` mm or more. Days missing at the gauge or the neighbours are left out;
#' a missing H19 value does not stop a day counting.
#'
#' @param gauge Daily totals at the gauge, mm.
#' @param neighbours The median daily total of the gauge's neighbours, mm.
#' @param h19 Optional daily totals of the gauge's H19 pixel, mm.
#' @param month An identifier of each day's month (for example `"2015-01"`), for the monthly
#'   counts.
#' @param wet,heavy,dry Thresholds, mm: a wet day; a clearly wet day; a clearly dry day.
#' @param per_month Days a month above which dry-while-wet or wet-while-dry is flagged.
#' @param min_hit,max_false Limits of the hit and false-alarm rates.
#' @param bands Lower edges of the bands of daily total for the bias, mm.
#' @param band_limits Range of the median ratio outside which a band is flagged.
#' @param min_days Fewest days needed in a measure to raise a flag.
#' @return A data frame with one row per check: `check`, `value`, `n`, `flag`, and `months`
#'   (the months flagged, for the two day counts).
#' @examples
#' n <- 365
#' set.seed(2)
#' neighbours <- pmax(0, rgamma(n, 0.6, 0.15) - 1)
#' gauge <- neighbours
#' # A blocked funnel for eleven days
#' gauge[100:110] <- 0
#' month <- format(as.Date("2015-01-01") + 0:(n - 1), "%Y-%m")
#' daily_agreement(gauge, neighbours, month = month)
#' @export
daily_agreement <- function(gauge, neighbours, h19 = NULL, month, wet = 1, heavy = 5,
                            dry = 0.5, per_month = 2L, min_hit = 0.8, max_false = 0.2,
                            bands = c(1, 5, 15, 30), band_limits = c(0.8, 1.25),
                            min_days = 30L) {
  n <- length(gauge)
  .check(is.numeric(gauge) && is.numeric(neighbours) && length(neighbours) == n,
         "gauge and neighbours must be numeric vectors of the same length")
  .check(length(month) == n, "month needs one value per day")
  .check(is.null(h19) || (is.numeric(h19) && length(h19) == n), "h19 needs one value per day")
  ok <- is.finite(gauge) & is.finite(neighbours)
  g <- gauge[ok]
  r <- neighbours[ok]
  m <- month[ok]
  h <- if (is.null(h19)) rep(NA_real_, length(g)) else h19[ok]

  ref_wet <- r >= wet
  g_wet <- g >= wet
  hit <- if (any(ref_wet)) mean(g_wet[ref_wet]) else NA_real_
  false <- if (any(g_wet)) mean(!ref_wet[g_wet]) else NA_real_
  rows <- list(
    .day_row("hit_rate", hit, sum(ref_wet),
             if (sum(ref_wet) < min_days) "too_few" else if (hit < min_hit) "low" else "ok"),
    .day_row("false_alarm", false, sum(g_wet),
             if (sum(g_wet) < min_days) "too_few" else if (false > max_false) "high" else "ok")
  )
  # H19 joins the test where it is present
  dww <- g == 0 & r > heavy & (is.na(h) | h > heavy)
  wwd <- g > heavy & r < dry & (is.na(h) | h < dry)
  rows <- c(rows, list(.count_row("dry_while_wet", dww, m, per_month),
                       .count_row("wet_while_dry", wwd, m, per_month)))
  edges <- c(bands, Inf)
  for (b in seq_along(bands)) {
    k <- r >= edges[b] & r < edges[b + 1] & r > 0
    label <- if (is.finite(edges[b + 1])) {
      sprintf("bias_%g_to_%g", edges[b], edges[b + 1])
    } else {
      sprintf("bias_over_%g", edges[b])
    }
    v <- if (any(k)) stats::median(g[k] / r[k]) else NA_real_
    flag <- if (sum(k) < min_days) "too_few" else .range_flag(v, band_limits)
    rows <- c(rows, list(.day_row(label, v, sum(k), flag)))
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

.day_row <- function(check, value, n, flag, months = "") {
  data.frame(check = check, value = value, n = as.integer(n), flag = flag, months = months)
}

# Days of a kind, and the months with more than per_month of them.
.count_row <- function(check, hit, month, per_month) {
  by_month <- tapply(hit, month, sum)
  bad <- names(by_month)[by_month > per_month]
  .day_row(check, sum(hit), sum(hit), if (length(bad)) "flagged" else "ok",
           paste(bad, collapse = ", "))
}

.range_flag <- function(v, limits) {
  if (v < limits[1]) "low" else if (v > limits[2]) "high" else "ok"
}
