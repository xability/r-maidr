#' Base R Term Plot Processor
#'
#' Reads `termplot()` as the partial-effect curves it draws: one panel per
#' term, the term's contribution to the fit plotted against its own carrier.
#'
#' **A grid, not a layer.** Like `pairs()` and `lag.plot()`, one `termplot()`
#' call draws several panels, and the orchestrator's ordinary multipanel path
#' cannot split them: `combine_layer_results()` maps a layer to a cell by its
#' *group* index, and one recorded call is one group, so every curve would
#' land in the same cell. So this answers `multi_panel = TRUE` and places each
#' curve at its own cell.
#'
#' **The panels are pages, not terms.** `termplot()` sets no layout of its
#' own -- unlike `pairs()`, which calls `par(mfrow)` itself -- so the caller's
#' `par(mfrow)` decides how many terms share a page, and R starts a new page
#' when it runs out of cells. Only the last page is exported. Measured on a
#' three-term `lm`:
#'
#'     no mfrow      (k = 1)   graphics-plot-1                 1 panel
#'     mfrow c(1,2)  (k = 2)   graphics-plot-1                 1 panel
#'     mfrow c(1,3)  (k = 3)   graphics-plot-1 .. -3           3 panels
#'     mfrow c(2,2)  (k = 4)   graphics-plot-1 .. -3           3 panels
#'
#' So with `n` terms and `k` cells the page carries the **last**
#' `((n - 1) %% k) + 1` of them, which is the rule
#' [compute_panel_slots()] already applies to whole plot groups -- the same
#' arithmetic, one level down. A reading that announced all `n` terms would
#' name curves that are not on the page.
#'
#' The `par` call is recorded as LAYOUT rather than as a layer, so it does not
#' reach the processor with the rest of the call. It is read off the device
#' the call was recorded on, through the same [detect_panel_configuration()]
#' the orchestrator uses, so the two cannot disagree about the grid.
#'
#' **What a panel draws.** The curve is the term's fitted contribution,
#' `predict(model, type = "terms")[, term]`, against that term's carrier from
#' the model frame, in increasing carrier order -- which is the order
#' `termplot()` sorts them into before drawing. With
#' `partial.resid = TRUE` it adds the partial residuals,
#' `contribution + residuals(model)`, as points beside the curve; measured,
#' that is a second grob in the same panel:
#'
#'     termplot(fit)                     panel k: lines-1
#'     termplot(fit, partial.resid = T)  panel k: lines-1 and points-1
#'
#' The points are left for a follow-up rather than emitted as a second layer:
#' they are a different reading of the same panel, and the curve is the thing
#' `termplot()` exists to draw.
#'
#' **A factor term is declined.** `termplot()` draws it as a step function
#' over the levels, which is neither this line nor a bar, and reading it as a
#' line would announce a slope between levels that have no order. It is left
#' out of the grid rather than given a wrong shape.
#'
#' @keywords internal
BaseRTermplotLayerProcessor <- R6::R6Class(
  "BaseRTermplotLayerProcessor",
  inherit = BaseRLineLayerProcessor,
  public = list(
    #' @description Emit one line layer per drawn panel
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
      curves <- private$curves(info)
      if (!length(curves)) {
        return(NULL)
      }

      shape <- private$shape(info, length(curves))
      title <- self$extract_main_title(info)

      panels <- list()
      for (index in seq_along(curves)) {
        panels[[length(panels) + 1]] <- list(
          row = (index - 1) %/% shape$ncols + 1,
          col = (index - 1) %% shape$ncols + 1,
          layers = list(private$panel_layer(curves[[index]], index, title))
        )
      }

      list(
        multi_panel = TRUE,
        nrows = shape$nrows,
        ncols = shape$ncols,
        panels = panels
      )
    }
  ),
  private = list(
    # One panel's points, axis labels and selector.
    panel_layer = function(curve, panel, title) {
      list(
        data = lapply(
          seq_along(curve$x),
          function(i) list(x = curve$x[[i]], y = curve$y[[i]])
        ),
        selectors = list(
          paste0("g#graphics-plot-", panel, "-lines-1\\.1")
        ),
        type = "line",
        title = title,
        axes = build_axes(
          x = curve$name,
          y = paste("partial for", curve$name)
        )
      )
    },
    # The curves that are on the page, in the order they were drawn.
    #
    # The recorded call carries the fitted model itself -- `termplot()` takes
    # it as `model`, its first formal, and the recording keeps the evaluated
    # argument -- so the contributions come from the model rather than from
    # the drawing.
    curves = function(layer_info) {
      model <- private$model(layer_info)
      if (is.null(model)) {
        return(list())
      }

      contributions <- tryCatch(
        stats::predict(model, type = "terms"),
        error = function(e) NULL
      )
      frame <- tryCatch(stats::model.frame(model), error = function(e) NULL)
      if (is.null(contributions) || is.null(frame)) {
        return(list())
      }
      contributions <- as.matrix(contributions)
      names <- colnames(contributions)
      if (is.null(names) || !length(names) || !nrow(contributions)) {
        return(list())
      }

      drawn <- list()
      for (name in names) {
        curve <- private$curve(name, contributions, frame)
        if (!is.null(curve)) {
          drawn[[length(drawn) + 1]] <- curve
        }
      }
      private$on_the_page(drawn, layer_info)
    },
    # One term's contribution against its own carrier, in carrier order.
    curve = function(name, contributions, frame) {
      if (!name %in% names(frame)) {
        return(NULL)
      }
      carrier <- frame[[name]]
      # A factor is drawn as a step over its levels; see the file header.
      if (!is.numeric(carrier)) {
        return(NULL)
      }
      contribution <- as.numeric(contributions[, name])
      keep <- !is.na(carrier) & !is.na(contribution)
      if (!any(keep)) {
        return(NULL)
      }
      carrier <- as.numeric(carrier)[keep]
      contribution <- contribution[keep]

      at <- order(carrier)
      list(name = name, x = carrier[at], y = contribution[at])
    },
    # The tail of the curves that the visible page carries.
    #
    # See the file header: `k` cells hold the last `((n - 1) %% k) + 1` of
    # `n` terms, which is `compute_panel_slots()`'s rule one level down.
    on_the_page = function(drawn, layer_info) {
      count <- length(drawn)
      if (count < 2) {
        return(drawn)
      }
      cells <- private$cells(layer_info)
      visible <- ((count - 1) %% cells) + 1
      drawn[seq.int(count - visible + 1, count)]
    },
    # How many panels the caller's layout left room for on one page.
    cells = function(layer_info) {
      config <- private$panel_config(layer_info)
      if (is.null(config)) {
        return(1L)
      }
      total <- suppressWarnings(as.integer(config$total_panels))
      if (is.na(total) || total < 1) {
        return(1L)
      }
      total
    },
    # The grid the visible panels sit in.
    #
    # The caller's own when they set one, and a single cell otherwise --
    # `termplot()` adds no layout of its own, so with no `par()` call there is
    # one panel on the page and nothing to lay out.
    shape = function(layer_info, count) {
      config <- private$panel_config(layer_info)
      if (is.null(config)) {
        return(list(nrows = 1L, ncols = 1L))
      }
      nrows <- suppressWarnings(as.integer(config$nrows))
      ncols <- suppressWarnings(as.integer(config$ncols))
      if (is.na(nrows) || is.na(ncols) || nrows < 1 || ncols < 1) {
        return(list(nrows = 1L, ncols = 1L))
      }
      # Only as much of the grid as the visible page fills. A three-term fit
      # under `mfrow = c(2, 2)` leaves the fourth cell undrawn, and a grid
      # that advertised it would give a reader an empty panel to enter.
      if (nrows * ncols > count) {
        nrows <- ceiling(count / ncols)
      }
      list(nrows = as.integer(nrows), ncols = ncols)
    },
    panel_config = function(layer_info) {
      device <- if (is.null(layer_info)) NULL else layer_info$plot_call$device_id
      if (is.null(device) || !length(device) || is.na(device[[1]])) {
        return(NULL)
      }
      config <- tryCatch(
        detect_panel_configuration(device[[1]]),
        error = function(e) NULL
      )
      if (!is_multipanel_config(config)) {
        return(NULL)
      }
      config
    },
    # The fitted model the call was handed.
    #
    # `model` is `termplot()`'s first formal with nothing ahead of it, so it
    # is either named or the first argument written without a name. A recorded
    # call keeps evaluated arguments, so this is the model object itself.
    model = function(layer_info) {
      if (is.null(layer_info) || is.null(layer_info$plot_call)) {
        return(NULL)
      }
      args <- layer_info$plot_call$args
      if (!length(args)) {
        return(NULL)
      }
      named <- args[["model"]]
      handed <- if (!is.null(named)) {
        named
      } else {
        labels <- names(args)
        at <- if (is.null(labels)) 1L else which(!nzchar(labels))[1L]
        if (is.na(at)) NULL else args[[at]]
      }
      if (is.null(handed) || is.language(handed)) {
        return(NULL)
      }
      handed
    }
  )
)
