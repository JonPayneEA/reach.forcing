# ============================================================
# Tool:         event_uncertainty
# Description:  Each event's rain uncertainty, measured without a model, and what the
#               calibration should do with it: full weight, a lower weight, exclusion or review
# Flode Module: reach.forcing
# Author:       reach.forcing contributors
# Created:      2026-11-16
# Tier:         1
# Inputs:       An event table (pdmS7's find_events() or any with the same windows); rain per
#               step by source; optional ensemble members, flow, season and response time
# Outputs:      The event table with uncertainty measures, a use and a weight for calibration
# Dependencies: stats
# ============================================================

#' Event uncertainty before calibration
#'
#' Measures how far each event's rain can be trusted without running a model, and turns that
#' into what the calibration should do with the event. This comes before calibration: events
#' that cannot be right leave the scoring set, and the rest count by how far their rain sources
#' agree.
#'
#' For each event, over its rain window:
#'
#' - `rain_mm`: the operational rain (column `"operational"` of `rain`).
#' - `spread`: the range of the sources' totals over their median, among sources with no more
#'   than `max_missing` of the window missing.
#' - `ens_low`, `ens_high`: the 5 and 95 per cent ensemble totals, when `members` is given.
#' - `runoff_ratio`: quick flow over the operational rain, with `ratio_low` and `ratio_high`
#'   at the highest and lowest plausible rain (the ensemble's, or else the sources' range).
#' - `envelope_z`: how far the runoff ratio sits from events of the same season and starting
#'   wetness, as a robust z-score (difference from the group median over 1.4826 median
#'   absolute deviations); `NA` in groups smaller than `min_group`.
#' - `lag_steps`: steps from the rain's centre of mass to the flow peak, against the
#'   catchment's `response_steps`.
#'
#' Then each event gets a `use`:
#'
#' 1. `"exclude"`: quick flow above `max_ratio` times the rain even at the highest plausible
#'    rain. The event cannot be right whatever the model does; weight 0.
#' 2. `"review"`: the runoff ratio is an outlier for its season and wetness (`|z| > max_z`), or
#'    the timing is off by more than `timing_tolerance` of the response time. A person decides;
#'    the event keeps its weight until they do.
#' 3. `"weight"` or `"full"`: the weight falls linearly from 1 at a spread of `spread_full` to
#'    `min_weight` at `spread_low`, and stays there beyond.
#'
#' @param events Data frame with `event`, `rain_start`, `rain_end`, `flow_start`, `flow_end`
#'   (row numbers of the series) and `quickflow_mm`; `peak_row` too for the timing check. The
#'   table from pdmS7's `find_events()` with `area_km2` given has them all.
#' @param rain Numeric matrix of rain, mm per step: one row per step, one named column per
#'   source, including `"operational"`.
#' @param members Optional matrix of ensemble members, mm per step, one column per member.
#' @param start_flow Optional flow at each event's start, in any unit, for the wetness groups.
#' @param season Optional season of each event (for example `"winter"`), for the envelope.
#' @param response_steps The catchment's response time, steps; `NULL` skips the timing check.
#' @param max_ratio Runoff ratio above which an event is impossible at the highest rain.
#' @param max_z Robust z-score beyond which a runoff ratio is an outlier.
#' @param min_group Fewest events in a season and wetness group to judge an outlier.
#' @param timing_tolerance Share of the response time by which the lag may differ.
#' @param spread_full,spread_low,min_weight The weight's ramp: full weight up to
#'   `spread_full`, falling to `min_weight` at `spread_low`.
#' @param max_missing Largest share of a window a source may miss and still count.
#' @return `events` with `rain_mm`, `spread`, `ens_low`, `ens_high`, `runoff_ratio`,
#'   `ratio_low`, `ratio_high`, `envelope_z`, `lag_steps`, `use`, `weight` and `reason` added.
#' @examples
#' rain <- cbind(operational = c(10, 0, 0, 20, 0, 0), h19 = c(11, 0, 0, 12, 0, 0))
#' events <- data.frame(event = 1:2, rain_start = c(1, 4), rain_end = c(1, 4),
#'                      flow_start = c(1, 4), flow_end = c(3, 6), quickflow_mm = c(4, 25))
#' event_uncertainty(events, rain)[, c("event", "spread", "runoff_ratio", "use", "weight")]
#' @export
event_uncertainty <- function(events, rain, members = NULL, start_flow = NULL, season = NULL,
                              response_steps = NULL, max_ratio = 1, max_z = 3, min_group = 5L,
                              timing_tolerance = 0.5, spread_full = 0.1, spread_low = 0.5,
                              min_weight = 0.2, max_missing = 0.1) {
  need <- c("event", "rain_start", "rain_end", "flow_start", "flow_end", "quickflow_mm")
  .check(is.data.frame(events) && all(need %in% names(events)),
         paste("events needs", paste(need, collapse = ", ")))
  .check(is.matrix(rain) && is.numeric(rain) && "operational" %in% colnames(rain),
         "rain must be a numeric matrix with an \"operational\" column")
  ne <- nrow(events)
  n <- nrow(rain)
  .check(all(events$rain_start >= 1 & events$rain_end <= n & events$rain_start <= events$rain_end),
         "event rain windows must lie within the rows of rain")
  .check(is.null(members) || (is.matrix(members) && nrow(members) == n),
         "members must be a matrix with one row per step of rain")
  .check(is.null(start_flow) || length(start_flow) == ne, "start_flow needs one value per event")
  .check(is.null(season) || length(season) == ne, "season needs one value per event")
  .check(spread_full < spread_low && .scalar(min_weight, 0) && min_weight <= 1,
         "the weight ramp needs spread_full < spread_low and min_weight in [0, 1]")

  window <- function(e) events$rain_start[e]:events$rain_end[e]
  totals <- t(vapply(seq_len(ne), function(e) {
    w <- rain[window(e), , drop = FALSE]
    miss <- colMeans(!is.finite(w))
    ifelse(miss <= max_missing, colSums(w, na.rm = TRUE), NA_real_)
  }, numeric(ncol(rain))))
  totals <- matrix(totals, nrow = ne, dimnames = list(NULL, colnames(rain)))
  out <- events
  out$rain_mm <- totals[, "operational"]
  out$spread <- apply(totals, 1, function(x) {
    x <- x[is.finite(x)]
    if (length(x) < 2L || stats::median(x) <= 0) NA_real_ else diff(range(x)) / stats::median(x)
  })
  if (!is.null(members)) {
    q <- t(vapply(seq_len(ne), function(e) {
      s <- colSums(members[window(e), , drop = FALSE])
      stats::quantile(s, c(0.05, 0.95), names = FALSE, na.rm = TRUE)
    }, numeric(2)))
    out$ens_low <- q[, 1]
    out$ens_high <- q[, 2]
    lo <- out$ens_low
    hi <- out$ens_high
  } else {
    out$ens_low <- NA_real_
    out$ens_high <- NA_real_
    lo <- apply(totals, 1, function(x) if (all(is.na(x))) NA_real_ else min(x, na.rm = TRUE))
    hi <- apply(totals, 1, function(x) if (all(is.na(x))) NA_real_ else max(x, na.rm = TRUE))
  }
  q_mm <- events$quickflow_mm
  out$runoff_ratio <- ifelse(out$rain_mm > 0, q_mm / out$rain_mm, NA_real_)
  out$ratio_low <- ifelse(hi > 0, q_mm / hi, NA_real_)
  out$ratio_high <- ifelse(lo > 0, q_mm / lo, NA_real_)

  out$envelope_z <- .envelope_z(out$runoff_ratio, season, start_flow, min_group)
  out$lag_steps <- NA_real_
  if (!is.null(response_steps) && "peak_row" %in% names(events)) {
    out$lag_steps <- vapply(seq_len(ne), function(e) {
      w <- window(e)
      r <- rain[w, "operational"]
      if (!any(is.finite(r)) || sum(r, na.rm = TRUE) <= 0) return(NA_real_)
      events$peak_row[e] - sum(w * r, na.rm = TRUE) / sum(r, na.rm = TRUE)
    }, numeric(1))
  }

  # Decide each event's use, impossible first
  out$use <- "full"
  out$reason <- ""
  out$weight <- vapply(out$spread, .spread_weight, numeric(1), spread_full, spread_low,
                       min_weight)
  part <- out$weight < 1
  out$use[part] <- "weight"
  out$reason[part] <- sprintf("sources spread %.0f%%", 100 * out$spread[part])
  timing_off <- rep(FALSE, ne)
  if (!is.null(response_steps)) {
    timing_off <- is.finite(out$lag_steps) &
      abs(out$lag_steps - response_steps) > timing_tolerance * response_steps
  }
  outlier <- is.finite(out$envelope_z) & abs(out$envelope_z) > max_z
  review <- outlier | timing_off
  out$use[review] <- "review"
  out$reason[review] <- trimws(paste(
    ifelse(outlier[review], "runoff ratio unusual for season and wetness;", ""),
    ifelse(timing_off[review], "timing off the response time;", "")
  ))
  impossible <- is.finite(out$ratio_low) & out$ratio_low > max_ratio
  out$use[impossible] <- "exclude"
  out$weight[impossible] <- 0
  out$reason[impossible] <- sprintf("quick flow %.2f of the highest plausible rain",
                                    out$ratio_low[impossible])
  out
}

