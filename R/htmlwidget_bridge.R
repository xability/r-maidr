#' Make a plotly, highcharter or echarts4r htmlwidget accessible
#'
#' Attaches MAIDR to an interactive chart drawn by another R package, so a
#' screen reader user can explore it with the keyboard, hear it as
#' sonification, and read it as text and braille. The chart is read by the
#' MAIDR JavaScript adapter for the library that draws it, once it has been
#' drawn in the browser; nothing about it is recomputed in R.
#'
#' Supported widgets:
#' \itemize{
#'   \item \strong{plotly}: \code{plotly::plot_ly()} and
#'     \code{plotly::ggplotly()}. MAIDR's core detects a Plotly chart on the
#'     page by itself, so no adapter is added.
#'   \item \strong{highcharter}: \code{highcharter::highchart()},
#'     \code{highcharter::hchart()} and the stock, map and gantt variants.
#'   \item \strong{echarts4r}: \code{echarts4r::e_charts()}. The chart is
#'     switched to ECharts' SVG renderer, since MAIDR highlights the mark
#'     being read by finding it among the drawn SVG elements, and the
#'     default canvas renderer draws none.
#' }
#'
#' Which chart types each library supports is decided by its MAIDR adapter;
#' see \url{https://maidr.ai/} for the lists. A chart the adapter cannot read
#' is left as it was drawn, with a warning in the browser console.
#'
#' The widget keeps working everywhere an htmlwidget does: the RStudio
#' viewer, \code{htmlwidgets::saveWidget()}, R Markdown and Quarto documents,
#' and Shiny (\code{plotly::renderPlotly()},
#' \code{highcharter::renderHighchart()}, \code{echarts4r::renderEcharts4r()}),
#' where the chart is read again each time the server re-renders it.
#'
#' Applying it twice returns the widget unchanged.
#'
#' @section Fan charts in echarts4r:
#' ECharts has no series for a band: a fan chart is drawn as a median
#' `e_line()` and, for each band, an invisible line holding its lower edge
#' with an `e_area()` of its width stacked on it. Nothing in the chart says
#' which quantiles those edges are, so they are stated with
#' `percentile_bands`, and MAIDR then reads the median and its bands as one
#' percentile band layer (experimental): each position announced with its
#' median and the edges of every band, as ECharts computed them for drawing.
#' Name the median's series and each band's filled series by the `name`
#' (or `id`) ECharts knows it by -- in echarts4r, the `name` given to
#' `e_line()` and `e_area()`, or the column name when none was given. Each
#' band's `lower` and `upper` are fractions, `0.05` rather than `5`, every
#' `lower` below 0.5 and every `upper` above it, and the bands must nest.
#' Draw the fan over a category x axis, a character or factor column given
#' to `e_charts()`: over a numeric x axis ECharts stacks each series on the
#' x values rather than the y, so neither the picture nor the reading is a
#' band. A width series stacks on a negative lower edge only under
#' `stackStrategy = "all"`.
#'
#' The option is read by maidr.js 4.15.0 and later. The copy bundled with
#' this version of the package is older, so with `use_cdn = FALSE`, or a
#' `maidr.cdn_version` pinned below 4.15.0, `percentile_bands` is checked
#' and then ignored with a warning, and the series read as they would be
#' without it.
#'
#' @param widget An htmlwidget created by plotly, highcharter or echarts4r.
#' @param use_cdn Logical. Where the MAIDR scripts are loaded from:
#'   \itemize{
#'     \item \code{FALSE} (default): the copy bundled with this package,
#'       which works offline and makes no network request.
#'     \item \code{TRUE}: the jsDelivr CDN, which loads the latest published
#'       MAIDR unless \code{maidr.cdn_version} pins one; see
#'       \code{?"maidr-options"}.
#'   }
#' @param percentile_bands echarts4r only. The fan charts the chart draws,
#'   each read as one percentile band layer; see "Fan charts in echarts4r"
#'   below. A list of fans, or a single fan, each a list with:
#'   \itemize{
#'     \item \code{median}: the name of the median's line series.
#'     \item \code{bands}: a data frame with columns \code{series},
#'       \code{lower} and \code{upper}, or a list of lists with those
#'       elements, one per band: the name of the band's filled series and
#'       the quantiles of its lower and upper edges, as fractions.
#'     \item \code{title}, \code{name} (optional): the layer's title and
#'       name, in place of the ones read from the chart.
#'   }
#'   \code{NULL} (default) declares none.
#' @param hover_mode highcharter and echarts4r only. How the pointer moves
#'   the reader through the chart: \code{"pointermove"}, \code{"click"} or
#'   \code{"off"}, as in \code{\link{show}()}, written into the chart MAIDR
#'   reads once it has been drawn. \code{NULL} (default) takes
#'   \code{getOption("maidr.hover_mode")}, and when that is unset writes
#'   nothing, so maidr.js uses the reader's own setting. A plotly chart is
#'   read by the MAIDR core itself, which takes no hover mode from R: an
#'   explicit \code{hover_mode} is refused for one, and the option is not
#'   applied to it.
#' @return The widget, with MAIDR attached. Print it, return it from a
#'   Shiny render function, or save it as you would the original.
#' @examples
#' if (requireNamespace("plotly", quietly = TRUE)) {
#'   w <- plotly::plot_ly(
#'     x = c("Mon", "Tue", "Wed"), y = c(20, 14, 23), type = "bar"
#'   )
#'   w <- maidr_htmlwidget(w)
#' }
#' \dontrun{
#' # Pipe-friendly
#' library(echarts4r)
#' mtcars |>
#'   e_charts(wt) |>
#'   e_scatter(mpg) |>
#'   maidr_htmlwidget()
#'
#' # A fan chart: a median and a 90% band drawn as a stacked area
#' fan <- data.frame(
#'   week = paste("Week", 1:8),
#'   median = c(10, 12, 13, 15, 16, 18, 19, 21),
#'   lower = c(8, 9, 9, 10, 10, 11, 11, 12)
#' )
#' fan$width <- 2 * (fan$median - fan$lower)
#' fan |>
#'   e_charts(week) |>
#'   e_line(median, name = "Median") |>
#'   e_line(lower, stack = "band", name = "lower", symbol = "none",
#'          lineStyle = list(opacity = 0)) |>
#'   e_area(width, stack = "band", name = "90% interval", symbol = "none") |>
#'   maidr_htmlwidget(
#'     use_cdn = TRUE,
#'     percentile_bands = list(
#'       median = "Median",
#'       bands = data.frame(series = "90% interval", lower = 0.05, upper = 0.95)
#'     )
#'   )
#' }
#' @export
maidr_htmlwidget <- function(widget, use_cdn = FALSE, percentile_bands = NULL,
                             hover_mode = NULL) {
  adapter <- maidr_htmlwidget_adapter(widget)

  if (!is.logical(use_cdn) || length(use_cdn) != 1L || is.na(use_cdn)) {
    stop("`use_cdn` must be TRUE or FALSE.", call. = FALSE)
  }

  # The core binds a plotly chart on its own, from a schema it builds itself,
  # so there is nothing here to write a hover mode into.
  check_hover_mode(hover_mode)
  if (identical(adapter, "plotly")) {
    if (!is.null(hover_mode)) {
      stop(
        "`hover_mode` is read only for a highcharter or echarts4r widget: ",
        "MAIDR reads a plotly chart by itself.",
        call. = FALSE
      )
    }
  } else {
    hover_mode <- resolve_hover_mode(hover_mode)
  }

  options <- list()
  if (!is.null(percentile_bands)) {
    if (!identical(adapter, "echarts")) {
      stop(
        "`percentile_bands` is read only for an echarts4r widget.",
        call. = FALSE
      )
    }
    fans <- validate_percentile_bands(percentile_bands)
    warn_unknown_echarts_series(widget, fans)
    if (echarts_percentile_bands_available(use_cdn)) {
      options$percentileBands <- fans
    } else {
      warning(
        "`percentile_bands` needs maidr.js ", ECHARTS_PERCENTILE_BANDS_VERSION,
        " or later, and this widget loads ",
        maidr_widget_version(use_cdn), "; it is ignored, and the series are ",
        "read as they would be without it. Use `use_cdn = TRUE` to load the ",
        "latest maidr.js.",
        call. = FALSE
      )
    }
  }

  already_bound <- vapply(
    widget$dependencies,
    function(dep) identical(dep$name, "maidr"),
    logical(1)
  )
  if (any(already_bound)) {
    return(widget)
  }

  if (identical(adapter, "echarts")) {
    widget$x$renderer <- "svg"
  }

  deps <- maidr_html_dependencies(use_cdn = use_cdn)
  if (!identical(adapter, "plotly")) {
    deps <- c(deps, list(maidr_adapter_dependency(adapter, use_cdn = use_cdn)))
  }
  widget$dependencies <- c(widget$dependencies, deps)

  data <- list(adapter = adapter)
  if (length(options) > 0L) {
    data$options <- options
  }
  if (!is.null(hover_mode)) {
    data$hoverMode <- hover_mode
  }
  htmlwidgets::onRender(widget, MAIDR_HTMLWIDGET_BIND_JS, data = data)
}

