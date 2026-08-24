#' Base R Function Classification
#'
#' This module classifies Base R plotting functions into categories:
#' - HIGH: Main plot creation functions (barplot, hist, plot, etc.)
#' - LOW: Drawing functions that add to existing plots (lines, points, etc.)
#' - LAYOUT: Canvas layout functions (par, layout, etc.)
#'
#' @keywords internal
NULL

#' Function Classification Maps
#'
#' @description Maps of function names to their classification levels
#' @keywords internal
.base_r_function_classes <- list(
  HIGH = c(
    "barplot",
    "plot",
    "hist",
    "boxplot",
    "image",
    "heatmap",
    "contour",
    "matplot",
    "curve",
    "dotchart",
    "stripchart",
    # `stem` is deliberately absent, though it lives in `package:graphics`.
    # It writes a stem-and-leaf display to the console: it opens no device,
    # draws no marks, and returns invisibly. Listed here it was recorded as a
    # chart, and measured, that cost two things (#260):
    #
    #   stem() alone      the save stopped with "Failed to create fallback
    #                     image" -- a recorded call over a blank device, the
    #                     shape #216 found for `qqnorm(plot.it = FALSE)`, and
    #                     a message that claims a plot exists;
    #   hist(); stem()    the histogram, interactive on its own, degraded to
    #                     a static image with "Plot contains unsupported
    #                     elements". The console output the caller asked for
    #                     cost them the accessible chart they also drew.
    #
    # Being unlisted is the right answer rather than a gap: `save_html()`
    # then says "No Base R plots detected", which is accurate, and a real
    # chart beside it is read on its own terms. The same call the wrapper
    # makes for `hist(x, plot = FALSE)` and `qqnorm(x, plot.it = FALSE)`,
    # except that those need an argument check and this one does not --
    # `stem()` never draws.
    "pie",
    "mosaicplot",
    "assocplot",
    "pairs",
    "coplot",
    # Recorded so the chart falls back to a picture, not so it is read.
    #
    # A HIGH name with no processor takes the static-image path with a
    # "Plot contains unsupported elements" warning, which is what `dotchart`
    # and `mosaicplot` already do. A name that is missing from this list
    # instead leaves the device with no recorded calls at all, and
    # `save_html()` then stops with "No Base R plots detected. Please create
    # a plot first" -- told to a caller whose plot is on the device (#216).
    # `qqplot` is the eighth: #216 listed seven, and review found it wearing
    # the same defect, since `stats::qqplot` is no more recorded than
    # `stats::qqnorm` was.
    #
    # Being listed here is therefore the *lower* of the two claims, not a
    # promise of a reading. Adding a reading later means adding a processor
    # and a `detect_layer_type()` branch; it does not mean touching this
    # list, because each of these is already recorded.
    "persp",
    "sunflowerplot",
    "fourfoldplot",
    "spineplot",
    "cdplot",
    "qqnorm",
    "qqplot",
    "filled.contour",
    # Twelve more wearing the same defect, found by the sweep #262 records:
    # each draws a chart and `save_html()` then reported "No Base R plots
    # detected. Please create a plot first" -- told to a caller whose chart
    # is on the device. Measured with bare calls, because a qualified
    # `stats::acf(v)` does not go through the search-path patch and would
    # have put `assocplot` and `coplot` on this list wrongly.
    #
    # What goes through `plot()` was already fine and is untouched:
    # `plot(density(x))`, `plot(ecdf(x))`, `plot(ts)`, `plot(lm)` and
    # `plot(acf(x, plot = FALSE))` all record, because `plot` is listed.
    # These are the entry points that draw *without* the generic.
    #
    # Listed, not read: the lower claim again -- except for `bxp`, which has
    # since gained the reading it was named as a candidate for. It draws the
    # same marks `boxplot()` does, from the summaries it is handed instead of
    # from observations, so it takes the `box` layer through a subclass that
    # only overrides where the summaries come from. Gaining that reading did
    # not touch this list, which is the point the paragraph above makes:
    # being recorded and being read are separate steps. #262 records the
    # candidates for the rest, `stars` among them.
    "acf",
    "pacf",
    "ccf",
    "biplot",
    "interaction.plot",
    "cpgram",
    "monthplot",
    "spectrum",
    "lag.plot",
    "termplot",
    "stars",
    "bxp",
    # quantmod entry point for OHLC / candlestick charts. Only chartSeries is
    # wrapped in the MVP; candleChart / barChart / lineChart are deferred.
    "chartSeries",
    # vioplot entry point. Like chartSeries this lives in a Suggests package,
    # so it is wrapped late through the packageEvent hooks in .onLoad rather
    # than at load time -- vioplot may be attached after maidr.
    "vioplot"
  ),
  LOW = c(
    "lines",
    "points",
    "text",
    "mtext",
    "abline",
    # Recorded so that a Q-Q plot carrying a reference line still declines
    # rather than dropping it. `qqnorm()` and `qqplot()` became readable in
    # #251, and `qqline()` -- which is how nearly every Q-Q plot in the wild
    # is finished -- calls `graphics::abline()` from inside `stats`, where
    # the wrapper never sees it. Unrecorded, the line left no trace at all,
    # so the chart came out as a scatter with a drawn mark silently missing
    # from it, which is worse than the picture it used to fall back to.
    #
    # Listed with no `detect_layer_type()` branch, so it types "unknown" and
    # takes the unsupported-elements path -- the same lower claim `persp`
    # and the rest above make. Reading the line itself is #252.
    "qqline",
    "segments",
    "arrows",
    "polygon",
    "rect",
    "symbols",
    "legend",
    "axis",
    "title",
    "grid"
  ),
  LAYOUT = c(
    "par",
    "layout",
    "split.screen"
  )
)

