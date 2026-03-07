#' Ramer-Douglas-Peucker Curve Simplification Utilities
#'
#' These helpers reduce the number of points on a curve while preserving its
#' shape.  Used by the violin KDE processor to keep the maidr JSON payload
#' compact (~30 points per violin instead of 500+).
#'
#' Ported from py-maidr (`maidr/util/rdp_utils.py`).
#'
#' @keywords internal
NULL

#' Perpendicular distance from points to a line segment
#'
#' @param points Nx2 numeric matrix of (x, y) points
#' @param start Numeric vector of length 2 (line start)
#' @param end Numeric vector of length 2 (line end)
#' @return Numeric vector of perpendicular distances
#' @keywords internal
perpendicular_distance <- function(points, start, end) {
  line_vec <- end - start
  line_len <- sqrt(sum(line_vec^2))
  if (line_len == 0) {
    return(sqrt(rowSums((points - matrix(start, nrow = nrow(points),
      ncol = 2, byrow = TRUE
    ))^2)))
  }
  line_unit <- line_vec / line_len
  diff_mat <- points - matrix(start, nrow = nrow(points),
    ncol = 2, byrow = TRUE
  )
  # Cross product magnitude (2D): |dx * uy - dy * ux|
  abs(diff_mat[, 1] * line_unit[2] - diff_mat[, 2] * line_unit[1])
}

#' Ramer-Douglas-Peucker algorithm for 2D polylines
#'
#' Iterative stack-based implementation to avoid R recursion limits.
#'
#' @param points Nx2 numeric matrix of ordered (x, y) points
#' @param epsilon Maximum allowed perpendicular distance. Larger values
#'   yield fewer retained points.
#' @return Logical vector of length N (TRUE = keep this point)
#' @keywords internal
rdp <- function(points, epsilon) {
  n <- nrow(points)
  if (n <= 2) {
    return(rep(TRUE, n))
  }

  mask <- rep(FALSE, n)
  mask[1] <- TRUE
  mask[n] <- TRUE

  # Stack-based iteration: each entry is c(lo, hi)
  stack <- list(c(1L, n))

  while (length(stack) > 0) {
    pair <- stack[[length(stack)]]
    stack[[length(stack)]] <- NULL
    lo <- pair[1]
    hi <- pair[2]

    if (hi - lo <= 1L) next

    segment <- points[(lo + 1L):(hi - 1L), , drop = FALSE]
    dists <- perpendicular_distance(segment, points[lo, ], points[hi, ])
    max_idx <- which.max(dists)
    idx <- max_idx + lo # absolute index in `points`

    if (dists[max_idx] > epsilon) {
      mask[idx] <- TRUE
      stack[[length(stack) + 1L]] <- c(lo, idx)
      stack[[length(stack) + 1L]] <- c(idx, hi)
    }
  }

  mask
}

#' Adaptively simplify a 2D curve to a target number of points
#'
#' Uses binary search on epsilon to find the smallest tolerance that
#' yields at most `target` retained points.
#'
#' @param points Nx2 numeric matrix of ordered (x, y) points
#' @param target Desired maximum number of retained points
#' @param min_epsilon Lower bound for epsilon search (default 0)
#' @param max_iterations Maximum binary-search iterations (default 50)
#' @return Logical vector of length N (TRUE = keep this point)
#' @keywords internal
simplify_curve <- function(points, target, min_epsilon = 0,
                           max_iterations = 50L) {
  n <- nrow(points)
  if (n <= target) {
    return(rep(TRUE, n))
  }

  # Estimate reasonable upper bound from data extent
  x_range <- diff(range(points[, 1]))
  y_range <- diff(range(points[, 2]))
  eps_hi <- max(sqrt(x_range^2 + y_range^2), 1e-10)
  eps_lo <- min_epsilon
  best_mask <- rdp(points, eps_hi)

  for (i in seq_len(max_iterations)) {
    eps_mid <- (eps_lo + eps_hi) / 2
    mask <- rdp(points, eps_mid)
    count <- sum(mask)

    if (count <= target) {
      best_mask <- mask
      eps_hi <- eps_mid
    } else {
      eps_lo <- eps_mid
    }

    if (eps_hi - eps_lo < 1e-12) break
  }

  best_mask
}
