#' Base R Spike Plot Layer Processor
#'
#' Processes Base R spike layers -- `plot(x, y, type = "h")` and the
#' `lines()` equivalent. `type = "h"` draws a vertical line from the baseline
#' to each value and joins nothing to anything: the samples stand side by
#' side rather than in a series.
#'
#' Read as a `lollipop` layer, which the core builds on `BarTrace`: one value
#' per position, with no claim about the space between two of them. The
#' marker head a lollipop conventionally carries is the only difference from
#' what base R draws here, and it is not something a reader hears.
#'
#' Announced as a `line` before this existed, which is the reading a spike
#' chart most needs not to have -- a line says the samples are joined and
#' that the space between them can be interpolated, and that is the one
#' relationship the chart is drawn to deny (#239).
#'
#' Data extraction, axis titles and the main title are a line layer's, so
#' this inherits `BaseRLineLayerProcessor`; what it adds is the layer `type`,
#' the flat point list a bar-shaped trace wants, and the grob family the
#' spikes are actually named after.
#'
#' @keywords internal
BaseRSpikeLayerProcessor <- R6::R6Class(
  "BaseRSpikeLayerProcessor",
  inherit = BaseRLineLayerProcessor,
  public = list(
    #' @description Process the spike layer.
    #' @param plot Unused for Base R (kept for interface compatibility)
    #' @param layout Unused for Base R (kept for interface compatibility)
    #' @param built Unused for Base R (kept for interface compatibility)
    #' @param gt Gtable object used for selector generation (optional)
    #' @param grob_id Unused for Base R
    #' @param panel_id Unused for Base R
    #' @param panel_ctx Unused for Base R
    #' @param layer_info Information about the recorded plot call
    #' @return List with data, selectors, type, title and axes
    process = function(plot,
                       layout,
                       built = NULL,
                       gt = NULL,
                       grob_id = NULL,
                       panel_id = NULL,
                       panel_ctx = NULL,
                       layer_info = NULL) {
      list(
        data = self$extract_data(layer_info),
        selectors = self$generate_selectors(layer_info, gt),
        type = "lollipop",
        title = self$extract_main_title(layer_info),
        axes = self$extract_axis_titles(layer_info)
      )
    },

    #' @description Read the spikes as one flat list of points.
    #'
    #' A line layer's `data` is a list of *series*, because several lines can
    #' share one layer. A lollipop is read as a bar is, and a bar layer's
    #' `data` is one point per position -- so the single series the inherited
    #' extraction produces is unwrapped here rather than shipped one level
    #' too deep, where the frontend would read the whole chart as a single
    #' point.
    #'
    #' Only the first series is taken. `plot(type = "h")` and
    #' `lines(type = "h")` each draw exactly one, and `matplot` -- the call
    #' that draws several -- has its own dispatch that never reaches here.
    #'
    #' @param layer_info Information about the recorded plot call
    #' @return List of `x`/`y` points, empty when there is nothing to read
    extract_data = function(layer_info) {
      series <- super$extract_data(layer_info)
      if (!length(series) || !is.list(series[[1]])) {
        return(list())
      }
      series[[1]]
    },

    #' @description Draw a spike layer's selectors from the spike grobs.
    #'
    #' gridGraphics names a grob after what drew it, so spikes land under
    #' `graphics-plot-N-spike-M` -- never under the `-lines-` name the
    #' inherited search looks for. Measured on `plot(1:6, y, type = "h")`,
    #' one polyline per spike sits under that grob, in data order:
    #'
    #'     <polyline id="graphics-plot-1-spike-1.1.1" points="74.4,... "/>
    #'     <polyline id="graphics-plot-1-spike-1.1.2" points="151.2,..."/>
    #'     ...
    #'
    #' so the one selector this yields resolves to one element per point,
    #' which is what a bar-shaped trace pairs with its data.
    #'
    #' @param layer_info Information about the recorded plot call
    #' @return "spike"
    selector_grob_type = function(layer_info) {
      "spike"
    }
  )
)
