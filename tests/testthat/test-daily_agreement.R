# Forty days, alternating wet (neighbours 10 mm) and dry (0 mm). The gauge matches except on
# three days set below, so every count and rate follows by hand.

nb <- rep(c(10, 0), 20)
month <- rep(c("2015-01", "2015-02"), each = 20)
gauge <- nb
gauge[c(1, 3)] <- 0    # two wet days recorded dry, both in January
gauge[22] <- 8         # one dry day recorded wet, in February
row_of <- function(out, name) out[out$check == name, ]

test_that("hit and false-alarm rates count wet days", {
  out <- daily_agreement(gauge, nb, month = month, min_days = 10)
  expect_equal(row_of(out, "hit_rate")$value, 18 / 20)
  expect_equal(row_of(out, "hit_rate")$flag, "ok")
  expect_equal(row_of(out, "false_alarm")$value, 1 / 19)
  expect_equal(row_of(out, "false_alarm")$n, 19L)
})

test_that("dry-while-wet and wet-while-dry days are counted and dated by month", {
  out <- daily_agreement(gauge, nb, month = month, per_month = 1, min_days = 10)
  expect_equal(row_of(out, "dry_while_wet")$value, 2)
  expect_equal(row_of(out, "dry_while_wet")$flag, "flagged")
  expect_equal(row_of(out, "dry_while_wet")$months, "2015-01")
  expect_equal(row_of(out, "wet_while_dry")$value, 1)
  expect_equal(row_of(out, "wet_while_dry")$flag, "ok")   # one day is not more than one
  out <- daily_agreement(gauge, nb, month = month, min_days = 10)
  expect_equal(row_of(out, "dry_while_wet")$flag, "ok")   # two is not more than two
})

test_that("H19 must agree before a day counts as dry while wet", {
  h19 <- nb
  h19[1] <- 0     # H19 also dry on day 1: not a blocked gauge
  out <- daily_agreement(gauge, nb, h19 = h19, month = month, min_days = 10)
  expect_equal(row_of(out, "dry_while_wet")$value, 1)
})

test_that("bias is the median ratio in each band of daily total", {
  out <- daily_agreement(gauge, nb, month = month, bands = c(1, 5, 15), min_days = 10)
  b <- row_of(out, "bias_5_to_15")
  expect_equal(b$value, 1)       # 18 days at 1, 2 at 0
  expect_equal(b$n, 20L)
  expect_equal(row_of(out, "bias_1_to_5")$flag, "too_few")
})

test_that("missing days are left out, and bad inputs refused", {
  g <- gauge
  g[2] <- NA
  out <- daily_agreement(g, nb, month = month, min_days = 10)
  expect_equal(row_of(out, "false_alarm")$n, 19L)
  expect_error(daily_agreement(1:3, 1:2, month = 1:3), "same length")
  expect_error(daily_agreement(1:3, 1:3, month = 1:2), "one value per day")
})
