# Charts shown inline in a knitted HTML page.
#
# A chart used to reach an R Markdown or Quarto page in an iframe of its own,
# each frame carrying or fetching its own copy of maidr.js. A page with many
# charts then held as many copies of the bundle, and a self-contained one was
# that many megabytes larger. In HTML output that pandoc writes, the chart is
# now the page's own <svg>, in a raw HTML block, as knitr's own `svg_code()`
# writes one; the page loads maidr.js once (`maidr_knitr_dependencies()`),
# and `knitr-inline.js` hands every chart to it. Every id of a chart is
# given a prefix of its own first (`inline_prefix_svg_ids()`), so charts
# sharing the page never reach into one another.
#
# The other outputs keep what they had: an iframe in HTML that is not a
# page pandoc writes (`.Rhtml`, an HTML fragment, EPUB, and the formats
# whose page cannot hold the raw block), and the plot as its library draws
# it in any other format, Markdown among them (see `is_html_output()`).

#' Whether a chart is shown inline in the document being knitted
#'
#' True while knitting HTML that pandoc writes as a page a browser opens:
#' `html_document` and the formats built on it, bookdown, Quarto, reveal.js,
#' ioslides, slidy, dashboards. Not for a document knitted without pandoc
#' (`.Rhtml`, or `knitr::knit()` to Markdown), nor for the outputs knitr also
#' counts as HTML: Markdown and GitHub Markdown, whose readers drop the
#' script, and EPUB. Not for an HTML fragment either, which has no `<head>`
#' for maidr.js, nor for xaringan, whose remark.js shows a raw HTML block as
#' code, nor for pagedown, whose paged.js rebuilds the page before maidr.js
#' could bind a chart in it. Those keep a chart in an iframe of its own,
#' except Markdown, which keeps the plot as its library draws it.
#'
#' @return Logical
#' @keywords internal
inline_output_ok <- function() {
  if (!isTRUE(getOption("knitr.in.progress")) || is.null(knitr::pandoc_to())) {
    return(FALSE)
  }
  # knitr folds every markdown_* variant into "markdown", and epub3 into
  # "epub", before it compares.
  if (!knitr::is_html_output(excludes = c("markdown", "gfm", "epub", "epub2"))) {
    return(FALSE)
  }
  template <- knitr_pandoc_template()
  is.null(template) ||
    !grepl("rmd/fragment/|/xaringan/|/pagedown/", gsub("\\\\", "/", template))
}

#' The pandoc template R Markdown renders the document with
#'
#' @return The template's path, or `NULL` when R Markdown names none.
#' @keywords internal
#' @noRd
knitr_pandoc_template <- function() {
  args <- as.character(knitr::opts_knit$get("rmarkdown.pandoc.args"))
  at <- which(args == "--template")
  if (length(at) > 0L && at[[1L]] < length(args)) {
    return(args[[at[[1L]] + 1L]])
  }
  joined <- grep("^--template=", args, value = TRUE)
  if (length(joined) > 0L) {
    return(sub("^--template=", "", joined[[1L]]))
  }
  NULL
}

#' The output of one chart in a knitted document
#'
#' Inline where `inline_output_ok()` allows it, in its own iframe in any
#' other HTML ([create_knitr_iframe()]), and nothing under
#' `fig.show = "hide"`. A chart that cannot be shown inline -- an id the
#' prefixing cannot scope, or any other error -- is shown in an iframe
#' instead, with one warning per document: a failure never stops the knit.
#'
#' @param content The chart's SVG, from `create_maidr_html(shiny = TRUE)`
#' @param options The chunk options
#' @param figure `TRUE` for a chart the plot hook writes in place of a
#'   figure, `FALSE` for one `knit_print()` returns
#' @return Character string: Markdown holding a raw HTML block, or the
#'   iframe's HTML
#' @keywords internal
knitr_chart_output <- function(content, options = list(), figure = FALSE) {
  if (identical(options$fig.show, "hide")) {
    return("")
  }
  if (!inline_output_ok()) {
    return(create_knitr_iframe(content))
  }
  # The chunk hook that adds the page's dependencies has to be in place by
  # the end of this chunk.
  ensure_knitr_integration()
  # A figure is numbered by knitr, which has picked its caption already.
  index <- if (figure) options$fig.cur %||% 1L else knitr_chart_index(options)
  tryCatch(
    knitr_inline_chart(content, options, index, figure = figure),
    error = function(e) {
      warn_inline_fallback(e)
      create_knitr_iframe(content)
    }
  )
}

