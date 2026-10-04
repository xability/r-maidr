#' Enable MAIDR Plot Interception
#'
#' Turns on the accessible rendering of ggplot2, lattice and Base R plots,
#' and installs the knitr hooks that an R Markdown or Quarto document needs.
#'
#' Interception is on by default after `library(maidr)`: printing a ggplot2
#' or lattice object opens it in the MAIDR viewer, and Base R plotting calls
#' are recorded until [show()] is called. lattice is reached through its own
#' hook, `lattice.options(print.function = )`, which maidr sets once lattice's
#' namespace is loaded; a print function set before is kept, and draws the
#' prints maidr leaves to lattice.
#'
#' In an R Markdown or Quarto document, `library(maidr)` is enough: the
#' first plot the document draws installs the knitr hooks that make every
#' plot of it an accessible chart, in each render of a session. Calling
#' `maidr_on()` yourself is needed after [maidr_off()], to start again; in a
#' document, it installs the hooks at once.
#'
#' In HTML output the charts are part of the page, which loads maidr.js once
#' for all of them, and the static figures of a chunk are recorded with
#' svglite rather than knitr's default png (`maidr.knitr_dev` in
#' [maidr-options] turns that off). A chunk can draw several charts --
#' `print(p)` in a loop, several Base R charts -- and each takes the place of
#' its own figure; a figure maidr cannot read as one chart stays knitr's
#' image. HTML that cannot hold a chart in the page, such as an HTML
#' fragment, EPUB or xaringan, shows each chart in a frame of its own. In
#' PDF, Word or Markdown output the plots are knitr's figures, as without
#' maidr. A chart a document draws never opens the viewer; an explicit
#' [show()] still does.
#'
#' A chunk cached with `cache = TRUE` brings its charts back from knitr's
#' cache. One cached with `cache = 1` or `cache = 2` shows them only when its
#' code runs: rendered again from the cache, its figures are knitr's static
#' images, since the charts they were drawn from are not cached with them.
#'
#' @return Invisible TRUE on success
#' @examples
#' \donttest{
#' library(maidr)
#'
#' # Enable interception (on by default after library(maidr))
#' maidr_on()
#'
#' # Now all plots render as accessible MAIDR widgets
#' library(ggplot2)
#' ggplot(mtcars, aes(x = factor(cyl))) +
#'   geom_bar()
#'
#' barplot(table(mtcars$cyl))
#' }
#' @seealso [maidr_off()] to disable MAIDR rendering
#' @export
maidr_on <- function() {
  # Enable options
  options(maidr.auto_show = TRUE)
  options(maidr.base_r = TRUE)
  options(maidr.ggplot2 = TRUE)
  options(maidr.lattice = TRUE)

  # Enable Base R function patching
  initialize_base_r_patching()

  # Register custom print.ggplot for interactive sessions
  tryCatch(
    register_ggplot2_print_method(),
    error = function(e) NULL
  )

  # And lattice's print hook, when lattice is loaded; its onLoad hook sets
  # it when lattice loads later.
  tryCatch(
    register_lattice_print_method(),
    error = function(e) NULL
  )

  # The knit_print methods for ggplot2 and lattice charts are registered
  # when maidr loads. These two hide what hist() and density() return, whose
  # charts the plot hook shows, and are registered only from here: a
  # density(x) printed for its numbers is not hidden because maidr is loaded.
  if (requireNamespace("knitr", quietly = TRUE)) {
    registerS3method(
      "knit_print",
      "histogram",
      knit_print.histogram,
      envir = asNamespace("knitr")
    )

    registerS3method(
      "knit_print",
      "density",
      knit_print.density,
      envir = asNamespace("knitr")
    )
  }

  # Store state
  .maidr_knitr_state$enabled <- TRUE

  # The hooks belong to the knit, which puts them back when it ends: they are
  # installed into the one running, if any.
  ensure_knitr_integration()

  invisible(TRUE)
}