# Full weight up to spread_full, falling linearly to min_weight at spread_low; full weight
# where the spread cannot be measured (a single source), since there is nothing to discount.
.spread_weight <- function(s, spread_full, spread_low, min_weight) {
  if (!is.finite(s) || s <= spread_full) return(1)
  if (s >= spread_low) return(min_weight)
  1 - (1 - min_weight) * (s - spread_full) / (spread_low - spread_full)
}

# Robust z-score of each runoff ratio within its season and starting-wetness tercile.
.envelope_z <- function(ratio, season, start_flow, min_group) {
  n <- length(ratio)
  group <- rep("all", n)
  if (!is.null(season)) group <- paste(group, season)
  if (!is.null(start_flow) && sum(is.finite(start_flow)) >= 3L) {
    cuts <- stats::quantile(start_flow, c(1, 2) / 3, na.rm = TRUE, names = FALSE)
    tercile <- 1L + (start_flow > cuts[1]) + (start_flow > cuts[2])
    group <- paste(group, tercile)
  }
  z <- rep(NA_real_, n)
  for (g in unique(group)) {
    k <- which(group == g & is.finite(ratio))
    if (length(k) < min_group) next
    s <- stats::mad(ratio[k])
    if (s > 0) z[k] <- (ratio[k] - stats::median(ratio[k])) / s
  }
  z
}