#' Warn, once per document, that a chart is in an iframe after all
#'
#' @param error The condition that stopped the inline chart
#' @return NULL (invisible)
#' @keywords internal
#' @noRd
warn_inline_fallback <- function(error) {
  if (isTRUE(knitr::opts_knit$get("maidr.inline_warned"))) {
    return(invisible(NULL))
  }
  knitr::opts_knit$set(maidr.inline_warned = TRUE)
  warning(
    "maidr: a chart could not be shown inline and is shown in a frame of ",
    "its own instead: ", conditionMessage(error),
    call. = FALSE
  )
  invisible(NULL)
}

#' Write one chart inline into a knitted HTML page
#'
#' The chart's `<svg>`, its ids prefixed, in a `{=html}` raw block (blank
#' lines around it, so pandoc reads it as a block of its own) inside a
#' `.maidr-knitr` wrapper:
#'
#' * The svg is a named image until maidr.js has mounted the chart, and stays
#'   one when it never does: `role="img"` and an `aria-label` from `fig.alt`,
#'   else `fig.cap`, else the chart's title, else "Chart". `knitr-inline.js`
#'   removes both once maidr's own focusable element is around the chart.
#' * The maidr-data JSON is in `data-maidr-knitr`, for `knitr-inline.js` to
#'   hand to maidr.js; see that script for why it is not in `maidr-data`.
#' * The alt text (or the title, when there is no caption either) is kept
#'   in a hidden span, and the caption below the chart. maidr names the
#'   chart's focusable element itself, so `knitr-inline.js` makes both its
#'   description.
#' * A caption is a `<p class="caption">` in a wrapper of class `figure`,
#'   as knitr writes a figure, with bookdown's `(#fig:label)` before it, so
#'   a bookdown cross-reference finds it; of the figures `fig.show = "hold"`
#'   holds to the end of a chunk, only the last is captioned, as knitr
#'   captions them. Markdown in it is shown as
#'   written: the caption is inside the raw block. Quarto writes the caption
#'   of a chart `knit_print()` returns itself -- the figcaption of a
#'   cross-referenceable figure for a `fig-` label, a paragraph below the
#'   chart otherwise -- so none is written for it then; only a hidden copy
#'   of the paragraph, for the description.
#' * `fig.align` aligns the chart, and an `out.width` the author sets (not
#'   the one knitr derives for a retina figure) sets the wrapper's width,
#'   which the chart shrinks to; `fig.width` and `fig.height` are not read,
#'   since maidr draws every chart at its own size.
#'
#' `fig.cap` and `fig.alt` are evaluated by knitr only once the chunk has
#' run, so a chart `knit_print()` writes while the chunk runs can see them
#' as unevaluated expressions; such an option is evaluated here. Of several
#' captions, the chunk's `index`-th chart takes the `index`-th, as knitr's
#' figures do; a figure's options hold its own caption alone already.
#'
#' @param svg The chart's SVG, from `create_maidr_html(shiny = TRUE)`
#' @param options The chunk options
#' @param index Which of the chunk's charts this one is, from 1
#' @param figure `TRUE` for a chart the plot hook writes in place of a
#'   figure, `FALSE` for one `knit_print()` returns
#' @return Character string of Markdown
#' @keywords internal
knitr_inline_chart <- function(svg, options = list(), index = 1L, figure = FALSE) {
  prefix <- inline_id_prefix()
  doc <- inline_prefix_svg_document(svg, prefix)
  root <- xml2::xml_root(doc)
  json <- xml2::xml_attr(root, "maidr-data")

  captions <- knitr_chart_option(options, "fig.cap")
  caption <- pick_chart_text(captions, index)
  alt <- pick_chart_text(knitr_chart_option(options, "fig.alt"), index)
  title <- if (is.null(alt) && is.null(caption)) knitr_chart_title(json)
  name <- alt %||% caption %||% title %||% "Chart"
  description <- alt %||% (if (is.null(caption)) title)
  if (identical(description, caption)) {
    description <- NULL
  }
  # Quarto captions a chart knit_print() returns, not one in place of a
  # figure, and labels its caption for the chart only in a fig- float.
  quarto_caption <- !figure && !is.null(knitr::opts_knit$get("quarto.version"))
  hidden_caption <- if (quarto_caption && !startsWith(options$label %||% "", "fig-")) caption
  # knitr captions the figures it holds to the end of a chunk once, below
  # the last of them.
  held <- figure && identical(options$fig.show, "hold") &&
    isTRUE(options$fig.cur < options$fig.num)
  if (quarto_caption || held) {
    caption <- NULL
  }

  classes <- c(stats::na.omit(xml2::xml_attr(root, "class")), "maidr-knitr-svg")
  xml2::xml_attr(root, "class") <- paste(classes, collapse = " ")
  xml2::xml_attr(root, "role") <- "img"
  xml2::xml_attr(root, "aria-label") <- name
  xml2::xml_attr(root, "maidr-data") <- NULL
  xml2::xml_attr(root, "data-maidr-knitr") <- json

  align <- options$fig.align
  wrapper_class <- c(
    if (!is.null(caption)) "figure",
    "maidr-knitr",
    if (length(align) == 1L && align %in% c("left", "center", "right")) {
      paste0("maidr-knitr-", align)
    }
  )
  # knitr sets out.width itself for a retina figure; only the author's is
  # the chart's.
  authored <- chunk_sets_option(options, "out.width") ||
    !is.null(knitr::opts_chunk$get("out.width"))
  width <- if (authored) knitr_chart_width(options$out.width, index)

  html <- c(
    sprintf(
      '<div class="%s"%s>',
      paste(wrapper_class, collapse = " "),
      if (is.null(width)) "" else sprintf(' style="width: %s;"', width)
    ),
    inline_svg_markup(doc),
    if (!is.null(description)) {
      sprintf(
        '<span class="maidr-knitr-alt" id="%salt" hidden>%s</span>',
        prefix, htmltools::htmlEscape(description)
      )
    },
    if (!is.null(caption)) {
      sprintf(
        '<p class="caption maidr-knitr-caption" id="%scaption">%s%s</p>',
        prefix,
        bookdown_figure_label(options, index, length(captions), figure),
        htmltools::htmlEscape(caption)
      )
    },
    if (!is.null(hidden_caption)) {
      sprintf(
        '<span class="maidr-knitr-caption" id="%scaption" hidden>%s</span>',
        prefix, htmltools::htmlEscape(hidden_caption)
      )
    },
    "</div>"
  )
  paste0("\n\n", paste(xfun::fenced_block(html, attrs = "=html"), collapse = "\n"), "\n\n")
}

