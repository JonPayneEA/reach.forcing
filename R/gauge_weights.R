# ============================================================
# Tool:         gauge_weights
# Description:  Thiessen weights of rain gauges over a catchment, by sampling the catchment
#               on a regular grid and giving each sample to its nearest gauge
# Flode Module: reach.forcing
# Author:       reach.forcing contributors
# Created:      2026-11-16
# Tier:         1
# Inputs:       Gauge locations; a catchment boundary (one ring of vertices); a sample spacing
# Outputs:      A named vector of weights summing to one
# Dependencies: none
# ============================================================

#' Thiessen weights of gauges over a catchment
#'
#' Each gauge's weight is the share of the catchment closer to it than to any other gauge (its
#' Thiessen polygon, clipped to the catchment). The catchment is sampled on a square grid of
#' points `cell` apart; each point inside the boundary goes to its nearest gauge, and a gauge's
#' weight is its share of the points. Gauges outside the catchment count too, since the nearest
#' gauge to part of a catchment may lie beyond its edge.
#'
#' The sampling error falls with the spacing: a few tenths of a per cent of the catchment for a
#' spacing of a hundredth of its width. Use coordinates in metres on a projected grid (British
#' National Grid), so distances are true.
#'
#' Give `reporting` to get the weights over a subset of gauges, with the polygons redrawn over
#' those alone: the challenger to the operational rule, which scales the fixed weights up
#' instead.
#'
#' @param gauges Data frame with `id`, `x` and `y`, in metres.
#' @param boundary The catchment boundary: a data frame with `x` and `y`, or a two-column
#'   matrix, one ring of vertices (closed or not).
#' @param cell Sample spacing, m.
#' @param reporting Optional ids of the gauges to use; by default all.
#' @return A named numeric vector of weights, one per gauge used, summing to one, with
#'   attributes `points` (the number of sample points inside the catchment) and `cell`.
#' @examples
#' square <- data.frame(x = c(0, 10000, 10000, 0), y = c(0, 0, 10000, 10000))
#' gauges <- data.frame(id = c("A", "B"), x = c(0, 4000), y = c(5000, 5000))
#' gauge_weights(gauges, square, cell = 50)   # A 0.2, B 0.8
#' @export
gauge_weights <- function(gauges, boundary, cell = 100, reporting = NULL) {
  .check(is.data.frame(gauges) && all(c("id", "x", "y") %in% names(gauges)) &&
           nrow(gauges) >= 1L, "gauges must be a data frame with id, x and y")
  .check(all(is.finite(gauges$x)) && all(is.finite(gauges$y)),
         "gauge coordinates must be finite")
  .check(!anyDuplicated(gauges$id), "gauge ids must be unique")
  .check(.scalar(cell, 0, strict = TRUE), "cell must be one positive number, m")
  if (!is.null(reporting)) {
    unknown <- setdiff(reporting, gauges$id)
    .check(length(unknown) == 0L, paste("unknown gauges in reporting:",
                                        paste(unknown, collapse = ", ")))
    gauges <- gauges[gauges$id %in% reporting, , drop = FALSE]
    .check(nrow(gauges) >= 1L, "reporting must name at least one gauge")
  }
  ring <- .ring(boundary)
  xs <- seq(min(ring$x) + cell / 2, max(ring$x), by = cell)
  ys <- seq(min(ring$y) + cell / 2, max(ring$y), by = cell)
  px <- rep(xs, times = length(ys))
  py <- rep(ys, each = length(xs))
  inside <- .point_in_polygon(px, py, ring$x, ring$y)
  .check(any(inside), "no sample point falls inside the boundary; reduce cell")
  px <- px[inside]
  py <- py[inside]
  best <- rep(Inf, length(px))
  owner <- integer(length(px))
  for (k in seq_len(nrow(gauges))) {
    d2 <- (px - gauges$x[k])^2 + (py - gauges$y[k])^2
    closer <- d2 < best
    best[closer] <- d2[closer]
    owner[closer] <- k
  }
  w <- tabulate(owner, nbins = nrow(gauges)) / length(px)
  names(w) <- as.character(gauges$id)
  structure(w, points = length(px), cell = cell)
}

# A boundary as one ring of vertices, x and y.
.ring <- function(boundary) {
  if (is.data.frame(boundary) && all(c("x", "y") %in% names(boundary))) {
    ring <- list(x = boundary$x, y = boundary$y)
  } else {
    .check(is.matrix(boundary) && ncol(boundary) == 2L && is.numeric(boundary),
           "boundary must be a data frame with x and y, or a two-column matrix")
    ring <- list(x = boundary[, 1], y = boundary[, 2])
  }
  .check(length(ring$x) >= 3L && all(is.finite(ring$x)) && all(is.finite(ring$y)),
         "boundary needs at least three finite vertices")
  ring
}

# Ray casting: TRUE where a point lies inside the polygon.
.point_in_polygon <- function(x, y, px, py) {
  n <- length(px)
  inside <- logical(length(x))
  j <- n
  for (i in seq_len(n)) {
    crosses <- ((py[i] > y) != (py[j] > y)) &
      (x < (px[j] - px[i]) * (y - py[i]) / (py[j] - py[i]) + px[i])
    inside <- xor(inside, crosses)
    j <- i
  }
  inside
}