#' Disable MAIDR Plot Interception
#'
#' Disables automatic MAIDR rendering and restores normal plot behavior.
#' After calling this, Base R plots display in the standard graphics window,
#' ggplot2 objects render with the default ggplot2 method, and lattice charts
#' print as lattice draws them: `lattice.options(print.function = )` is set
#' back to what it was before maidr set it. In an R Markdown or Quarto
#' document, the chunks after it are knitted as they would be without maidr,
#' and maidr's knitr hooks are taken out until [maidr_on()].
#'
#' @return Invisible TRUE on success
#' @seealso [maidr_on()] to enable MAIDR rendering
#' @export
maidr_off <- function() {
  # Disable options
  options(maidr.auto_show = FALSE)

  # Deactivate Base R patching (wrappers pass through to originals)
  restore_original_functions()

  # Cancel any pending auto-show callbacks
  cancel_auto_show()

  # Close any lingering maidr temp device to avoid stale device state
  tryCatch(
    close_maidr_temp_device(),
    error = function(e) NULL
  )

  # Restore original print.ggplot method
  tryCatch(
    restore_ggplot2_print_method(),
    error = function(e) NULL
  )

  # And the print function lattice had before
  tryCatch(
    restore_lattice_print_method(),
    error = function(e) NULL
  )

  # Take the knitr hooks out of the running knit, or out of the session a
  # plain knitr::knit() left them in.
  uninstall_knitr_integration()

  # Update state
  .maidr_knitr_state$enabled <- FALSE

  invisible(TRUE)
}

#' Check if MAIDR RMarkdown Mode is Enabled
#'
#' @return Logical indicating if MAIDR mode is active
#' @keywords internal
is_maidr_on <- function() {
  isTRUE(.maidr_knitr_state$enabled)
}

#' Custom knit_print Method for ggplot Objects
#'
#' Makes a ggplot object a chunk returns an accessible MAIDR chart: inline in
#' an HTML page, in its own iframe in other HTML output (see
#' `knitr_chart_output()`). In any other output format (PDF, Word, ...) the
#' chart is drawn by ggplot2 and becomes knitr's figure.
#'
#' A chart knitr prints for a chunk is one of the chunk's figures: ggplot2
#' draws it on the chunk's device, and the plot hook shows the chart in place
#' of the figure (see `draw_as_knit_figure()`), so knitr numbers, captions,
#' keeps and holds it with the chunk's other figures, as it would without
#' maidr. A chart maidr cannot read stays that figure. One the chunk's code
#' asks `knit_print()` for itself, with no chunk options -- as
#' `cat(knit_print(p))` in a `results = "asis"` loop does -- is returned as
#' the chart's Markdown, and as an inline image when MAIDR cannot read it.
#'
#' Registered for knitr when maidr loads, so `library(maidr)` is all a
#' document needs; it installs maidr into the running knit as well.
#'
#' @param x A ggplot object
#' @param options Chunk options from knitr
#' @param ... Additional arguments (ignored)
#' @return A knit_asis object holding the chart, or `NULL` (invisible) when
#'   the chart is drawn natively
#' @exportS3Method knitr::knit_print
#' @keywords internal
knit_print.ggplot <- function(x, options = list(), ...) {
  # Honour maidr_off(), which cannot take a registered method out: render
  # with the original ggplot2 print method when disabled.
  if (!is_ggplot2_enabled()) {
    print_ggplot_natively(x)
    return(invisible(NULL))
  }

  ensure_knitr_integration()

  if (!is_html_output()) {
    # For PDF/EPUB/LaTeX: let knitr handle the plot natively. Use the
    # ORIGINAL ggplot2 print method: plain print(x) would dispatch to
    # maidr's own print.ggplot override.
    print_ggplot_natively(x)
    return(invisible(NULL))
  }
  if (!missing(options) && knit_print_draws_figure(...)) {
    draw_as_knit_figure(x, function() print_ggplot_natively(x))
    return(invisible(NULL))
  }
  if (identical(options$fig.show, "hide")) {
    return(knitr::asis_output(""))
  }

  # Create orchestrator ONCE and reuse it
  registry <- get_global_registry()
  adapter <- registry$get_adapter("ggplot2")
  orchestrator <- adapter$create_orchestrator(x)

  if (orchestrator$should_fallback()) {
    # For fallback/unsupported plots in HTML: use inline image (no iframe needed)
    img_html <- create_inline_image(x)
    return(knitr::asis_output(img_html))
  }

  # Get content using the SAME orchestrator (avoid creating another)
  content <- create_maidr_html(x, shiny = TRUE, orchestrator = orchestrator)

  knitr_chart_asis(knitr_chart_output(content, options))
}

