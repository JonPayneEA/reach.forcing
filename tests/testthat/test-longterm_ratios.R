# Expected values follow from c = mean(HadUK) / baseline, m = baseline / SAAR and
# b = mean(gauge) / (SAAR * c), over the years both records cover.

years <- as.character(2001:2015)

test_that("the three ratios follow their definitions", {
  gauge <- setNames(rep(900, 15), years)
  haduk <- setNames(rep(1050, 15), years)
  r <- longterm_ratios(gauge, haduk, haduk_baseline = 1000, saar = 980)
  expect_equal(r$years, 15L)
  expect_equal(r$c, 1.05)
  expect_equal(r$m, 1000 / 980)
  expect_equal(r$b, 900 / (980 * 1.05))
  expect_equal(r$b_flag, "low")
  expect_equal(r$m_flag, "ok")
})

test_that("only the years both records cover are used", {
  gauge <- setNames(c(rep(1000, 12), NA, NA, NA), years)
  haduk <- setNames(c(rep(1000, 10), NA, rep(1000, 4)), years)
  r <- longterm_ratios(gauge, haduk, haduk_baseline = 1000, saar = 1000)
  expect_equal(r$years, 11L)
  expect_equal(r$b, 1)
  expect_equal(r$b_flag, "ok")
})

test_that("short records are reported but not flagged", {
  gauge <- setNames(rep(500, 5), years[1:5])
  haduk <- setNames(rep(1000, 5), years[1:5])
  r <- longterm_ratios(gauge, haduk, haduk_baseline = 1000, saar = 1000)
  expect_equal(r$b, 0.5)
  expect_equal(r$b_flag, "too_few_years")
  none <- longterm_ratios(setNames(NA_real_, "2001"), haduk, 1000, 1000)
  expect_equal(none$years, 0L)
  expect_true(is.na(none$b))
})

test_that("the method ratio flags HadUK and SAAR disagreeing", {
  gauge <- setNames(rep(1000, 15), years)
  r <- longterm_ratios(gauge, gauge, haduk_baseline = 1100, saar = 1000)
  expect_equal(r$m_flag, "high")
})

test_that("bad inputs are refused", {
  expect_error(longterm_ratios(c(1, 2), c(a = 1), 1, 1), "named by water year")
  expect_error(longterm_ratios(c(a = 1), c(a = 1), 0, 1), "positive")
  expect_error(longterm_ratios(c(a = 1), c(a = 1), 1, 1, b_limits = c(2, 1)), "increasing")
})
