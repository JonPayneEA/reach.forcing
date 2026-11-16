# Each expected value is worked by hand from the operational rule:
# rain = (sum(w_g * g) + w_h * h) / (sum(w_g) + w_h) over the inputs that report,
# H19 alone below the threshold.

w2 <- c(A = 0.6, B = 0.4)

test_that("a full network is the weighted mean, with H19 at its standing weight", {
  out <- operational_rain(cbind(A = 1, B = 3), w2, h19 = 2, temperature = 10)
  expect_equal(out$rain_mm, (0.6 * 1 + 0.4 * 3 + 0.01 * 2) / 1.01)
  expect_equal(out$source, "blend")
  expect_equal(out$gauges_reporting, 2L)
  expect_equal(out$weight_present, 1)
})

test_that("a failed gauge's weight is spread over the others in proportion to theirs", {
  w3 <- c(A = 0.5, B = 0.3, C = 0.2)
  out <- operational_rain(cbind(A = 1, B = 3, C = NA), w3)
  # C's 0.2 goes 5/8 to A and 3/8 to B: (0.5 * 1 + 0.3 * 3) / 0.8
  expect_equal(out$rain_mm, 1.75)
  expect_equal(out$weight_present, 0.8)
  expect_equal(out$gauges_reporting, 2L)
  # with H19 beside them
  out <- operational_rain(cbind(A = 2, B = NA), w2, h19 = 2)
  expect_equal(out$rain_mm, (0.6 * 2 + 0.01 * 2) / 0.61)
})

test_that("H19 carries the catchment when every gauge fails", {
  out <- operational_rain(cbind(A = NA_real_, B = NA_real_), w2, h19 = 5)
  expect_equal(out$rain_mm, 5)
  expect_equal(out$source, "h19_fallback")
  expect_equal(out$weight_present, 0)
})

test_that("below the threshold the catchment takes H19 alone", {
  out <- operational_rain(cbind(A = c(1, 1), B = c(3, 3)), w2, h19 = c(7, 7),
                          temperature = c(3.9, 4))
  expect_equal(out$rain_mm, c(7, (0.6 + 1.2 + 0.07) / 1.01))
  expect_equal(out$source, c("h19_cold", "blend"))
})

test_that("a cold step without H19 follows cold_fallback", {
  rain <- cbind(A = 1, B = 3)
  out <- operational_rain(rain, w2, h19 = NA_real_, temperature = 0)
  expect_equal(out$rain_mm, 0.6 * 1 + 0.4 * 3)
  expect_equal(out$source, "cold_gauges")
  out <- operational_rain(rain, w2, h19 = NA_real_, temperature = 0, cold_fallback = "missing")
  expect_true(is.na(out$rain_mm))
  expect_equal(out$source, "missing")
})

test_that("missing temperature counts as warm and no input at all is missing", {
  out <- operational_rain(cbind(A = c(1, NA), B = c(3, NA)), w2, h19 = c(9, NA),
                          temperature = c(NA, NA))
  expect_equal(out$rain_mm[1], (0.6 + 1.2 + 0.09) / 1.01)
  expect_true(is.na(out$rain_mm[2]))
  expect_equal(out$source, c("blend", "missing"))
})

test_that("weights need not sum to one, and extra columns are ignored", {
  out <- operational_rain(cbind(A = 1, B = 3, Z = 100), c(A = 3, B = 2))
  expect_equal(out$rain_mm, (3 * 1 + 2 * 3) / 5)
})

test_that("bad inputs are refused", {
  rain <- cbind(A = 1, B = 3)
  expect_error(operational_rain(rain, c(A = 1, C = 1)), "no column for: C")
  expect_error(operational_rain(rain, c(A = -1, B = 1)), "nonnegative")
  expect_error(operational_rain(unname(rain), w2), "named column")
  expect_error(operational_rain(rain, w2, h19 = c(1, 2)), "one value per row")
  expect_error(operational_rain(cbind(A = -1, B = 3), w2), "nonnegative")
})