# The first maidr.js whose ECharts adapter reads `percentileBands`
# (xability/maidr#1369, released after 4.14.0).
ECHARTS_PERCENTILE_BANDS_VERSION <- "4.15.0"

#' The maidr.js version a widget loads
#'
#' @param use_cdn Logical, as in [maidr_htmlwidget()].
#' @return The bundled `MAIDR_VERSION`, or the version CDN documents load,
#'   which may be `"latest"`
#' @keywords internal
maidr_widget_version <- function(use_cdn) {
  if (isTRUE(use_cdn)) maidr_cdn_version() else MAIDR_VERSION
}

#' Whether the maidr.js a widget loads reads ECharts' `percentileBands`
#'
#' The option shipped in the ECharts adapter after maidr.js 4.14.0, the
#' version bundled with this package. An older maidr.js ignores an option it
#' does not know, so emitting it would do no harm, but nothing would be read
#' either and the author would never learn why; the option is therefore
#' dropped with a warning on the R side instead, as the `*_trace_available()`
#' checks drop a trace the bundle cannot build. The moment the bundle, or the
#' CDN version, reaches the release that carries it, the option goes through.
#'
#' @param use_cdn Logical, as in [maidr_htmlwidget()].
#' @return TRUE when the loaded maidr.js reads the option
#' @keywords internal
echarts_percentile_bands_available <- function(use_cdn = FALSE) {
  version <- maidr_widget_version(use_cdn)
  if (identical(version, MAIDR_CDN_LATEST_TAG)) {
    return(TRUE)
  }
  !maidr_is_older_than_bundled(version, ECHARTS_PERCENTILE_BANDS_VERSION)
}