#' Custom knit_print Method for lattice (trellis) Objects
#'
#' Converts a trellis object a chunk returns to an accessible MAIDR chart,
#' as \code{knit_print.ggplot()} does for a ggplot object: inline in an HTML
#' page, in its own iframe in other HTML output, and as lattice draws it in
#' any other output format. A chart knitr prints for a chunk is one of the
#' chunk's figures, drawn by lattice, and the chart is shown in its place --
#' unless lattice draws it onto a page a \code{print(more = TRUE)} left open,
#' whose figure stays knitr's. One the chunk's code asks \code{knit_print()}
#' for itself is returned as the chart's Markdown, or as an inline image
#' when the chart cannot be read.
#'
#' A chart the chunk prints itself -- \code{print(p)}, lattice's idiom for a
#' chart inside a loop or a function -- does not reach this method, since
#' knitr does not route an explicit print through \code{knit_print}; it is
#' a figure of the chunk all the same.
#'
#' @param x A trellis object
#' @param options Chunk options from knitr
#' @param ... Additional arguments (ignored)
#' @return A knit_asis object holding the chart, or `NULL` (invisible) when
#'   the chart is drawn natively
#' @exportS3Method knitr::knit_print
#' @keywords internal
knit_print.trellis <- function(x, options = list(), ...) {
  # Honour maidr_off(), which cannot take a registered method out, and draw
  # with lattice itself: a plain print() would go through MAIDR's own print
  # hook.
  if (!is_lattice_enabled()) {
    print_trellis_natively(x)
    return(invisible(NULL))
  }

  ensure_knitr_integration()

  if (!is_html_output()) {
    print_trellis_natively(x)
    return(invisible(NULL))
  }
  if (!missing(options) && knit_print_draws_figure(...)) {
    own_page <- !lattice_print_composes(list(), x$plot.args) && !lattice_page_open()
    draw_as_knit_figure(x, function() print_trellis_natively(x), mark = own_page)
    return(invisible(NULL))
  }
  if (identical(options$fig.show, "hide")) {
    return(knitr::asis_output(""))
  }

  orchestrator <- get_global_registry()$get_adapter("lattice")$create_orchestrator(x)

  if (orchestrator$should_fallback()) {
    img_html <- create_inline_image(x)
    return(knitr::asis_output(img_html))
  }

  content <- create_maidr_html(x, shiny = TRUE, orchestrator = orchestrator)
  knitr_chart_asis(knitr_chart_output(content, options))
}

#' A chart `knit_print()` returns, as knitr's `asis` output
#'
#' An inline chart carries the page's dependencies with it: no chunk hook
#' runs for the value of inline code (`` `r p` ``), which knitr adds the
#' meta of an `asis` value for all the same. A chunk's charts declare them
#' through maidr's chunk hook as well (`maidr_knitr_chunk_hook()`).
#'
#' @param out The chart's output, from `knitr_chart_output()`
#' @return A `knit_asis` object
#' @keywords internal
#' @noRd
knitr_chart_asis <- function(out) {
  inline <- any(grepl("data-maidr-knitr=", out, fixed = TRUE))
  knitr::asis_output(out, meta = if (inline) maidr_knitr_dependencies())
}

#' Whether a chart knitr prints for a chunk is drawn as one of its figures
#'
#' Wherever the plot hook shows a figure's chart (`knit_figures_active()`),
#' except for a value of inline code, which is no figure.
#'
#' @param ... The arguments `knit_print()` was given besides the chart and
#'   the chunk options
#' @return Logical
#' @keywords internal
#' @noRd
knit_print_draws_figure <- function(...) {
  !isTRUE(list(...)$inline) && knit_figures_active()
}

#' Custom knit_print Method for histogram Objects
#'
#' Suppresses the default printing of histogram return values in RMarkdown.
#' The plot is already rendered via the plot hook; this prevents the
#' histogram object structure from being printed as text output.
#'
#' @param x A histogram object (from hist())
#' @param options Chunk options from knitr
#' @param ... Additional arguments (ignored)
#' @return An invisible empty string
#' @keywords internal
knit_print.histogram <- function(x, options = list(), ...) {
  # Only suppress while MAIDR interception is active; after maidr_off()
  # the user expects the normal text representation back.
  if (!is_maidr_enabled()) {
    return(knitr::normal_print(x))
  }
  # Return invisible empty output to suppress printing
  invisible(knitr::asis_output(""))
}

