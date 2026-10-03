# Which chart is on which of a chunk's figures.
#
# knitr records every page a chunk draws, keeps the ones `fig.keep` asks for,
# puts them in the order `fig.show` asks for, and then, figure by figure,
# replays the page into the figure's file and calls the plot hook with that
# file's name. The hook is never handed the page, so on its own it cannot
# tell which of the chunk's charts the figure shows: a loop printing three
# ggplot2 charts, a barplot() and a hist(), or a ggplot2 chart printed beside
# a Base R one.
#
# So every chart drawn in a knit leaves a marker on its page: an entry on the
# device's display list, made with `grDevices::recordGraphics()`, that draws
# nothing and, each time the page is replayed, reports the chart's token
# (`knit_page_replayed()`). knitr replays a figure's page just before it
# calls the hook for that figure, so the tokens reported since the hook last
# ran name the charts on the figure in hand -- whatever `fig.keep`, `fig.show`
# or `dev` say. A ggplot2 or lattice chart printed in the knit is queued
# under its token; a Base R call is recorded with its token as `uid`.
#
# The hook shows a figure as a chart only when its tokens name exactly one
# ggplot2 or lattice chart, or Base R calls alone, recorded on one device;
# anything else -- two charts on a page, a chart something else was drawn
# over, a chart drawn across pages, a replay made by the chunk itself -- is
# left as knitr's own figure. A wrong chart is never shown.

.maidr_knit_figures <- new.env(parent = emptyenv())
# Tokens reported by the pages replayed since the plot hook last ran, and the
# page each was drawn on.
.maidr_knit_figures$seen <- character()
.maidr_knit_figures$seen_page <- integer()
# The ggplot2 and lattice charts drawn in the knit, by token: each a list of
# the chart and the device it was drawn on.
.maidr_knit_figures$objects <- list()
.maidr_knit_figures$counter <- 0L
.maidr_knit_figures$session <- NULL
# The pages the knit has started, and the count when a Base R call started.
.maidr_knit_figures$page <- 0L
.maidr_knit_figures$call_start_page <- 0L
# TRUE while a marker is made, which evaluates it once, and while the plot
# hook renders a chart, which draws charts of its own.
.maidr_knit_figures$drawing <- FALSE
.maidr_knit_figures$rendering <- FALSE

#' Whether a chart drawn now is a figure maidr matches to its chart
#'
#' While knitting HTML, with maidr's plot hook the one knitr will call: a
#' chart drawn when nothing reads its marker would only be queued for
#' nothing. Not while the hook renders a chart.
#'
#' @return Logical
#' @keywords internal
#' @noRd
knit_figures_active <- function() {
  !isTRUE(.maidr_knit_figures$rendering) &&
    knit_in_progress() &&
    is_maidr_knitr_hook(knitr::knit_hooks$get("plot")) &&
    is_html_output()
}

#' A token for one chart drawn in a knit
#'
#' Unique across R sessions, not only within one: knitr's `cache = 1` and
#' `cache = 2` keep a chunk's recorded pages, markers and all, and replay
#' them in a later session, whose own charts must not answer to them. The
#' session part is built as [inline_id_prefix()] builds its own, from the
#' time and the process id, never from the random number stream.
#'
#' @param kind `"o"` for a ggplot2 or lattice chart, `"b"` for a Base R call
#' @return A string
#' @keywords internal
#' @noRd
new_knit_token <- function(kind) {
  state <- .maidr_knit_figures
  if (is.null(state$session)) {
    state$session <- paste0(
      base36_fixed(floor(unclass(Sys.time()) * 1000), 9L),
      base36_fixed(Sys.getpid(), 5L)
    )
  }
  state$counter <- state$counter + 1L
  paste0(kind, state$session, "-", state$counter)
}