#' Check the fan charts declared for an echarts4r widget
#'
#' The rules are the ones maidr.js's own validator applies
#' (`isValidBands()` in its trace declarations), checked here so that a
#' mistake is an error in R, where the author is, rather than a warning in
#' a browser console nobody opens: a median named by a non-empty string, at
#' least one band, each naming a series with a `lower` level from 0 to below
#' 0.5 and an `upper` one above 0.5 to 1, fractions rather than percentages,
#' and the bands nested, each strictly inside the next wider one.
#'
#' @param percentile_bands A fan -- a list with `median` and `bands` -- or a
#'   list of them.
#' @return A list of fans, each a list of `median`, `bands` (a list of
#'   `list(series, lower, upper)`) and, when given, `title` and `name`, in
#'   the shape maidr.js reads once serialised.
#' @keywords internal
validate_percentile_bands <- function(percentile_bands) {
  if (!is.list(percentile_bands) || is.data.frame(percentile_bands) ||
      length(percentile_bands) == 0L) {
    stop(
      "`percentile_bands` must be a list of fans, each a list of `median` ",
      "and `bands`.",
      call. = FALSE
    )
  }
  if ("median" %in% names(percentile_bands)) {
    percentile_bands <- list(percentile_bands)
  }
  lapply(seq_along(percentile_bands), function(i) {
    validate_percentile_fan(percentile_bands[[i]], sprintf("`percentile_bands[[%d]]`", i))
  })
}