#' Custom knit_print Method for density Objects
#'
#' Suppresses the default printing of density return values in RMarkdown.
#' The density() function is not patched (it's in stats, not graphics),
#' so we need this method to suppress its output.
#'
#' @param x A density object (from density())
#' @param options Chunk options from knitr
#' @param ... Additional arguments (ignored)
#' @return An invisible empty string
#' @keywords internal
knit_print.density <- function(x, options = list(), ...) {
  # Only suppress while MAIDR interception is active; after maidr_off()
  # the user expects the normal text representation back.
  if (!is_maidr_enabled()) {
    return(knitr::normal_print(x))
  }
  invisible(knitr::asis_output(""))
}

#' Print a ggplot with the original (non-MAIDR) print method
#'
#' The print method `print()` would find without MAIDR: that of the chart's
#' own class when it has one ahead of ggplot2's -- a patchwork's, which
#' draws every plot of it where ggplot2's draws the last alone -- and
#' ggplot2's otherwise.
#'
#' @param x A ggplot object
#' @return NULL (invisible)
#' @keywords internal
print_ggplot_natively <- function(x) {
  method <- NULL
  for (class in class(x)) {
    method <- utils::getS3method("print", class, optional = TRUE)
    if (!is.null(method)) {
      break
    }
  }
  if (is.null(method) || identical(method, maidr_print_ggplot)) {
    method <- .maidr_ggplot_state$original_print_ggplot
  }
  if (!is.null(method)) {
    method(x)
  } else {
    print(x)
  }
  invisible(NULL)
}

#' Create MAIDR Widget for knitr (Internal)
#'
#' Internal function to create a MAIDR widget from either ggplot or Base R plots.
#'
#' @param plot A ggplot object or NULL for Base R
#' @return An htmlwidget object
#' @keywords internal
create_maidr_widget_internal <- function(plot = NULL) {
  # Get SVG content using existing infrastructure
  svg_content <- create_maidr_html(plot, shiny = TRUE)

  # Use centralized MAIDR dependencies (local files with CDN fallback)
  maidr_deps <- maidr_html_dependencies()

  htmlwidgets::createWidget(
    name = "maidr",
    x = list(svg_content = as.character(svg_content)),
    width = NULL,
    height = NULL,
    elementId = NULL,
    dependencies = maidr_deps,
    sizingPolicy = htmlwidgets::sizingPolicy(
      browser.fill = TRUE,
      browser.padding = 0,
      defaultWidth = "100%",
      defaultHeight = "auto",
      viewer.fill = FALSE,
      viewer.padding = 5,
      knitr.figure = FALSE,
      knitr.defaultWidth = "100%",
      knitr.defaultHeight = "400px"
    )
  )
}

#' knitr Plot Hook
#'
#' Shows the chart a figure holds in place of the figure file knitr saved:
#' inline in an HTML page, in its own iframe in other HTML output (see
#' `knitr_chart_output()`). The chart is the one the figure's page carries
#' the marker of (see knitr_figure_map.R): a ggplot2 or lattice chart the
#' chunk printed, or the Base R calls drawn on the page. Any other figure --
#' no chart, two charts or a chart something else was drawn over, a chart
#' maidr cannot read -- and every figure of an animation or of any other
#' output format (PDF, Word, ...), is left to the hook maidr's was installed
#' over, which keeps its caption and alt text. A wrong chart is never shown.
#'
#' @param x The plot file path from knitr
#' @param options Chunk options, reduced to the figure's own
#' @param original The plot hook maidr's was installed over; knitr's
#'   Markdown hook when `NULL`
#' @return The figure's Markdown or HTML
#' @keywords internal
maidr_plot_hook <- function(x, options, original = NULL) {
  tokens <- take_replayed_tokens()
  shown <- length(tokens) > 0L && is_html_output() &&
    !identical(options$fig.show, "animate")
  chart <- if (shown) resolve_figure_chart(tokens)
  if (!is.null(chart)) {
    options$maidr.figure.id <- quarto_figure_id(x, options, original)
  }
  out <- if (!is.null(chart)) render_figure_chart(chart, options)
  if (is.null(out)) {
    return(call_original_plot_hook(x, options, original))
  }
  out
}

