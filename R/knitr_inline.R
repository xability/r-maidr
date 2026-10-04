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
#' Inline where `inline_output_ok()` allows it, and in its own iframe in any
#' other HTML ([create_knitr_iframe()]). A chart that cannot be shown inline
#' -- an id the prefixing cannot scope, or any other error -- is shown in an
#' iframe instead, with one warning per document: a failure never stops the
#' knit.
#'
#' @param content The chart's SVG, from `create_maidr_html(shiny = TRUE)`
#' @param options The chunk options
#' @param figure `TRUE` for a chart the plot hook writes in place of a
#'   figure, `FALSE` for one `knit_print()` returns
#' @return Character string: Markdown holding a raw HTML block, or the
#'   iframe's HTML
#' @keywords internal
knitr_chart_output <- function(content, options = list(), figure = FALSE) {
  if (!inline_output_ok()) {
    return(create_knitr_iframe(content))
  }
  # The chunk hook that adds the page's dependencies has to be in place by
  # the end of this chunk.
  ensure_knitr_integration()
  index <- options$fig.cur %||% 1L
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
#'   a bookdown cross-reference finds it. Markdown in it is shown as
#'   written: the caption is inside the raw block. Of the figures
#'   `fig.show = "hold"` holds to the end of a chunk, only the last is
#'   captioned, as knitr captions them; the caption of each other one is
#'   kept as its description.
#' * A chart in place of a figure of a `fig-` chunk in Quarto is given to
#'   Quarto as the figure it numbers and captions (`quarto_figure_float()`);
#'   every other chart is captioned here.
#' * `fig.align` aligns the chart, and an `out.width` the author sets (not
#'   the one knitr derives for a retina figure) sets the wrapper's width,
#'   which the chart shrinks to; `fig.width` and `fig.height` are not read,
#'   since maidr draws every chart at its own size. The charts in place of
#'   figures `fig.show = "hold"` holds, at such a width and not aligned,
#'   sit side by side, as knitr's images do.
#'
#' A figure's options hold its own caption and alt text alone; of several,
#' as a chart `knit_print()` is asked for with a chunk's options may see,
#' the `index`-th is taken.
#'
#' @param svg The chart's SVG, from `create_maidr_html(shiny = TRUE)`
#' @param options The chunk options
#' @param index Which of the chunk's figures this one is, from 1
#' @param figure `TRUE` for a chart the plot hook writes in place of a
#'   figure, `FALSE` for one `knit_print()` returns
#' @return Character string of Markdown
#' @keywords internal
knitr_inline_chart <- function(svg, options = list(), index = 1L, figure = FALSE) {
  prefix <- inline_id_prefix()
  doc <- inline_prefix_svg_document(svg, prefix)
  root <- xml2::xml_root(doc)
  json <- xml2::xml_attr(root, "maidr-data")

  # A chart in place of a figure of a fig- chunk is made the float Quarto
  # numbers and captions (quarto_figure_float()), with the figure's
  # sub-caption, if any; any other is captioned here.
  quarto <- !is.null(knitr::opts_knit$get("quarto.version"))
  float <- figure && quarto && startsWith(options$label %||% "", "fig-")

  caption <- pick_chart_text(options$fig.cap, index)
  if (float) {
    caption <- pick_chart_text(options$fig.subcap, 1L) %||% caption
  }
  alt <- pick_chart_text(options$fig.alt, index)
  title <- if (is.null(alt) && is.null(caption)) knitr_chart_title(json)
  name <- alt %||% caption %||% title %||% "Chart"
  description <- alt %||% title
  if (identical(description, caption)) {
    description <- NULL
  }
  float_caption <- if (float) caption
  # knitr captions the figures it holds to the end of a chunk once, below
  # the last of them; the caption of one before it still describes it.
  held <- figure && identical(options$fig.show, "hold")
  last_held <- held && !isTRUE(options$fig.cur < options$fig.num)
  if (held && !last_held && !float) {
    description <- description %||% caption
  }
  if (float || (held && !last_held)) {
    caption <- NULL
  }

  classes <- c(stats::na.omit(xml2::xml_attr(root, "class")), "maidr-knitr-svg")
  xml2::xml_attr(root, "class") <- paste(classes, collapse = " ")
  xml2::xml_attr(root, "role") <- "img"
  xml2::xml_attr(root, "aria-label") <- name
  xml2::xml_attr(root, "maidr-data") <- NULL
  xml2::xml_attr(root, "data-maidr-knitr") <- json

  # knitr sets out.width itself for a retina figure; only the author's is
  # the chart's.
  authored <- chunk_sets_option(options, "out.width") ||
    !is.null(knitr::opts_chunk$get("out.width"))
  width <- if (authored) knitr_chart_width(options$out.width, index)
  align <- options$fig.align
  aligned <- length(align) == 1L && align %in% c("left", "center", "right")
  # knitr writes the figures it holds, at a width the author sets and with
  # no alignment, as images in a row; Quarto puts each in a block of its
  # own. Such charts float in a row, and the last of them ends it.
  side_by_side <- held && !quarto && !is.null(width) && !aligned
  wrapper_class <- c(
    if (!is.null(caption)) "figure",
    "maidr-knitr",
    if (side_by_side) "maidr-knitr-row",
    if (aligned) paste0("maidr-knitr-", align)
  )

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
        bookdown_figure_label(options, index),
        htmltools::htmlEscape(caption)
      )
    },
    "</div>",
    if (side_by_side && last_held) '<div class="maidr-knitr-row-end"></div>'
  )
  block <- paste(xfun::fenced_block(html, attrs = "=html"), collapse = "\n")
  if (float) {
    return(quarto_figure_float(block, options, index, float_caption))
  }
  paste0("\n\n", block, "\n\n")
}