#' Note the page count a Base R call starts at
#'
#' Called by every recording wrapper before it draws (`ensure_maidr_device()`),
#' so the call's marker can tell a call that drew several pages.
#'
#' @return NULL (invisible)
#' @keywords internal
#' @noRd
note_knit_call_start <- function() {
  .maidr_knit_figures$call_start_page <- .maidr_knit_figures$page
  invisible(NULL)
}

#' Leave a chart's marker on the current page
#'
#' The marker's expression needs only base R, and calls back into maidr
#' through the `maidr.knit.replayed` option, which maidr's knitr integration
#' sets (`install_knitr_integration()`): knitr's cache keeps recorded pages
#' and replays them in later sessions, which may have another maidr, or none.
#' The expression is evaluated once now, which is ignored, and again each
#' time the page is replayed.
#'
#' A chart whose drawing started more than one new page -- `plot(fit,
#' which = 1:2)`, a lattice chart laid out over several pages -- is on no
#' single figure, and is marked with page `NA`: each of its figures, and
#' whatever shares its last page, stays knitr's.
#'
#' @param token The chart's token
#' @param start_page The page count when the chart started drawing
#' @return NULL (invisible)
#' @keywords internal
#' @noRd
mark_knit_page <- function(token, start_page) {
  if (grDevices::dev.cur() == 1L) {
    return(invisible(NULL))
  }
  state <- .maidr_knit_figures
  page <- state$page
  if (page - start_page > 1L) {
    page <- NA_integer_
  }
  state$drawing <- TRUE
  on.exit(state$drawing <- FALSE, add = TRUE)
  grDevices::recordGraphics(
    {
      replayed <- getOption("maidr.knit.replayed")
      if (is.function(replayed)) replayed(maidr_token, maidr_page)
    },
    list(maidr_token = token, maidr_page = page),
    baseenv()
  )
  invisible(NULL)
}

#' Note a chart whose page is being replayed
#'
#' The callback of every marker (`mark_knit_page()`), through the
#' `maidr.knit.replayed` option. A chart something else was drawn over is
#' noted under a token no chart has, so its figure stays knitr's
#' (`knit_marker_overdrawn()`).
#'
#' @param token The chart's token
#' @param page The page it was drawn on, `NA` for several
#' @return NULL (invisible)
#' @keywords internal
knit_page_replayed <- function(token, page) {
  state <- .maidr_knit_figures
  ignored <- isTRUE(state$drawing) || !knit_figures_active() ||
    !is.character(token) || length(token) != 1L
  if (ignored) {
    return(invisible(NULL))
  }
  if (knit_marker_overdrawn(token)) {
    token <- paste0("x", token)
  }
  state$seen <- c(state$seen, token)
  state$seen_page <- c(state$seen_page, as.integer(page)[1L])
  invisible(NULL)
}

#' Whether something was drawn over a chart after its marker
#'
#' Read from the display list being replayed, which `recordPlot()` returns
#' while the replay runs. Anything after a ggplot2 or lattice chart's marker
#' other than another marker -- `grid.text()`, an inset printed into a
#' viewport, `trellis.focus()` and a `panel.*()` call -- is not in the chart,
#' and showing the chart would leave it out. After a Base R call's marker,
#' only grid drawing counts: a Base R call maidr does not record is left out
#' of the chart as it always was.
#'
#' @param token The chart's token
#' @return Logical; `TRUE` as well when the display list cannot be read
#' @keywords internal
#' @noRd
knit_marker_overdrawn <- function(token) {
  entries <- tryCatch(grDevices::recordPlot()[[1L]], error = function(e) NULL)
  if (!is.list(entries)) {
    return(TRUE)
  }
  tokens <- vapply(entries, knit_marker_token, character(1))
  own <- which(tokens == token)
  if (length(own) == 0L) {
    return(TRUE)
  }
  after <- seq_along(entries) > max(own) & is.na(tokens)
  if (startsWith(token, "b")) {
    after <- after & vapply(entries, is_recorded_graphics_entry, logical(1))
  }
  any(after)
}