#' A chunk option that knitr may not have evaluated yet
#'
#' @param options The chunk options
#' @param name The option's name
#' @return The option's value, evaluated in knitr's environment when it is
#'   still an expression; `NULL` when it cannot be evaluated yet, because it
#'   refers to something the chunk has not made yet.
#' @keywords internal
#' @noRd
knitr_chart_option <- function(options, name) {
  value <- options[[name]]
  if (is.language(value)) {
    value <- tryCatch(eval(value, knitr::knit_global()), error = function(e) NULL)
  }
  value
}

#' The text one chart takes from a chunk option
#'
#' @param value The option's value, as `knitr_chart_option()` returns it
#' @param index Which of the chunk's charts this is, from 1
#' @return One string, or `NULL` for none
#' @keywords internal
#' @noRd
pick_chart_text <- function(value, index) {
  if (length(value) == 0L) {
    return(NULL)
  }
  value <- value[[(index - 1L) %% length(value) + 1L]]
  if (length(value) == 0L || anyNA(value)) {
    return(NULL)
  }
  text <- paste(as.character(value), collapse = " ")
  if (nzchar(trimws(text))) text else NULL
}

#' The title of a chart, from its maidr-data
#'
#' @param json The maidr-data JSON
#' @return The title, or `NULL` when it has none
#' @keywords internal
#' @noRd
knitr_chart_title <- function(json) {
  title <- tryCatch(jsonlite::parse_json(json)$title, error = function(e) NULL)
  pick_chart_text(if (is.character(title)) title, 1L)
}

