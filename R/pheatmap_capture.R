#' Draw a clustered heat map with pheatmap, keeping its values for maidr
#'
#' A wrapper of `pheatmap::pheatmap()` that `library(maidr)` puts on the
#' search path. It calls the original with every argument unchanged, draws
#' exactly what it draws and returns what it returns, with one addition: the
#' matrix the chart was drawn from, kept with the result so that [show()]
#' and [save_html()] announce each cell's exact value.
#'
#' `pheatmap::pheatmap()` returns its trees and its drawing but not its
#' matrix. Without this wrapper -- a chart drawn by a call to
#' `pheatmap::pheatmap()` by name, before maidr was loaded, or with
#' 'pheatmap' attached after maidr, which then masks this function -- maidr
#' can only read each cell back from its colour, to within one band of the
#' legend, and says so.
#'
#' The matrix kept is the one drawn: the input after `scale = "row"` or
#' `"column"`, computed as pheatmap computes it; the k-means centres with
#' `kmeans_k`; in the order of the row and column trees.
#'
#' @section Attach order:
#' Attach 'pheatmap' *before* maidr, or call `maidr::pheatmap()`:
#'
#' ```r
#' library(pheatmap)
#' library(maidr)
#' ```
#'
#' @param mat The numeric matrix to draw, as `pheatmap::pheatmap()` takes it
#' @param ... Every other argument of `pheatmap::pheatmap()`, passed on
#'   unchanged
#' @return What `pheatmap::pheatmap()` returns, invisibly, with the drawn
#'   matrix as its `"maidr_matrix"` attribute
#' @seealso [show()] and [save_html()], which read the result.
#' @examples
#' if (requireNamespace("pheatmap", quietly = TRUE)) {
#'   m <- matrix(rnorm(20), 4, 5, dimnames = list(letters[1:4], LETTERS[1:5]))
#'   p <- maidr::pheatmap(m, silent = TRUE)
#'   maidr::save_html(p, file = tempfile(fileext = ".html"))
#' }
#' @export
pheatmap <- function(mat, ...) {
  if (!requireNamespace("pheatmap", quietly = TRUE)) {
    stop(
      "Package 'pheatmap' is required for pheatmap(). ",
      "Please install it via install.packages('pheatmap').",
      call. = FALSE
    )
  }
  original <- getExportedValue("pheatmap", "pheatmap")
  result <- original(mat, ...)

  drawn <- tryCatch(
    {
      matched <- as.list(match.call(original, as.call(c(list(quote(f)), list(mat), list(...)))))
      pheatmap_drawn_matrix(mat, matched$scale %||% "none", result)
    },
    error = function(e) NULL
  )
  if (!is.null(drawn)) {
    attr(result, "maidr_matrix") <- drawn
  }
  invisible(result)
}

#' pheatmap's row scaling, exactly as `pheatmap:::scale_rows()` computes it
#' @param x A numeric matrix
#' @return Each row less its mean, over its standard deviation
#' @keywords internal
pheatmap_scale_rows <- function(x) {
  m <- apply(x, 1, mean, na.rm = TRUE)
  s <- apply(x, 1, stats::sd, na.rm = TRUE)
  (x - m) / s
}

#' The matrix a pheatmap drew, from its input and the object it returned
#'
#' The steps `pheatmap::pheatmap()` takes before colouring, in its order:
#' scaling (`scale_mat()`), the k-means centres in place of the rows when
#' `kmeans_k` is set (kept in the result's `kmeans`), then the rows and
#' columns put in the order of their trees. A value that is not finite --
#' a missing one, or a constant row scaled to `NaN` -- is drawn in `na_col`,
#' and kept as `NA`.
#'
#' @param mat The matrix the caller passed
#' @param scale The `scale` argument: `"none"`, `"row"` or `"column"`
#' @param result The object `pheatmap::pheatmap()` returned
#' @return A numeric matrix, rows top first
#' @keywords internal
pheatmap_drawn_matrix <- function(mat, scale, result) {
  x <- as.matrix(mat)
  x <- switch(scale,
    none = x,
    row = pheatmap_scale_rows(x),
    column = t(pheatmap_scale_rows(t(x))),
    stop("unknown scale")
  )
  if (inherits(result$kmeans, "kmeans")) {
    x <- result$kmeans$centers
  }
  if (inherits(result$tree_row, "hclust")) {
    x <- x[result$tree_row$order, , drop = FALSE]
  }
  if (inherits(result$tree_col, "hclust")) {
    x <- x[, result$tree_col$order, drop = FALSE]
  }
  storage.mode(x) <- "double"
  x[!is.finite(x)] <- NA_real_
  x
}

#' Say, as pheatmap is attached, that it now masks maidr's pheatmap()
#'
#' The attach hook for 'pheatmap'. Attached after maidr, a bare
#' `pheatmap()` reaches pheatmap's own function, and maidr can read its
#' values only from the colours.
#'
#' @param ... Unused; what the hook is called with
#' @return NULL (invisible)
#' @keywords internal
.maidr_pheatmap_attach_hook <- function(...) {
  tryCatch(
    if (package_masks_maidr("pheatmap") && isTRUE(getOption("maidr.startup_message", TRUE))) {
      packageStartupMessage("maidr: ", pheatmap_mask_advice())
    },
    error = function(e) NULL
  )
  invisible(NULL)
}

#' Advice when a pheatmap's values could not be kept
#' @return A single advice string
#' @keywords internal
pheatmap_mask_advice <- function() {
  paste0(
    "'pheatmap' is attached ahead of 'maidr' on the search path, so a bare ",
    "pheatmap() call goes straight to pheatmap, and maidr can read its ",
    "values only approximately, from the colours. Attach 'pheatmap' before ",
    "'maidr', or call maidr::pheatmap() explicitly."
  )
}
