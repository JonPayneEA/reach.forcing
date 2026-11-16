# Each event is one step of rain at a known total, so every sum, spread, ratio and weight below
# follows by hand.

# Builds a rain matrix and event table from per-event totals of two sources and a quick flow.
make <- function(op, h19, quick, gap = 4L) {
  n <- length(op) * gap
  rain <- cbind(operational = rep(0, n), h19 = rep(0, n))
  rows <- seq(1L, by = gap, length.out = length(op))
  rain[rows, "operational"] <- op
  rain[rows, "h19"] <- h19
  events <- data.frame(event = seq_along(op), rain_start = rows, rain_end = rows,
                       flow_start = rows, flow_end = rows + gap - 1L, quickflow_mm = quick)
  list(rain = rain, events = events)
}

test_that("sources that agree give full weight; a wide spread the floor", {
  d <- make(op = c(10, 20, 10), h19 = c(11, 12, 7), quick = c(4, 5, 3))
  out <- event_uncertainty(d$events, d$rain)
  expect_equal(out$rain_mm, c(10, 20, 10))
  expect_equal(out$spread, c(1 / 10.5, 8 / 16, 3 / 8.5))
  expect_equal(out$weight[1], 1)
  expect_equal(out$use[1], "full")
  expect_equal(out$weight[2], 0.2)          # spread 0.5: the floor
  expect_equal(out$weight[3], 1 - 0.8 * (3 / 8.5 - 0.1) / 0.4)
  expect_equal(out$use[2:3], c("weight", "weight"))
  expect_equal(out$runoff_ratio, c(0.4, 0.25, 0.3))
})

test_that("quick flow above the highest plausible rain excludes the event", {
  d <- make(op = c(10, 10), h19 = c(9, 10), quick = c(12, 9))
  out <- event_uncertainty(d$events, d$rain)
  expect_equal(out$ratio_low, c(12 / 10, 9 / 10))
  expect_equal(out$use, c("exclude", "full"))
  expect_equal(out$weight, c(0, 1))
  expect_match(out$reason[1], "1.20 of the highest plausible rain")
})

test_that("ensemble members set the plausible range", {
  d <- make(op = c(10, 20), h19 = c(10, 20), quick = c(4, 23))
  # 21 members at 0.80 to 1.20 times the operational rain: 5 and 95 per cent at 0.82 and 1.18
  members <- d$rain[, "operational"] %o% seq(0.8, 1.2, length.out = 21)
  out <- event_uncertainty(d$events, d$rain, members = members)
  expect_equal(out$ens_low, c(8.2, 16.4))
  expect_equal(out$ens_high, c(11.8, 23.6))
  expect_equal(out$ratio_low, c(4 / 11.8, 23 / 23.6))
  expect_equal(out$ratio_high, c(4 / 8.2, 23 / 16.4))
  expect_equal(out$use, c("full", "full"))   # 23 mm is below the highest member's 23.6 mm
})

test_that("a runoff ratio unusual for its group is sent for review, keeping its weight", {
  d <- make(op = rep(10, 6), h19 = rep(10, 6), quick = c(4, 4.1, 3.9, 4, 4.2, 9))
  out <- event_uncertainty(d$events, d$rain, season = rep("winter", 6))
  # median 0.405, mad 0.01 * 1.4826
  expect_equal(out$envelope_z[6], (0.9 - 0.405) / (0.01 * 1.4826))
  expect_equal(out$use, c(rep("full", 5), "review"))
  expect_equal(out$weight[6], 1)
  expect_match(out$reason[6], "unusual for season")
  small <- event_uncertainty(d$events[1:4, ], d$rain, season = rep("winter", 4))
  expect_true(all(is.na(small$envelope_z)))
})

test_that("a peak far from the response time is sent for review", {
  d <- make(op = c(10, 10), h19 = c(10, 10), quick = c(4, 4), gap = 20L)
  d$events$peak_row <- d$events$rain_start + c(5L, 10L)
  out <- event_uncertainty(d$events, d$rain, response_steps = 5)
  expect_equal(out$lag_steps, c(5, 10))
  expect_equal(out$use, c("full", "review"))
  expect_match(out$reason[2], "timing")
})

test_that("a source missing more than max_missing of the window does not count", {
  d <- make(op = c(10, 10), h19 = c(NA, 5), quick = c(4, 4))
  out <- event_uncertainty(d$events, d$rain)
  expect_true(is.na(out$spread[1]))         # one source left: nothing to discount
  expect_equal(out$weight[1], 1)
  expect_equal(out$spread[2], 5 / 7.5)
})

test_that("bad inputs are refused", {
  d <- make(op = 10, h19 = 10, quick = 4)
  expect_error(event_uncertainty(d$events[, -6], d$rain), "quickflow_mm")
  colnames(d$rain) <- c("a", "b")
  expect_error(event_uncertainty(d$events, d$rain), "operational")
})
