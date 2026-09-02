#' Base R Biplot Processor
#'
#' Reads `biplot()` as the two things it draws: the observations in principal
#' component space, and the variables' loadings on the same components.
#'
#' **It is a grid, and for a reason the other grids do not have.** `pairs()`,
#' `lag.plot()` and `termplot()` are read as grids because they draw several
#' panels. A biplot draws its two halves *on top of each other* -- but on
#' **two different pairs of axes**, which is the whole trick of the chart.
#' Measured, the two `plot.xy` calls run over different ranges, and the
#' quantities behind them are different sizes again:
#'
#'     scores   PC1 range  -1.716 ..  2.199
#'     loadings PC1 range  -0.962 .. -0.012
#'
#' Announcing both against one axis pair would misstate every loading. So the
#' two are given a cell each -- one row, two columns -- which is the only way
#' the existing grammar can say "these have separate scales" without
#' inventing a second axis on one layer.
#'
#' **It draws no points at all.** Both `plot.xy` calls are `type = "n"`;
#' every mark on the page is a *label* or an *arrow*. Measured on the export
#' of a ten-observation, four-variable fit:
#'
#'     graphics-plot-1-text-1     10 children   the observations
#'     graphics-plot-2-text-1      4 children   the variables
#'     graphics-plot-2-arrows-1    4 children   the arrows
#'
#' Both text grobs are addressable per datum, in data order, which is the
#' shape `lag.plot()`'s labelled panels already established -- one `g` per
#' label rather than one `use` per symbol. The arrows are not emitted
#' separately: an arrow and its label name the same variable and sit at the
#' same place, so the label is the mark a reader is moved to.
#'
#' **The values are the caller's, not the drawing's.** `biplot()` apportions
#' the two halves between the axes so that both fit one page -- it divides
#' the scores by `sdev * sqrt(n)` and multiplies the loadings by it, so
#' *neither* set is drawn at its own scale. What a reader wants is the pair
#' that mean something: the **scores**, an observation's coordinate in
#' component space, and the **loadings**, a variable's weight on each
#' component. Those are announced. This is the same choice `stars()` makes,
#' where the radii on the page are shares of a column's range and the reading
#' hands over the readings instead.
#'
#' @keywords internal
BaseRBiplotLayerProcessor <- R6::R6Class(
  "BaseRBiplotLayerProcessor",
  inherit = BaseRPointLayerProcessor,
  public = list(
    #' @description Emit the observations and the variables, a cell each
    #' @param plot Unused; present for the processor interface.
    #' @param layout Unused; present for the processor interface.
    #' @param built Unused; present for the processor interface.
    #' @param gt Unused; the selectors are built rather than searched for.
    #' @param grob_id Unused; present for the processor interface.
    #' @param panel_id Unused; present for the processor interface.
    #' @param panel_ctx Unused; present for the processor interface.
    #' @param layer_info Layer information with the recorded call.
    #' @return A multi-panel result, or NULL when nothing was read
    process = function(plot,
                       layout,
                       built = NULL,
                       gt = NULL,
                       grob_id = NULL,
                       panel_id = NULL,
                       panel_ctx = NULL,
                       layer_info = NULL) {
      info <- if (!is.null(layer_info)) layer_info else self$layer_info
      halves <- private$halves(info)
      if (is.null(halves)) {
        return(NULL)
      }

      title <- self$extract_main_title(info)
      panels <- list()
      for (index in seq_along(halves)) {
        half <- halves[[index]]
        panels[[length(panels) + 1]] <- list(
          row = 1,
          col = index,
          layers = list(private$panel_layer(half, index, title))
        )
      }

      list(
        multi_panel = TRUE,
        nrows = 1,
        ncols = length(panels),
        panels = panels
      )
    }
  ),
  private = list(
    # One half's points, axes and selector.
    panel_layer = function(half, panel, title) {
      list(
        data = lapply(
          seq_along(half$names),
          function(i) {
            list(x = half$x[[i]], y = half$y[[i]], label = half$names[[i]])
          }
        ),
        # The labels, one `g` per datum in data order. `text-1` on both
        # panels; the arrows beside the variables name the same things and
        # are left to the labels.
        selectors = list(
          paste0("g#graphics-plot-", panel, "-text-1\\.1 > g")
        ),
        type = "point",
        title = title,
        axes = build_axes(x = half$x_label, y = half$y_label)
      )
    },
    # The observations and the variables, in the order they are drawn.
    halves = function(layer_info) {
      fit <- private$fit(layer_info)
      if (is.null(fit)) {
        return(NULL)
      }

      scores <- private$pair(fit$scores)
      loadings <- private$pair(fit$loadings)
      if (is.null(scores) || is.null(loadings)) {
        return(NULL)
      }

      list(
        list(
          x = scores$x, y = scores$y, names = scores$names,
          x_label = scores$x_label, y_label = scores$y_label
        ),
        list(
          x = loadings$x, y = loadings$y, names = loadings$names,
          x_label = loadings$x_label, y_label = loadings$y_label
        )
      )
    },
    # The first two columns of a matrix, with the names down its side.
    #
    # `biplot()` draws `choices = 1:2` by default, and a component beyond the
    # second is not on the page.
    pair = function(matrix_form) {
      if (is.null(matrix_form) || !is.matrix(matrix_form)) {
        return(NULL)
      }
      if (nrow(matrix_form) < 1 || ncol(matrix_form) < 2) {
        return(NULL)
      }
      if (!is.numeric(matrix_form)) {
        return(NULL)
      }

      columns <- colnames(matrix_form)
      rows <- rownames(matrix_form)
      list(
        x = as.numeric(matrix_form[, 1]),
        y = as.numeric(matrix_form[, 2]),
        names = if (!is.null(rows) && length(rows) == nrow(matrix_form)) {
          as.character(rows)
        } else {
          as.character(seq_len(nrow(matrix_form)))
        },
        x_label = private$component(columns, 1),
        y_label = private$component(columns, 2)
      )
    },
    component = function(columns, at) {
      if (!is.null(columns) && length(columns) >= at && nzchar(columns[[at]])) {
        return(columns[[at]])
      }
      paste0("PC", at)
    },
    # The scores and loadings the call was handed.
    #
    # `biplot()` is generic. `biplot.prcomp` reads `x` and `rotation`;
    # `biplot.princomp` reads `scores` and `loadings`. A call whose first
    # argument is neither is declined rather than guessed at -- the arguments
    # of a call that stopped are recorded all the same.
    fit = function(layer_info) {
      if (is.null(layer_info) || is.null(layer_info$plot_call)) {
        return(NULL)
      }
      args <- layer_info$plot_call$args
      if (!length(args)) {
        return(NULL)
      }
      handed <- args[[1]]
      if (is.null(handed) || is.language(handed)) {
        return(NULL)
      }

      scores <- private$field(handed, c("x", "scores"))
      loadings <- private$field(handed, c("rotation", "loadings"))
      if (is.null(scores) || is.null(loadings)) {
        return(NULL)
      }
      list(scores = scores, loadings = loadings)
    },
    # The first of `names` the object carries as a matrix.
    #
    # `princomp` returns its loadings with class "loadings", which is a
    # matrix wearing a print method, so `as.matrix` rather than a class test.
    field = function(handed, names) {
      for (name in names) {
        value <- tryCatch(handed[[name]], error = function(e) NULL)
        if (is.null(value)) {
          next
        }
        matrix_form <- tryCatch(as.matrix(value), error = function(e) NULL)
        if (!is.null(matrix_form) && is.numeric(matrix_form)) {
          return(matrix_form)
        }
      }
      NULL
    }
  )
)
