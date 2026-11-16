# ============================================================
# Tool:         longterm_ratios
# Description:  A gauge's or catchment's long-term rain against SAAR, with SAAR moved from
#               1961-1990 to the record's own years using HadUK-Grid
# Flode Module: reach.forcing
# Author:       reach.forcing contributors
# Created:      2026-11-16
# Tier:         1
# Inputs:       Annual rain by water year (mm) from the gauge and HadUK-Grid; HadUK-Grid's
#               1961-1990 mean (mm); SAAR (mm)
# Outputs:      The climate factor c, method ratio m and bias index b, with flags
# Dependencies: none
# ============================================================

#' Long-term rain against SAAR
#'
#' A gauge's long-term mean should match SAAR once SAAR is moved from 1961 to 1990 to the
#' gauge's own years, and HadUK-Grid supplies that move. Over the years both records cover:
#'
#' - the climate factor `c = mean(HadUK over the years) / HadUK 1961-1990 mean`;
#' - the method ratio `m = HadUK 1961-1990 mean / SAAR`, HadUK against SAAR over the same years,
#'   so a difference of method rather than climate;
#' - the bias index `b = mean(gauge over the years) / (SAAR * c)`, the gauge against SAAR moved
#'   to its period.
#'
#' The same works for a catchment, with catchment averages in place of the gauge and cell.
#'
#' @param gauge Annual rain from the gauge (or catchment), mm, named by water year.
#' @param haduk Annual HadUK-Grid rain at the gauge's cell (or over the catchment), mm, named by
#'   water year.
#' @param haduk_baseline HadUK-Grid's 1961-1990 mean annual rain at the same place, mm.
#' @param saar SAAR at the same place, mm.
#' @param min_years Fewest complete years needed to raise a flag.
#' @param b_limits Range of the bias index outside which it is flagged.
#' @param m_limits Range of the method ratio outside which it is flagged.
#' @return A one-row data frame: `years`, `c`, `m`, `b`, `b_flag` and `m_flag` (`"ok"`, `"low"`,
#'   `"high"`, or `"too_few_years"`).
#' @examples
#' years <- as.character(2001:2015)
#' gauge <- setNames(rep(900, 15), years)
#' haduk <- setNames(rep(1050, 15), years)
#' longterm_ratios(gauge, haduk, haduk_baseline = 1000, saar = 1000)  # b 0.857: low
#' @export
longterm_ratios <- function(gauge, haduk, haduk_baseline, saar, min_years = 10L,
                            b_limits = c(0.9, 1.1), m_limits = c(0.95, 1.05)) {
  .check(is.numeric(gauge) && !is.null(names(gauge)), "gauge must be named by water year")
  .check(is.numeric(haduk) && !is.null(names(haduk)), "haduk must be named by water year")
  .check(.scalar(haduk_baseline, 0, strict = TRUE), "haduk_baseline must be positive, mm")
  .check(.scalar(saar, 0, strict = TRUE), "saar must be positive, mm")
  .check(.scalar(min_years, 1), "min_years must be at least one")
  .check(is.numeric(b_limits) && length(b_limits) == 2L && b_limits[1] < b_limits[2],
         "b_limits must be two increasing numbers")
  .check(is.numeric(m_limits) && length(m_limits) == 2L && m_limits[1] < m_limits[2],
         "m_limits must be two increasing numbers")
  years <- intersect(names(gauge)[is.finite(gauge)], names(haduk)[is.finite(haduk)])
  m <- haduk_baseline / saar
  if (length(years) == 0L) {
    return(data.frame(years = 0L, c = NA_real_, m = m, b = NA_real_,
                      b_flag = "too_few_years", m_flag = .flag(m, m_limits)))
  }
  c <- mean(haduk[years]) / haduk_baseline
  b <- mean(gauge[years]) / (saar * c)
  b_flag <- if (length(years) < min_years) "too_few_years" else .flag(b, b_limits)
  data.frame(years = length(years), c = c, m = m, b = b, b_flag = b_flag,
             m_flag = .flag(m, m_limits))
}

.flag <- function(v, limits) {
  if (v < limits[1]) "low" else if (v > limits[2]) "high" else "ok"
}
