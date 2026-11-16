# Expected values follow from constructed series: an exact factor, an exact trend in the log
# ratio, an exact step, and Pettitt's statistic K = t (n - t) for a clean step.

year <- rep(2001:2015, each = 12)
month <- rep(c(10:12, 1:9), 15)
ref <- 50 + 10 * sin(seq_along(year))   # positive, varied
check_of <- function(out, name) out[out$check == name, ]

test_that("an exact factor gives that typical ratio, a flat interval and no trend", {
  out <- ratio_checks(ref * 0.88, ref, year, month, seed = 1)
  t <- check_of(out, "typical_ratio")
  expect_equal(t$value, 0.88)
  expect_equal(c(t$lower, t$upper), c(0.88, 0.88))
  expect_equal(t$flag, "low")
  expect_equal(t$n, 180L)
  expect_equal(check_of(out, "spread")$value, 0)
  expect_equal(check_of(out, "winter_summer")$value, 1)
  expect_equal(check_of(out, "trend")$value, 0)
  expect_equal(check_of(out, "trend")$flag, "ok")
  expect_equal(check_of(out, "change_point")$flag, "ok")
})

test_that("a steady drift in the ratio is the trend, per cent a decade", {
  gauge <- ref * exp(0.01 * (year - 2001))
  tr <- check_of(ratio_checks(gauge, ref, year, month, seed = 1), "trend")
  expect_equal(tr$value, (exp(0.1) - 1) * 100)
  expect_equal(tr$flag, "flagged")
  expect_equal(tr$n, 15L)
})

test_that("a step in the ratio is found, sized and dated", {
  gauge <- ref * ifelse(year >= 2009, 0.9, 1)
  cp <- check_of(ratio_checks(gauge, ref, year, month, seed = 1), "change_point")
  expect_equal(cp$at, 2009L)
  expect_equal(cp$value, -10)
  expect_equal(cp$flag, "flagged")   # K = 8 * 7, p = 2 exp(-6 * 56^2 / (15^3 + 15^2)) = 0.011
})

test_that("Pettitt's statistic matches its closed form for a clean step", {
  p <- reach.forcing:::.pettitt(c(rep(0, 10), rep(1, 10)))
  expect_equal(p$index, 10L)
  expect_equal(p$k, 100)
  expect_equal(p$p, 2 * exp(-6 * 100^2 / (20^3 + 20^2)))
})

test_that("winter under-catch shows in the winter to summer ratio", {
  gauge <- ref * ifelse(month %in% c(12, 1, 2), 0.8, 1)
  ws <- check_of(ratio_checks(gauge, ref, year, month, seed = 1), "winter_summer")
  expect_equal(ws$value, 0.8)
  expect_equal(ws$flag, "low")
})

test_that("short records are reported without a flag, and missing months are left out", {
  k <- 1:12
  out <- ratio_checks(ref[k] * 0.5, ref[k], year[k], month[k], seed = 1)
  expect_equal(check_of(out, "typical_ratio")$value, 0.5)
  expect_equal(check_of(out, "typical_ratio")$flag, "too_few")
  expect_equal(check_of(out, "trend")$flag, "too_few")
  gauge <- ref
  gauge[1:3] <- NA
  expect_equal(check_of(ratio_checks(gauge, ref, year, month, seed = 1), "typical_ratio")$n, 177L)
})

test_that("a seed gives a repeatable interval and leaves the caller's random state alone", {
  gauge <- ref * exp(rep(seq(-0.1, 0.1, length.out = 15), each = 12))
  a <- ratio_checks(gauge, ref, year, month, seed = 7)
  b <- ratio_checks(gauge, ref, year, month, seed = 7)
  expect_equal(a, b)
  set.seed(42)
  x <- stats::runif(1)
  set.seed(42)
  invisible(ratio_checks(gauge, ref, year, month, seed = 7))
  expect_equal(stats::runif(1), x)
})

test_that("bad inputs are refused", {
  expect_error(ratio_checks(1:3, 1:2, 1:3), "same length")
  expect_error(ratio_checks(1:3, 1:3, 1:3, month = c(1, 2, 13)), "1 to 12")
  expect_error(ratio_checks(1:3, 1:3, 1:3, limits = c(2, 1)), "increasing")
})
