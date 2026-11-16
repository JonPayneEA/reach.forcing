# A deterministic storm pattern repeating every ten hours: shifted copies give known lags, and
# fixed ratios by temperature give known medians.

pattern <- rep(c(0, 0, 5, 1, 0, 0, 0, 3, 0, 0), 30)

test_that("a gauge two hours late has a lag of two", {
  late <- c(0, 0, head(pattern, -2))
  out <- timing_offset(late, pattern, max_lag = 4, min_pairs = 20)
  expect_equal(out$lag, 2L)
  expect_equal(out$correlation, 1)
  early <- c(tail(pattern, -1), 0)
  expect_equal(timing_offset(early, pattern, max_lag = 4, min_pairs = 20)$lag, -1L)
  expect_equal(timing_offset(pattern, pattern, max_lag = 4, min_pairs = 20)$lag, 0L)
})

test_that("too few wet hours give no lag", {
  out <- timing_offset(pattern[1:20], pattern[1:20], max_lag = 2, min_pairs = 50)
  expect_true(is.na(out$lag))
})

test_that("temperature bands give the median ratio in each band", {
  temperature <- c(rep(-1, 150), rep(1, 150), rep(5, 150), rep(9, 50))
  h19 <- rep(1, 500)
  gauge <- c(rep(0.6, 150), rep(0.8, 150), rep(1, 150), rep(1, 50))
  out <- temperature_bands(gauge, h19, temperature, breaks = c(-Inf, 0, 2, 6, Inf),
                           min_hours = 100)
  expect_equal(out$ratio, c(0.6, 0.8, 1, NA))
  expect_equal(out$hours, c(150L, 150L, 150L, 50L))
})

test_that("hours below the wet threshold are left out", {
  temperature <- rep(5, 300)
  h19 <- c(rep(1, 200), rep(0.1, 100))
  gauge <- c(rep(1, 200), rep(5, 100))     # the dry hours would distort the ratio
  out <- temperature_bands(gauge, h19, temperature, breaks = c(-Inf, 4, Inf), min_hours = 100)
  expect_equal(out$ratio[2], 1)
  expect_equal(out$hours[2], 200L)
})

test_that("bad inputs are refused", {
  expect_error(timing_offset(1:3, 1:2), "same length")
  expect_error(temperature_bands(1:3, 1:3, 1:3, breaks = c(2, 1)), "increasing")
})