#' The token of a display list entry that is a chart's marker
#'
#' @param entry An entry of a recorded plot's display list
#' @return The token, or `NA` for any other entry
#' @keywords internal
#' @noRd
knit_marker_token <- function(entry) {
  args <- if (length(entry) >= 2L) entry[[2L]]
  if (length(args) < 2L || !is.list(args[[2L]])) {
    return(NA_character_)
  }
  token <- args[[2L]][["maidr_token"]]
  if (is.character(token) && length(token) == 1L) token else NA_character_
}

#' Whether a display list entry was recorded with `recordGraphics()`
#'
#' As grid records every grob it draws. A Base R call is recorded as the
#' graphics engine's own operation, whose first argument is a native
#' routine rather than an expression.
#'
#' @param entry An entry of a recorded plot's display list
#' @return Logical
#' @keywords internal
#' @noRd
is_recorded_graphics_entry <- function(entry) {
  args <- if (length(entry) >= 2L) entry[[2L]]
  length(args) >= 1L && is.language(args[[1L]])
}

#' Count a page a knit starts: R's `before.plot.new` hook
#'
#' `plot.new()` starts a page unless it moves to the next panel of one
#' (`par(mfrow = )`), which `par("page")` tells before it does.
#'
#' @return NULL (invisible)
#' @keywords internal
knit_before_plot_new <- function() {
  if (knit_figures_active() && grDevices::dev.cur() != 1L && isTRUE(graphics::par("page"))) {
    .maidr_knit_figures$page <- .maidr_knit_figures$page + 1L
  }
  invisible(NULL)
}

#' Count a page a knit starts: grid's `before.grid.newpage` hook
#'
#' @return NULL (invisible)
#' @keywords internal
knit_before_grid_newpage <- function() {
  if (knit_figures_active()) {
    .maidr_knit_figures$page <- .maidr_knit_figures$page + 1L
  }
  invisible(NULL)
}

#' Count the pages of a knit, from now on
#'
#' Each hook is set once; [maidr_off()] removes them
#' (`remove_knit_page_hooks()`).
#'
#' @return NULL (invisible)
#' @keywords internal
#' @noRd
set_knit_page_hooks <- function() {
  hooks <- list(
    before.plot.new = knit_before_plot_new,
    before.grid.newpage = knit_before_grid_newpage
  )
  for (name in names(hooks)) {
    if (!any(vapply(getHook(name), identical, logical(1), hooks[[name]]))) {
      setHook(name, hooks[[name]])
    }
  }
  invisible(NULL)
}

#' Stop counting the pages of a knit
#'
#' @return NULL (invisible)
#' @keywords internal
#' @noRd
remove_knit_page_hooks <- function() {
  hooks <- list(
    before.plot.new = knit_before_plot_new,
    before.grid.newpage = knit_before_grid_newpage
  )
  for (name in names(hooks)) {
    set <- getHook(name)
    keep <- !vapply(set, identical, logical(1), hooks[[name]])
    if (!all(keep)) {
      setHook(name, set[keep], action = "replace")
    }
  }
  invisible(NULL)
}

#' Forget the tokens reported so far
#'
#' What a replay the chunk made itself -- `dev.print()`, `dev.copy()`,
#' `replayPlot()` -- reported belongs to no figure. knitr saves a chunk's
#' figures only once the chunk has run, so maidr's `evaluate` hook calls this
#' when it has (`maidr_knitr_evaluate_hook()`); every chunk starts with none
#' as well.
#'
#' @return NULL (invisible)
#' @keywords internal
#' @noRd
forget_replayed_tokens <- function() {
  .maidr_knit_figures$seen <- character()
  .maidr_knit_figures$seen_page <- integer()
  invisible(NULL)
}