#' Classify a Base R Function
#'
#' Determines the classification level of a Base R plotting function.
#'
#' @param function_name Name of the function to classify
#' @return Character string: "HIGH", "LOW", "LAYOUT", or "UNKNOWN"
#' @keywords internal
classify_function <- function(function_name) {
  if (is.null(function_name) || !is.character(function_name)) {
    return("UNKNOWN")
  }

  base_name <- sub("\\.default$", "", function_name)

  if (base_name %in% .base_r_function_classes$HIGH) {
    "HIGH"
  } else if (base_name %in% .base_r_function_classes$LOW) {
    "LOW"
  } else if (base_name %in% .base_r_function_classes$LAYOUT) {
    "LAYOUT"
  } else {
    "UNKNOWN"
  }
}

#' Get All Functions of a Specific Class
#'
#' Returns all function names for a given classification level.
#'
#' @param class_level Classification level: "HIGH", "LOW", or "LAYOUT"
#' @return Character vector of function names
#' @keywords internal
get_functions_by_class <- function(class_level) {
  if (class_level %in% names(.base_r_function_classes)) {
    return(.base_r_function_classes[[class_level]])
  }
  character(0)
}

#' Check if Function is HIGH-level
#'
#' @param function_name Name of the function
#' @return TRUE if HIGH-level, FALSE otherwise
#' @keywords internal
is_high_level_function <- function(function_name) {
  classify_function(function_name) == "HIGH"
}

#' Check if Function is LOW-level
#'
#' @param function_name Name of the function
#' @return TRUE if LOW-level, FALSE otherwise
#' @keywords internal
is_low_level_function <- function(function_name) {
  classify_function(function_name) == "LOW"
}

#' Check if Function is LAYOUT-level
#'
#' @param function_name Name of the function
#' @return TRUE if LAYOUT-level, FALSE otherwise
#' @keywords internal
is_layout_function <- function(function_name) {
  classify_function(function_name) == "LAYOUT"
}

#' Get All Patchable Functions
#'
#' Returns a list of all functions that should be patched, organized by class.
#'
#' @return List with HIGH, LOW, and LAYOUT function vectors
#' @keywords internal
get_all_patchable_functions <- function() {
  .base_r_function_classes
}

#' Get Flat List of All Patchable Functions
#'
#' Returns a flat vector of all functions to patch.
#'
#' @return Character vector of all patchable function names
#' @keywords internal
get_all_function_names <- function() {
  unlist(.base_r_function_classes, use.names = FALSE)
}
