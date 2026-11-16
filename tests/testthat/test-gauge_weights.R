# Each expected weight comes from where the perpendicular bisectors between gauges cut a
# square catchment of 10 km, 0 to 10,000 m on both axes.

square <- data.frame(x = c(0, 10000, 10000, 0), y = c(0, 0, 10000, 10000))

test_that("two gauges split the square at their bisector", {
  g <- data.frame(id = c("A", "B"), x = c(0, 4000), y = c(5000, 5000))
  w <- gauge_weights(g, square, cell = 50)
  # bisector at x = 2000
  expect_equal(as.numeric(w), c(0.2, 0.8), tolerance = 0.005)
  expect_equal(names(w), c("A", "B"))
  expect_equal(sum(w), 1)
  expect_equal(attr(w, "cell"), 50)
  expect_equal(attr(w, "points"), 200L * 200L)
})

test_that("four gauges at the quarter centres take a quarter each", {
  g <- data.frame(id = 1:4, x = c(2500, 7500, 2500, 7500), y = c(2500, 2500, 7500, 7500))
  expect_equal(as.numeric(gauge_weights(g, square, cell = 100)), rep(0.25, 4))
})

test_that("a gauge outside the catchment counts when it is nearest", {
  g <- data.frame(id = c("out", "in"), x = c(-2000, 4000), y = c(5000, 5000))
  # bisector at x = 1000
  expect_equal(as.numeric(gauge_weights(g, square, cell = 50)), c(0.1, 0.9), tolerance = 0.005)
  g <- data.frame(id = c("far", "in"), x = c(-6000, 4000), y = c(5000, 5000))
  # bisector at x = -1000, outside the square
  expect_equal(as.numeric(gauge_weights(g, square, cell = 50)), c(0, 1))
})

test_that("reporting redraws the polygons over the gauges named", {
  g <- data.frame(id = c("A", "B", "C"), x = c(2000, 5000, 8000), y = c(5000, 5000, 5000))
  w <- gauge_weights(g, square, cell = 50, reporting = c("A", "C"))
  # with B gone, A and C meet at x = 5000
  expect_equal(as.numeric(w), c(0.5, 0.5), tolerance = 0.005)
  expect_equal(names(w), c("A", "C"))
})

test_that("a triangle and a closed ring work", {
  tri <- data.frame(x = c(0, 10000, 0, 0), y = c(0, 0, 10000, 0))
  g <- data.frame(id = c("A", "B"), x = c(2500, 2500), y = c(2500, 7500))
  # bisector y = 5000 cuts the triangle into 3/4 and 1/4 of its area
  expect_equal(as.numeric(gauge_weights(g, tri, cell = 50)), c(0.75, 0.25), tolerance = 0.005)
})

test_that("bad inputs are refused", {
  g <- data.frame(id = c("A", "A"), x = c(0, 1), y = c(0, 1))
  expect_error(gauge_weights(g, square), "unique")
  expect_error(gauge_weights(data.frame(x = 1, y = 1), square), "id, x and y")
  g <- data.frame(id = "A", x = 1, y = 1)
  expect_error(gauge_weights(g, square, reporting = "Z"), "unknown gauges")
  expect_error(gauge_weights(g, square, cell = 0), "positive")
  expect_error(gauge_weights(g, square[1:2, ]), "three")
})