#' Wrap a chart in its iframe for a knitted document
#'
#' For HTML output that cannot show a chart inline (see
#' `knitr_chart_output()`), and for a chart that could not be. Online, the
#' frame loads maidr.js from the CDN, and the document is given
#' its own copy of the bundle ([maidr_page_bundle_dependency()]) for the frame
#' to fall back on. The frame's document sits in a `srcdoc` attribute, where
#' R Markdown's `self_contained` and Quarto's `embed-resources` cannot reach
#' its `<script src>`; the copy is what they embed instead, once per document
#' however many charts it has, so a self-contained document's charts work
#' offline. Offline at render time, each frame carries the bundle inline, as
#' before.
#'
#' @param content The chart's SVG content, from [create_maidr_html()]
#' @return Character string of iframe HTML
#' @keywords internal
create_knitr_iframe <- function(content) {
  use_cdn <- maidr_internet_available()
  if (use_cdn) {
    knitr::knit_meta_add(list(maidr_page_bundle_dependency()))
  }

  create_maidr_iframe(
    svg_content = content,
    width = "100%",
    height = "450px",
    use_cdn = use_cdn,
    page_fallback = use_cdn
  )
}

#' Delegate to the plot hook maidr's was installed over
#'
#' Falls back to knitr's markdown hook only when there is none.
#'
#' @param x The plot file path from knitr
#' @param options Chunk options
#' @param original The plot hook maidr's was installed over
#' @return The hook's output
#' @keywords internal
call_original_plot_hook <- function(x, options, original = NULL) {
  if (is.function(original)) {
    return(original(x, options))
  }
  knitr::hook_plot_md(x, options)
}

# Internal state for knitr integration: whether maidr_on() was called last
# (rather than maidr_off()), and the label and count of the charts of the
# chunk being knitted (knitr_chart_index()).
.maidr_knitr_state <- new.env(parent = emptyenv())
.maidr_knitr_state$enabled <- FALSE
.maidr_knitr_state$chart_label <- NULL
.maidr_knitr_state$chart_count <- 0L

#' Check if current knitr output format is HTML
#'
#' Detects whether the current RMarkdown document is being rendered to HTML
#' format (html_document, bookdown, etc.) vs non-HTML formats (pdf, etc.)
#'
#' Markdown output (`github_document`, `md_document`, `knitr::knit()` of an
#' `.Rmd`), which knitr also counts as HTML, is not: GitHub and most Markdown
#' viewers drop an iframe, and rmarkdown refuses the dependency a frame
#' brings, so a chart in one was either lost or stopped the render. Its
#' charts are drawn as their libraries draw them, as knitr's figures.
#'
#' @return TRUE if rendering to HTML, FALSE otherwise
#' @keywords internal
is_html_output <- function() {
  # Use knitr's built-in detection if available

  if (requireNamespace("knitr", quietly = TRUE)) {
    # knitr::is_html_output() checks the current output format; it folds
    # every markdown_* variant into "markdown" before it compares.
    if (exists("is_html_output", where = asNamespace("knitr"))) {
      return(knitr::is_html_output(excludes = c("markdown", "gfm")))
    }

    # Fallback: check pandoc output format
    pandoc_to <- knitr::opts_knit$get("rmarkdown.pandoc.to")
    if (!is.null(pandoc_to)) {
      html_formats <- c("html", "html4", "html5", "revealjs", "s5", "slideous", "slidy")
      return(pandoc_to %in% html_formats || grepl("^html", pandoc_to))
    }
  }

  # Default to TRUE (assume HTML) if we can't detect

  TRUE
}

#' Create inline image HTML for non-iframe rendering
#'
#' Creates a simple img tag for a chart MAIDR cannot read, when the chunk's
#' code asks `knit_print()` for it itself (see [knit_print.ggplot()]); a
#' chart knitr prints for a chunk stays knitr's own figure instead.
#'
#' @param plot A ggplot object or NULL for Base R
#' @param width Width for the image container
#' @param height Height for the image container
#' @return Character string of HTML with img tag
#' @keywords internal
create_inline_image <- function(plot = NULL, width = "100%", height = "auto") {
  # The format the caller configured through `maidr_set_fallback()`.
  img_data <- create_fallback_image(plot, format = get_fallback_format())

  # Create simple inline image HTML
  img_html <- sprintf(
    '<div style="text-align: center; width: %s;"><img src="%s" alt="Plot" style="max-width: 100%%; height: %s;" /></div>',
    width,
    img_data,
    height
  )

  img_html
}