#' Check one fan of `percentile_bands`
#'
#' @param fan A list with `median`, `bands` and optionally `title`, `name`
#' @param where How the fan is named in an error
#' @return The fan, normalised
#' @keywords internal
validate_percentile_fan <- function(fan, where) {
  fail <- function(...) stop(where, " ", ..., call. = FALSE)

  if (!is.list(fan) || is.data.frame(fan) || is.null(names(fan))) {
    fail("must be a list of `median` and `bands`.")
  }
  unknown <- setdiff(names(fan), c("median", "bands", "title", "name"))
  if (length(unknown) > 0L) {
    fail(
      "has unknown element(s) ", paste0("`", unknown, "`", collapse = ", "),
      "; expected `median`, `bands`, `title` and `name`."
    )
  }
  if (!is_band_text(fan$median)) {
    fail("must name its median series in `median`, a non-empty string.")
  }
  for (key in c("title", "name")) {
    if (!is.null(fan[[key]]) && !is_band_text(fan[[key]])) {
      fail("has a `", key, "` that is not a non-empty string.")
    }
  }

  bands <- percentile_band_rows(fan$bands, fail)
  bands <- lapply(seq_along(bands), function(j) {
    validate_percentile_band(bands[[j]], sprintf("`bands[[%d]]`", j), fail)
  })
  check_bands_nest(bands, fail)

  normalised <- list(median = fan$median, bands = bands)
  if (!is.null(fan$title)) normalised$title <- fan$title
  if (!is.null(fan$name)) normalised$name <- fan$name
  normalised
}

#' Whether a value is one non-empty string
#'
#' @param value Anything
#' @return TRUE for a single, non-missing, non-empty string
#' @keywords internal
is_band_text <- function(value) {
  is.character(value) && length(value) == 1L && !is.na(value) && nzchar(value)
}

#' A fan's bands as a list, one entry per band
#'
#' @param bands A data frame with `series`, `lower` and `upper` columns, or a
#'   list of lists
#' @param fail Raises an error located on the fan
#' @return A non-empty list
#' @keywords internal
percentile_band_rows <- function(bands, fail) {
  if (is.data.frame(bands)) {
    missing_cols <- setdiff(c("series", "lower", "upper"), names(bands))
    if (length(missing_cols) > 0L) {
      fail(
        "`bands` lacks the column(s) ",
        paste0("`", missing_cols, "`", collapse = ", "), "."
      )
    }
    bands <- lapply(seq_len(nrow(bands)), function(row) {
      list(
        series = as.character(bands$series[[row]]),
        lower = bands$lower[[row]],
        upper = bands$upper[[row]]
      )
    })
  }
  if (!is.list(bands) || length(bands) == 0L) {
    fail(
      "must list at least one band in `bands`, each with `series`, ",
      "`lower` and `upper`."
    )
  }
  bands
}

#' Check one band of a fan
#'
#' @param band A list of `series`, `lower` and `upper`
#' @param at How the band is named in an error
#' @param fail Raises an error located on the fan
#' @return The band, its levels as numbers
#' @keywords internal
validate_percentile_band <- function(band, at, fail) {
  if (!is.list(band) || is.null(names(band))) {
    fail(at, " must be a list of `series`, `lower` and `upper`.")
  }
  unknown <- setdiff(names(band), c("series", "lower", "upper"))
  if (length(unknown) > 0L) {
    fail(at, " has unknown element(s) ", paste0("`", unknown, "`", collapse = ", "), ".")
  }
  if (!is_band_text(band$series)) {
    fail(at, " must name its filled series in `series`, a non-empty string.")
  }
  level <- function(value, from, to) {
    is.numeric(value) && length(value) == 1L && is.finite(value) &&
      value >= from && value <= to
  }
  usable <- level(band$lower, 0, 0.5) && band$lower < 0.5 &&
    level(band$upper, 0.5, 1) && band$upper > 0.5
  if (!usable) {
    fail(
      at, " has levels ", format(band$lower), " and ", format(band$upper),
      "; expected a `lower` from 0 to below 0.5 and an `upper` above 0.5 ",
      "to 1, as fractions (0.05, not 5)."
    )
  }
  list(
    series = band$series,
    lower = as.numeric(band$lower),
    upper = as.numeric(band$upper)
  )
}