#' A chart as the figure Quarto makes of a figure of a `fig-` chunk
#'
#' Quarto numbers a figure, resolves a reference to it and writes its
#' `<figcaption>` from a div whose id is the figure's label, holding the
#' figure and then its caption as a paragraph; its own plot hook gives an
#' image that id. The id is the one Quarto's plot hook gives the figure
#' (`quarto_figure_id()`, in `options$maidr.figure.id`), which Quarto turns
#' into the chunk's label, or `label-1`, `label-2`, ... once it has counted
#' the chunk's figures. Without one, it is the label, numbered when the
#' chunk has several figures. The caption is the figure's `fig-subcap` when
#' the chunk gives sub-captions, its `fig-cap` otherwise, and Markdown in it
#' is read. The float is in a `.cell-output-display` div, as each figure
#' Quarto's plot hook writes is.
#'
#' @param block The chart's raw HTML block
#' @param options The figure's chunk options
#' @param index Which of the chunk's figures this is, from 1
#' @param caption The figure's caption, or `NULL`
#' @return Character string of Markdown
#' @keywords internal
#' @noRd
quarto_figure_float <- function(block, options, index, caption) {
  id <- options$maidr.figure.id
  if (is.null(id)) {
    id <- options$label
    if (isTRUE(options$fig.num > 1L)) {
      id <- paste0(id, "-", index)
    }
  }
  paste0(
    "\n\n::: {.cell-output-display}\n\n::: {#", id, "}\n\n",
    block, "\n\n",
    if (!is.null(caption)) paste0(caption, "\n\n"),
    ":::\n\n:::\n\n"
  )
}

#' The id Quarto's plot hook gives a figure of a `fig-` chunk
#'
#' Quarto names the figures of a `fig-` chunk with a stand-in its chunk hook
#' replaces once the chunk's output is complete: by the chunk's label when
#' the output names one figure, and by `label-1`, `label-2`, ... in the
#' order they are written when it names several -- its own figures and the
#' outputs it makes figures of alike. A chart in place of a figure is named
#' as Quarto's hook names that figure, so that Quarto counts it with the
#' others; the hook is asked for the figure's Markdown, and the id read
#' from it.
#'
#' @param x The figure's file
#' @param options The figure's chunk options
#' @param original The plot hook maidr's was installed over
#' @return The id, or `NULL` outside a `fig-` chunk in Quarto, or when the
#'   hook's Markdown names none
#' @keywords internal
#' @noRd
quarto_figure_id <- function(x, options, original) {
  label <- options$label %||% ""
  if (is.null(knitr::opts_knit$get("quarto.version")) || !startsWith(label, "fig-")) {
    return(NULL)
  }
  out <- tryCatch(
    paste(call_original_plot_hook(x, options, original), collapse = ""),
    error = function(e) ""
  )
  at <- regexpr(paste0("{#", label), out, fixed = TRUE)
  if (at < 0L) {
    return(NULL)
  }
  sub("[ }].*$", "", substring(out, at + 2L))
}

#' The text one chart takes from a chunk option
#'
#' @param value The option's value
#' @param index Which of the chunk's figures this is, from 1
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
#' where they are drawn (`fig.show = "asis"`), `label` otherwise. A chart
#' written for no chunk label, as inline code's is, has none.
#'
#' @param options The chunk options
#' @param index Which of the chunk's figures this is, from 1
#' @return The label and a space, or `""` outside bookdown
#' @keywords internal
#' @noRd
bookdown_figure_label <- function(options, index) {
  if (!isTRUE(knitr::opts_knit$get("bookdown.internal.label")) || is.null(options$label)) {
    return("")
  }
  numbered <- isTRUE(options$fig.num > 1L) && identical(options$fig.show, "asis")
  suffix <- if (numbered) paste0("-", index) else ""
  sprintf("(#%s%s%s) ", options$fig.lp %||% "fig:", options$label, suffix)
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