#' The tokens of the figure knitr has just replayed, forgotten once read
#'
#' A page replayed before the figure's own belongs to another figure, so
#' only the last page's tokens are taken. A chart drawn across several pages
#' (page `NA`) shares its last page with whatever follows it there, so a
#' figure that replays any such marker holds no one chart.
#'
#' @return The tokens, `NA` when the figure is no one chart, or none
#' @keywords internal
#' @noRd
take_replayed_tokens <- function() {
  seen <- .maidr_knit_figures$seen
  pages <- .maidr_knit_figures$seen_page
  forget_replayed_tokens()
  if (length(seen) == 0L) {
    return(character())
  }
  if (anyNA(pages)) {
    return(NA_character_)
  }
  unique(seen[pages == pages[[length(pages)]]])
}

#' Draw a ggplot2 or lattice chart as a figure of the chunk, and queue it
#'
#' The chart is drawn as its library draws it, on knitr's device, where knitr
#' records it as a figure; the plot hook then shows the chart in its place.
#' A print that composes a page -- into a viewport, or with lattice's
#' `split`, `more`, `position`, `newpage = FALSE` or `draw.in` -- draws a part
#' of a page others share, and is not marked: its figure stays knitr's.
#'
#' @param x The chart to show, as maidr reads it
#' @param draw A function of no arguments drawing it natively
#' @param mark Whether the print draws a page of its own
#' @return What `draw` returns, invisibly
#' @keywords internal
#' @noRd
draw_as_knit_figure <- function(x, draw, mark = TRUE) {
  start_page <- .maidr_knit_figures$page
  drawn <- draw()
  if (mark && knit_figures_active()) {
    token <- new_knit_token("o")
    .maidr_knit_figures$objects[[token]] <- list(plot = x, device = grDevices::dev.cur())
    mark_knit_page(token, start_page)
  }
  invisible(drawn)
}

#' The chart a figure's tokens name, or `NULL` when they name no one chart
#'
#' One queued ggplot2 or lattice chart alone, or Base R calls alone, at
#' least one of them a high-level plot, all recorded on one device. Two
#' charts on one page, a chart beside Base R calls, a token marked as drawn
#' over or as spanning pages, and calls no longer recorded are none.
#'
#' @param tokens The figure's tokens, from `take_replayed_tokens()`
#' @return `list(plot = <chart>)`, `list(device = <id>, calls = <entries>)`,
#'   or `NULL`
#' @keywords internal
#' @noRd
resolve_figure_chart <- function(tokens) {
  if (length(tokens) == 0L || anyNA(tokens)) {
    return(NULL)
  }
  objects <- intersect(tokens, names(.maidr_knit_figures$objects))
  calls <- setdiff(tokens, objects)
  if (length(objects) == 1L && length(calls) == 0L) {
    return(list(plot = .maidr_knit_figures$objects[[objects]]$plot))
  }
  if (length(objects) > 0L) {
    return(NULL)
  }
  figure <- figure_call_entries(calls)
  high <- vapply(figure$calls, function(e) identical(e$class_level, "HIGH"), logical(1))
  if (any(high)) figure else NULL
}

#' The recorded Base R calls behind a figure
#'
#' The calls whose markers the figure replayed, in the order they were
#' recorded, and the layout calls (`par()`, `layout()`) recorded on the same
#' device before the last of them: a layout call draws nothing, so it leaves
#' no marker, and it governs every page drawn after it.
#'
#' @param uids The figure's Base R tokens
#' @return `list(device, calls)`, or `NULL` unless every token is a call
#'   recorded on one device
#' @keywords internal
#' @noRd
figure_call_entries <- function(uids) {
  for (key in names(.maidr_base_r_session$devices)) {
    calls <- .maidr_base_r_session$devices[[key]]$calls
    ids <- vapply(calls, function(e) e$uid %||% NA_character_, character(1))
    on_page <- which(ids %in% uids)
    if (length(on_page) == 0L) {
      next
    }
    if (length(on_page) != length(uids)) {
      return(NULL)
    }
    layout <- which(vapply(calls, function(e) identical(e$class_level, "LAYOUT"), logical(1)))
    keep <- sort(c(on_page, layout[layout < max(on_page)]))
    return(list(device = as.integer(key), calls = calls[keep]))
  }
  NULL
}