#' Check that a fan's bands nest, each strictly inside the next wider one
#'
#' @param bands Checked bands, from [validate_percentile_band()]
#' @param fail Raises an error located on the fan
#' @return NULL, invisibly
#' @keywords internal
check_bands_nest <- function(bands, fail) {
  lowers <- vapply(bands, function(band) band$lower, numeric(1))
  outermost_first <- bands[order(lowers)]
  for (k in seq_along(outermost_first)[-1L]) {
    outer <- outermost_first[[k - 1L]]
    inner <- outermost_first[[k]]
    if (!(inner$lower > outer$lower && inner$upper < outer$upper)) {
      fail(
        "has bands \"", outer$series, "\" and \"", inner$series,
        "\" that do not nest; each band must lie strictly inside the next ",
        "wider one."
      )
    }
  }
  invisible(NULL)
}

#' Warn about fan series the echarts4r widget does not draw
#'
#' maidr.js reports a series it cannot find in the browser console, where an
#' R author is unlikely to look, so a name that matches none of the widget's
#' series names or ids is said here too. Only a widget whose series are in
#' its options (`x$opts$series`) is checked; a name may still match a series
#' added later, as a Shiny proxy adds them, so this warns rather than stops.
#'
#' @param widget The echarts4r widget
#' @param fans Fans from [validate_percentile_bands()]
#' @return NULL, invisibly
#' @keywords internal
warn_unknown_echarts_series <- function(widget, fans) {
  series <- widget$x$opts$series
  if (!is.list(series) || length(series) == 0L) {
    return(invisible(NULL))
  }
  known <- unlist(lapply(series, function(s) {
    if (is.list(s)) c(s$name, s$id) else NULL
  }), use.names = FALSE)
  known <- as.character(known)

  wanted <- unique(unlist(lapply(fans, function(fan) {
    c(fan$median, vapply(fan$bands, function(band) band$series, character(1)))
  }), use.names = FALSE))
  missing_names <- setdiff(wanted, known)
  if (length(missing_names) > 0L) {
    warning(
      "`percentile_bands` names ",
      paste0("\"", missing_names, "\"", collapse = ", "),
      ", which the chart has no series of; series are named by the `name` ",
      "given to e_line() or e_area(), or their column. The chart has ",
      paste0("\"", unique(known), "\"", collapse = ", "), ".",
      call. = FALSE
    )
  }
  invisible(NULL)
}

#' Which MAIDR adapter reads a widget
#'
#' @param widget The object passed to [maidr_htmlwidget()].
#' @return `"plotly"`, `"highcharts"` or `"echarts"`.
#' @keywords internal
maidr_htmlwidget_adapter <- function(widget) {
  if (!inherits(widget, "htmlwidget")) {
    stop(
      "`widget` must be an htmlwidget from plotly, highcharter or echarts4r. ",
      "For a ggplot2, lattice or Base R plot, use maidr::show() instead.",
      call. = FALSE
    )
  }

  if (inherits(widget, "plotly")) {
    return("plotly")
  }
  if (inherits(widget, "highchart")) {
    return("highcharts")
  }
  if (inherits(widget, "echarts4r")) {
    return("echarts")
  }

  stop(
    sprintf(
      "maidr cannot read a `%s` htmlwidget. Supported: plotly, highcharter and echarts4r.",
      class(widget)[[1]]
    ),
    call. = FALSE
  )
}

