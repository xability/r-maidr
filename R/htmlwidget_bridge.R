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
#' @param widget An htmlwidget created by plotly, highcharter or echarts4r.
#' @param use_cdn Logical. Where the MAIDR scripts are loaded from:
#'   \itemize{
#'     \item \code{FALSE} (default): the copy bundled with this package,
#'       which works offline and makes no network request.
#'     \item \code{TRUE}: the jsDelivr CDN, which loads the latest published
#'       MAIDR unless \code{maidr.cdn_version} pins one; see
#'       \code{?"maidr-options"}.
#'   }
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
#' }
#' @export
maidr_htmlwidget <- function(widget, use_cdn = FALSE) {
  adapter <- maidr_htmlwidget_adapter(widget)

  if (!is.logical(use_cdn) || length(use_cdn) != 1L || is.na(use_cdn)) {
    stop("`use_cdn` must be TRUE or FALSE.", call. = FALSE)
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

  htmlwidgets::onRender(
    widget,
    MAIDR_HTMLWIDGET_BIND_JS,
    data = list(adapter = adapter)
  )
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
      "For a ggplot2 or Base R plot, use maidr::show() instead.",
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
        bind(el, window.maidrECharts.createMaidrFromEChart(instance, el));
      } catch (e) {
        warn('the ECharts chart could not be read (' + e.message + ')');
      }
    });
  }
}"