#' Evaluate code with a figure's calls as its device's recorded calls
#'
#' Every reader of Base R calls -- the orchestrator, the fallback picture --
#' reads the current device's; this makes the figure's device current and
#' lends it the figure's calls alone, then puts back both.
#'
#' @param device The device the calls were recorded on
#' @param calls The figure's calls
#' @param code The code, evaluated here
#' @return What `code` evaluates to
#' @keywords internal
#' @noRd
with_figure_calls <- function(device, calls, code) {
  previous <- grDevices::dev.cur()
  if (device != previous && device %in% grDevices::dev.list()) {
    grDevices::dev.set(device)
    on.exit(if (previous %in% grDevices::dev.list()) grDevices::dev.set(previous), add = TRUE)
  }
  key <- as.character(grDevices::dev.cur())
  saved <- .maidr_base_r_session$devices[[key]]
  .maidr_base_r_session$devices[[key]] <- list(
    device_id = grDevices::dev.cur(),
    calls = calls,
    metadata = list(created = Sys.time(), call_count = length(calls))
  )
  on.exit(.maidr_base_r_session$devices[[key]] <- saved, add = TRUE)
  force(code)
}

#' A figure's chart as the document's output, or `NULL` to keep knitr's
#'
#' Inline, or in an iframe outside a page (`knitr_chart_output()`). A chart
#' maidr cannot read, whose build fails, or whose layers hold no data at all
#' is left as knitr's own figure, which keeps its caption and alt text.
#'
#' @param chart From `resolve_figure_chart()`
#' @param options The figure's chunk options
#' @return Character string, or `NULL`
#' @keywords internal
#' @noRd
render_figure_chart <- function(chart, options) {
  # Charts maidr draws while it renders are no figures of the chunk.
  .maidr_knit_figures$rendering <- TRUE
  on.exit(.maidr_knit_figures$rendering <- FALSE, add = TRUE)
  build <- function(plot) {
    system <- if (is.null(plot)) {
      "base_r"
    } else if (inherits(plot, "trellis")) {
      "lattice"
    } else {
      "ggplot2"
    }
    orchestrator <- get_global_registry()$get_adapter(system)$create_orchestrator(plot)
    if (orchestrator$should_fallback()) {
      return(NULL)
    }
    create_maidr_html(plot, shiny = TRUE, orchestrator = orchestrator)
  }
  content <- tryCatch(
    if (is.null(chart$plot)) {
      with_figure_calls(chart$device, chart$calls, build(NULL))
    } else {
      build(chart$plot)
    },
    error = function(e) NULL
  )
  if (is.null(content) || !maidr_chart_has_data(content)) {
    return(NULL)
  }
  knitr_chart_output(content, options, figure = TRUE)
}

#' Whether a chart's maidr-data holds any data
#'
#' A chart maidr could not build is a picture in place of the svg, with no
#' maidr-data; a chart whose every layer is empty -- `plot(lm_fit)` under
#' `par(mfrow = )` reads as one empty point layer -- would give a reader
#' nothing where the figure shows four plots.
#'
#' @param content The chart, from `create_maidr_html(shiny = TRUE)`
#' @return Logical
#' @keywords internal
#' @noRd
maidr_chart_has_data <- function(content) {
  json <- tryCatch(
    xml2::xml_attr(
      xml2::read_xml(as.character(content), options = c("HUGE", "NOBLANKS")),
      "maidr-data"
    ),
    error = function(e) NA_character_
  )
  data <- if (!is.na(json)) tryCatch(jsonlite::parse_json(json), error = function(e) NULL)
  for (row in data$subplots) {
    for (cell in row) {
      for (layer in cell$layers) {
        if (length(unlist(layer$data, use.names = FALSE)) > 0L) {
          return(TRUE)
        }
      }
    }
  }
  FALSE
}