#' The dependency carrying a MAIDR chart-library adapter
#'
#' The adapters are UMD bundles published beside `maidr.js` -- `highcharts.js`
#' defines `window.maidrHighcharts`, `echarts.js` defines
#' `window.maidrECharts` -- and are bundled in the same directory, so the
#' local and CDN copies are always the same release as the core they run
#' against. Only the adapter's own file is declared (`all_files = FALSE`): the
#' directory also holds the multi-megabyte core, which the `maidr`
#' dependency already copies.
#'
#' @param adapter `"highcharts"` or `"echarts"`.
#' @param use_cdn Logical, as in [maidr_htmlwidget()].
#' @return A single htmltools::htmlDependency()
#' @keywords internal
maidr_adapter_dependency <- function(adapter, use_cdn = FALSE) {
  script <- paste0(adapter, ".js")
  if (isTRUE(use_cdn)) {
    return(htmltools::htmlDependency(
      name = paste0("maidr-", adapter),
      version = MAIDR_VERSION,
      src = c(href = maidr_cdn_url()),
      script = script
    ))
  }
  htmltools::htmlDependency(
    name = paste0("maidr-", adapter),
    version = MAIDR_VERSION,
    package = "maidr",
    src = sprintf("htmlwidgets/lib/maidr-%s", MAIDR_VERSION),
    script = script,
    all_files = FALSE
  )
}

# Runs after each render of the widget (htmlwidgets calls `onRender` hooks
# after every `renderValue`, so a Shiny re-render reads the new chart).
#
# A plotly chart is found by the core itself, which marks the graph div
# `data-maidr-auto` once it has bound it and never looks at a marked div again.
# A Shiny re-render draws the chart afresh into the same div, discarding what
# MAIDR mounted, so the mark is cleared here: the core's observer runs after
# this hook, sees the new drawing and binds it.
#
# An echarts4r widget's adapter options (`percentileBands`, from
# `maidr_htmlwidget(percentile_bands = )`) arrive as `data.options`, and are
# handed to `createMaidrFromEChart()` as its third argument.
#
# A hover mode (`maidr_htmlwidget(hover_mode = )`, or the `maidr.hover_mode`
# option) arrives as `data.hoverMode` and is written into the top level of
# the schema the adapter built, as `with_hover_mode()` writes it for a chart
# drawn in R, before the schema is handed over.
#
# The payload is handed to MAIDR through the `maidr:bindchart` event, which
# `maidr.js` listens for from the moment it loads, and the `maidr-data`
# attribute it reads is removed again once it has. Left in place, it would be
# found by the page scan `maidr.js` runs at DOMContentLoaded, which initialises
# the chart a second time and, finding a bound chart, skips the automatic
# detection that makes a plotly widget on the same page accessible.
MAIDR_HTMLWIDGET_BIND_JS <- "function (el, x, data) {
  function warn(message) {
    if (window.console) {
      console.warn('maidr: ' + message + '; the chart is left as drawn.');
    }
  }

  function bind(target, maidr) {
    if (data.hoverMode) {
      maidr.hoverMode = data.hoverMode;
    }
    target.setAttribute('maidr-data', JSON.stringify(maidr));
    target.dispatchEvent(
      new CustomEvent('maidr:bindchart', { bubbles: true, detail: maidr })
    );
    target.removeAttribute('maidr-data');
  }

  if (data.adapter === 'plotly') {
    el.removeAttribute('data-maidr-auto');
    return;
  }

  if (data.adapter === 'highcharts') {
    if (!window.Highcharts || !window.maidrHighcharts) {
      warn('the Highcharts adapter did not load');
      return;
    }
    var charts = (window.Highcharts.charts || []).filter(function (c) {
      return c && c.renderTo === el;
    });
    var chart = charts[charts.length - 1];
    if (!chart) {
      warn('no Highcharts chart was drawn into #' + el.id);
      return;
    }
    try {
      bind(chart.renderTo, window.maidrHighcharts.highchartsToMaidr(chart, { id: el.id }));
    } catch (e) {
      warn('the Highcharts chart could not be read (' + e.message + ')');
    }
    return;
  }

  if (data.adapter === 'echarts') {
    var instance = window.echarts && window.echarts.getInstanceByDom(el);
    if (!instance || !window.maidrECharts) {
      warn('the ECharts adapter did not load');
      return;
    }
    // The adapter finds the marks among the drawn elements, so it has to run
    // once ECharts has drawn them, which is after this hook returns.
    instance.on('finished', function once() {
      instance.off('finished', once);
      try {
        bind(el, window.maidrECharts.createMaidrFromEChart(instance, el, data.options || {}));
      } catch (e) {
        warn('the ECharts chart could not be read (' + e.message + ')');
      }
    });
  }
}"