#' bookdown's label for a captioned chart
#'
#' bookdown numbers a figure, and resolves a reference to it, by the
#' `(#fig:label)` at the start of its caption; written in a raw block it is
#' not escaped. A chart in place of a figure is labelled as knitr labels the
#' figure: `label-1`, `label-2`, ... when the chunk has several figures shown
#' where they are drawn (`fig.show = "asis"`), `label` otherwise. Of the
#' charts `knit_print()` writes, the second and later are numbered, and all
#' of them when the chunk gives several captions.
#'
#' @param options The chunk options
#' @param index Which of the chunk's charts this is, from 1
#' @param count How many captions the chunk gives
#' @param figure Whether the chart is in place of a figure
#' @return The label and a space, or `""` outside bookdown
#' @keywords internal
#' @noRd
bookdown_figure_label <- function(options, index, count, figure = FALSE) {
  if (!isTRUE(knitr::opts_knit$get("bookdown.internal.label"))) {
    return("")
  }
  numbered <- if (figure) {
    isTRUE(options$fig.num > 1L) && identical(options$fig.show, "asis")
  } else {
    index > 1L || count > 1L
  }
  suffix <- if (numbered) paste0("-", index) else ""
  sprintf("(#%s%s%s) ", options$fig.lp %||% "fig:", options$label %||% "", suffix)
}

#' The CSS width a chart's wrapper takes from `out.width`
#'
#' A number is pixels, as knitr reads it for HTML; a string is used when it
#' is one CSS length or percentage. Anything else (LaTeX's `\linewidth`) is
#' not used.
#'
#' @param out_width The `out.width` chunk option
#' @param index Which of the chunk's charts this is, from 1
#' @return The width, or `NULL`
#' @keywords internal
#' @noRd
knitr_chart_width <- function(out_width, index) {
  width <- pick_chart_text(out_width, index)
  if (is.null(width)) {
    return(NULL)
  }
  width <- trimws(width)
  if (grepl("^[0-9]*\\.?[0-9]+$", width)) {
    return(paste0(width, "px"))
  }
  units <- "px|%|em|rem|ex|ch|vw|vh|vmin|vmax|cm|mm|in|pt|pc"
  if (grepl(sprintf("^[0-9]*\\.?[0-9]+(%s)$", units), width)) width else NULL
}

#' Count the charts of the chunk being knitted
#'
#' The counter starts again at each chunk: it is reset when a chunk ends
#' (by maidr's chunk hook) and when a chunk with another label shows a
#' chart.
#'
#' @param options The chunk options
#' @return Which of the chunk's charts this one is, from 1
#' @keywords internal
#' @noRd
knitr_chart_index <- function(options) {
  label <- options$label %||% ""
  state <- .maidr_knitr_state
  if (!identical(state$chart_label, label)) {
    state$chart_label <- label
    state$chart_count <- 0L
  }
  state$chart_count <- state$chart_count + 1L
  state$chart_count
}

#' Start counting a chunk's charts again
#'
#' @return NULL (invisible)
#' @keywords internal
#' @noRd
reset_knitr_chart_index <- function() {
  .maidr_knitr_state$chart_label <- NULL
  .maidr_knitr_state$chart_count <- 0L
  invisible(NULL)
}
