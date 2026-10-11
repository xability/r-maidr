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
# page pandoc writes (`.Rhtml`, an HTML fragment, and pagedown, whose page
# cannot hold the raw block), and the plot as its library draws it in any
# other format, Markdown, EPUB and xaringan among them (see
# `is_html_output()`).

#' Whether a chart is shown inline in the document being knitted
#'
#' True while knitting HTML that pandoc writes as a page a browser opens:
#' `html_document` and the formats built on it, bookdown, Quarto, reveal.js,
#' ioslides, slidy, dashboards. Not for a document knitted without pandoc
#' (`.Rhtml`, or `knitr::knit()` to Markdown), nor for the outputs knitr also
#' counts as HTML: Markdown and GitHub Markdown, whose readers drop the
#' script, EPUB, and xaringan, whose remark.js shows a raw HTML block as
#' text. Not for an HTML fragment either, which has no `<head>` for
#' maidr.js, nor for pagedown, whose paged.js rebuilds the page before
#' maidr.js could bind a chart in it. Markdown, EPUB and xaringan keep the
#' plot as its library draws it (`is_html_output()`); the others keep a
#' chart in an iframe of its own.
#'
#' @return Logical
#' @keywords internal
inline_output_ok <- function() {
  if (!knit_in_progress() || is.null(knitr::pandoc_to())) {
    return(FALSE)
  }
  if (!is_html_output()) {
    return(FALSE)
  }
  template <- knitr_pandoc_template()
  is.null(template) || !grepl("rmd/fragment/|/pagedown/", gsub("\\\\", "/", template))
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
#'   one when it never does: `role="img"`, named by `fig.alt`, else
#'   `fig.cap`, else the chart's title, else its kind and axes ("Bar chart of
#'   n by kind"). The name is the element that holds the text, through
#'   `aria-labelledby`, rather than a copy in `aria-label`: bookdown resolves
#'   a text reference, `(ref:label)`, in the whole page, attributes included,
#'   and the HTML it writes would end the attribute. `knitr-inline.js`
#'   removes the role and the name once maidr's own focusable element is
#'   around the chart.
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
#' * Any other chart in place of a figure in Quarto is in a
#'   `.cell-output-display` div (`quarto_output_display()`), as Quarto's
#'   plot hook writes each figure, but in a `results = "asis"` chunk, where
#'   it writes none; and its wrapper is Markdown around the raw block, which
#'   pandoc reads as a div (`quarto_chart()`), but in a chunk Quarto lays
#'   out as a panel (`quarto_lays_out()`). A dashboard makes a card of each
#'   such chunk, as of a chunk whose output is an image, and leaves the
#'   chart in it: of a chunk whose output is only a raw block, it made none,
#'   and gathered such chunks, one after another, into one card, titled by
#'   the first; and it lifts an output that is only a raw block out of its
#'   card when the text `bsli` is in it.
#' * The chart was drawn at the chunk's `fig.width` and `fig.height`
#'   (`knitr_chart_size()`), which set the room it is laid out in, on a
#'   canvas of 72 pixels to the inch that its `viewBox` keeps. It is shown at
#'   the size knitr shows the chunk's figure at: its svg's `width` and
#'   `height` are the figure's (`knitr_chart_ppi()`).
#' * An `out.width` the author sets (not the one knitr derives for a retina
#'   figure) is the wrapper's width, which the chart fills, wider than its
#'   own size or narrower; in a panel Quarto lays out, a percentage is the
#'   cell's, as Quarto makes an image's. An `out.height` sets the chart's
#'   height, and its width keeps its shape. `fig.align` aligns the chart,
#'   and the wrapper too when it is narrower than its column. A chart
#'   Quarto captions outside a float is centred unless the chunk says
#'   otherwise, as Quarto centres such a figure. Every chart still shrinks
#'   to a column narrower than itself, keeping its shape. The charts in
#'   place of figures `fig.show = "hold"` holds, at such a width and not
#'   aligned, sit side by side, as knitr's images do.
#' * In a Quarto reveal.js deck that keeps `auto-stretch`, a chart not
#'   given a height is marked `maidr-knitr-stretch`, and `knitr-inline.js`
#'   stretches it when it stands alone on its slide, as Quarto stretches a
#'   lone figure (`quarto_auto_stretch()`).
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
  if (!is.null(description)) {
    xml2::xml_attr(root, "aria-labelledby") <- paste0(prefix, "alt")
  } else if (!is.null(caption)) {
    xml2::xml_attr(root, "aria-labelledby") <- paste0(prefix, "caption")
  } else {
    xml2::xml_attr(root, "aria-label") <- alt %||% float_caption %||% knitr_chart_kind(json)
  }
  xml2::xml_attr(root, "maidr-data") <- NULL
  xml2::xml_attr(root, "data-maidr-knitr") <- json

  # Shown at the size knitr shows the figure at; drawn as it was.
  inline_display_size(root, knitr_chart_ppi(options))
  width <- knitr_chart_out_width(options, index, quarto)
  height <- knitr_chart_height(options$out.height, index)
  if (!is.null(height)) {
    xml2::xml_attr(root, "style") <- sprintf("width: %s;", inline_width_for_height(root, height))
  }
  # Quarto centres a figure it captions, unless told otherwise; a figure of
  # a fig- chunk is its own float, which it aligns itself.
  align <- knitr_chart_align(options$fig.align, quarto && !float && !is.null(caption))
  # knitr writes the figures it holds, at a width the author sets and with
  # no alignment, as images in a row; Quarto puts each in a block of its
  # own. Such charts float in a row, and the last of them ends it.
  side_by_side <- held && !quarto && !is.null(width) && is.null(align)
  # A reveal.js slide's one figure is stretched to the room left on the
  # slide (Quarto's auto-stretch); knitr-inline.js stretches a chart that
  # stands where such a figure would, but one given a height, as Quarto
  # leaves an image given one.
  stretch <- is.null(height) && quarto_stretches_figures()
  wrapper_class <- c(
    if (!is.null(caption)) "figure",
    "maidr-knitr",
    if (side_by_side) "maidr-knitr-row",
    if (!is.null(align)) paste0("maidr-knitr-", align),
    if (!is.null(width)) "maidr-knitr-sized",
    if (stretch) "maidr-knitr-stretch"
  )

  wrapper <- sprintf(
    '<div class="%s"%s>',
    paste(wrapper_class, collapse = " "),
    if (is.null(width)) "" else sprintf(' style="width: %s;"', width)
  )
  chart <- c(
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
    }
  )
  if (figure && quarto && !float && !quarto_lays_out(options)) {
    return(quarto_chart(wrapper, chart, options))
  }
  block <- raw_html_block(c(
    wrapper,
    chart,
    "</div>",
    if (side_by_side && last_held) '<div class="maidr-knitr-row-end"></div>'
  ))
  if (float) {
    return(quarto_figure_float(block, options, index, float_caption))
  }
  if (figure && quarto && !identical(options$results, "asis")) {
    return(quarto_output_display(block))
  }
  paste0("\n\n", block, "\n\n")
}

#' The CSS pixels to the inch knitr shows a chunk's figures at
#'
#' A chart is drawn on a canvas of 72 pixels to the inch (`R/chart_size.R`)
#' and shown at the size the figure it stands for would be: `fig.width` by
#' `fig.height` at this many pixels to the inch.
#'
#' * A retina figure (`fig.retina` other than 1) is shown `fig.width * dpi`
#'   pixels wide: knitr sets its `out.width` so before it multiplies the
#'   `dpi` by `fig.retina` for the file. That is the `dpi` a plot hook sees
#'   divided by `fig.retina`: 96 in Quarto's HTML formats, whose `fig-dpi`
#'   is 96, and in R Markdown's, which set `dpi = 96` (and `fig.retina = 2`
#'   but in `html_vignette`).
#' * Any other bitmap is shown a pixel to a dot, at the `dpi`; so is the
#'   `png` maidr records on svglite in place of (`maidr_chunk_device()`),
#'   which would have been one.
#' * An svg is shown at the size its file gives itself, in the units its
#'   device writes: svglite writes points, 96 pixels to the inch, and R's
#'   `svg()` with Cairo 1.18 pixels, 72 to the inch (Quarto's `fig-format:
#'   svg`). Its file is read when the plot hook names it; otherwise
#'   svglite is 96 and any other svg device 72.
#'
#' @param options The chunk options, as a plot hook sees them. Those a chart
#'   `knit_print()` was asked for with none of are the current chunk's.
#' @return One number; 72, the canvas's own, when the options carry no
#'   usable `dpi`
#' @keywords internal
#' @noRd
knitr_chart_ppi <- function(options) {
  option <- function(name) knitr_chart_option(options, name)
  dpi <- positive_number(option("dpi"))
  retina <- positive_number(option("fig.retina")) %||% 1
  if (is.null(dpi)) {
    return(72)
  }
  if (retina != 1) {
    return(dpi / retina)
  }
  dev <- as.character(option("dev"))[1L]
  if (!dev %in% c("svg", "svglite", "CairoSVG", "gridSVG") || svglite_for_png(dev, options)) {
    return(dpi)
  }
  svg_figure_ppi(option("maidr.figure.file"), positive_number(option("fig.width"))) %||%
    if (identical(dev, "svglite")) 96 else 72
}

#' One chunk option of a chart
#'
#' @param options The chunk options
#' @param name The option's name
#' @return Its value: the current chunk's when `options` carries none
#' @keywords internal
#' @noRd
knitr_chart_option <- function(options, name) {
  value <- options[[name]]
  if (is.null(value) && knit_in_progress()) knitr::opts_current$get(name) else value
}

#' Whether a chunk's svglite is the one maidr gave it in place of its `png`
#'
#' `maidr_chunk_device()` gives svglite only to a chunk that sets no device
#' of its own in a document whose device is `png`.
#'
#' @param dev The chunk's device
#' @param options The chunk options
#' @return Logical
#' @keywords internal
#' @noRd
svglite_for_png <- function(dev, options) {
  identical(dev, "svglite") && identical(knitr::opts_chunk$get("dev"), "png") &&
    !chunk_sets_option(options, "dev")
}

#' The pixels to the inch an svg figure's file shows it at
#'
#' The width its file gives itself (`svg_file_width()`) over the figure's
#' width in inches.
#'
#' @param file The figure's file, as knitr hands it to the plot hook
#' @param width The figure's width, in inches
#' @return One number, or `NULL` when the file is not an svg that can be
#'   read
#' @keywords internal
#' @noRd
svg_figure_ppi <- function(file, width) {
  pixels <- svg_file_width(file)
  if (is.null(pixels) || is.null(width)) NULL else pixels / width
}

#' The width an svg file gives itself, in CSS pixels
#'
#' Its root element's `width`, in an absolute unit or none. knitr names a
#' figure's file relative to its `base.dir`, when it has one.
#'
#' @param file The file's path
#' @return One number, or `NULL` when it is no svg, cannot be read, or
#'   gives no width in an absolute unit
#' @keywords internal
#' @noRd
svg_file_width <- function(file) {
  if (!is.character(file) || length(file) != 1L || !grepl("\\.svg$", file, ignore.case = TRUE)) {
    return(NULL)
  }
  # The root <svg> tag opens the file, after at most an XML declaration and
  # a comment; 4096 bytes hold it. Should it not be in them, no width is
  # read and the device's own rule applies (`knitr_chart_ppi()`).
  start <- tryCatch(
    readChar(knitr_figure_path(file), 4096L, useBytes = TRUE),
    error = function(e) "",
    warning = function(w) ""
  )
  tag <- regmatches(start, regexpr("<svg\\b[^>]*>", start))
  pattern <- "\\swidth\\s*=\\s*[\"']\\s*([0-9]*\\.?[0-9]+)\\s*([a-z]*)\\s*[\"']"
  found <- unlist(regmatches(tag, regexec(pattern, tag)))
  if (length(found) != 3L) {
    return(NULL)
  }
  css_pixels(as.numeric(found[[2L]]), found[[3L]])
}

#' Where a figure's file is
#'
#' @param file The file, as knitr names it: relative to its `base.dir`, when
#'   it has one
#' @return The path to read it from
#' @keywords internal
#' @noRd
knitr_figure_path <- function(file) {
  base <- knitr::opts_knit$get("base.dir")
  if (file.exists(file) || !is.character(base) || length(base) != 1L) {
    return(file)
  }
  file.path(base, file)
}

#' A length in absolute CSS units, in CSS pixels
#'
#' @param value The number
#' @param unit Its unit: px (or none), pt, pc, in, cm or mm
#' @return One number, or `NULL` for a unit that is not absolute
#' @keywords internal
#' @noRd
css_pixels <- function(value, unit) {
  per <- c(px = 1, pt = 4 / 3, pc = 16, `in` = 96, cm = 96 / 2.54, mm = 96 / 25.4)
  unit <- if (nzchar(unit)) unit else "px"
  if (!unit %in% names(per) || !is.finite(value)) {
    return(NULL)
  }
  value * per[[unit]]
}

#' One positive number, from a chunk option
#'
#' @param value The option's value; its first element is read
#' @return The number, or `NULL` when it is not one
#' @keywords internal
#' @noRd
positive_number <- function(value) {
  value <- if (is.numeric(value) && length(value) >= 1L) value[[1L]]
  if (length(value) == 1L && is.finite(value) && value > 0) value
}

#' Show an inline chart at the size knitr shows a figure
#'
#' The chart's svg is as wide and high as its canvas, at 72 pixels to the
#' inch, in user units its `viewBox` keeps; its `width` and `height` are
#' made `ppi` pixels to the inch, so that it takes the room the chunk's
#' figure would. What it draws, and what maidr reads from it, are as they
#' were.
#'
#' @param root The chart's `<svg>` node
#' @param ppi Pixels to the inch, from `knitr_chart_ppi()`
#' @return `root`, invisibly
#' @keywords internal
#' @noRd
inline_display_size <- function(root, ppi) {
  size <- inline_svg_size(root)
  if (is.null(size) || isTRUE(all.equal(ppi, 72))) {
    return(invisible(root))
  }
  xml2::xml_attr(root, "width") <- format_px(size[["width"]] * ppi / 72)
  xml2::xml_attr(root, "height") <- format_px(size[["height"]] * ppi / 72)
  invisible(root)
}

#' The size of an inline chart's canvas, in its user units
#'
#' @param root The chart's `<svg>` node
#' @return A named numeric vector, `width` and `height`, or `NULL`
#' @keywords internal
#' @noRd
inline_svg_size <- function(root) {
  box <- xml2::xml_attr(root, "viewBox")
  values <- if (!is.na(box)) {
    suppressWarnings(as.numeric(strsplit(trimws(box), "[[:space:],]+")[[1L]]))
  }
  if (length(values) == 4L && all(is.finite(values)) && all(values[3:4] > 0)) {
    return(c(width = values[[3L]], height = values[[4L]]))
  }
  NULL
}

#' A length in pixels as the svg's attributes write it
#'
#' @param x A number of pixels
#' @return One string, such as "672px"
#' @keywords internal
#' @noRd
format_px <- function(x) {
  paste0(format(round(x, 2), trim = TRUE, scientific = FALSE), "px")
}

#' The CSS width a chart takes from the author's `out.width`
#'
#' knitr sets `out.width` itself for a retina figure; only the author's, in
#' the chunk or for the document, is the chart's. In a panel Quarto lays
#' out (`quarto_lays_out()`) a percentage is given to the panel's cell,
#' which the chart then fills, as Quarto gives an image's.
#'
#' @param options The chunk options
#' @param index Which of the chunk's charts this is, from 1
#' @param quarto Whether Quarto is knitting the document
#' @return The width, or `NULL`
#' @keywords internal
#' @noRd
knitr_chart_out_width <- function(options, index, quarto) {
  authored <- chunk_sets_option(options, "out.width") ||
    !is.null(knitr::opts_chunk$get("out.width"))
  width <- if (authored) knitr_chart_width(options$out.width, index)
  in_cell <- quarto && !is.null(width) && endsWith(width, "%") && quarto_lays_out(options)
  if (in_cell) NULL else width
}

#' How a chart is aligned
#'
#' @param align The `fig.align` chunk option
#' @param centred Whether the chart is centred when `fig.align` says
#'   nothing, as Quarto centres a figure it captions
#' @return "left", "center" or "right", or `NULL` for none
#' @keywords internal
#' @noRd
knitr_chart_align <- function(align, centred) {
  if (length(align) == 1L && align %in% c("left", "center", "right")) {
    return(align)
  }
  if (centred) "center"
}

#' The CSS height a chart takes from `out.height`
#'
#' As `knitr_chart_width()` reads `out.width`. A percentage is not used: a
#' figure's box is as high as what it holds, and an image given a
#' percentage of it keeps its own height.
#'
#' @param out_height The `out.height` chunk option
#' @param index Which of the chunk's charts this is, from 1
#' @return The height, or `NULL`
#' @keywords internal
#' @noRd
knitr_chart_height <- function(out_height, index) {
  height <- knitr_chart_width(out_height, index)
  if (is.null(height) || endsWith(height, "%")) NULL else height
}

#' The width that shows a chart at a height, keeping its shape
#'
#' An image given `out.height` is stretched to it; a chart keeps its shape,
#' and is made as wide as that height asks. It still shrinks to a column
#' narrower than that.
#'
#' @param root The chart's `<svg>` node
#' @param height The CSS height, from `knitr_chart_height()`
#' @return A CSS width
#' @keywords internal
#' @noRd
inline_width_for_height <- function(root, height) {
  size <- inline_svg_size(root)
  ratio <- if (is.null(size)) 1 else size[["width"]] / size[["height"]]
  found <- regmatches(height, regexec("^([0-9]*\\.?[0-9]+)([a-z]*)$", height))[[1L]]
  pixels <- if (length(found) == 3L) css_pixels(as.numeric(found[[2L]]), found[[3L]])
  if (!is.null(pixels)) {
    return(format_px(pixels * ratio))
  }
  sprintf("calc(%s * %s)", height, format(round(ratio, 4), scientific = FALSE))
}

#' Whether Quarto stretches the lone figure of a slide of this document
#'
#' In a reveal.js deck that keeps `auto-stretch` (`quarto_auto_stretch()`).
#'
#' @return Logical
#' @keywords internal
#' @noRd
quarto_stretches_figures <- function() {
  !is.null(knitr::opts_knit$get("quarto.version")) &&
    identical(knitr::pandoc_to(), "revealjs") && quarto_auto_stretch()
}

#' Whether Quarto stretches a reveal.js slide's lone figure
#'
#' Quarto's `auto-stretch`, on unless the document's own front matter turns
#' it off, at its top level or under `format: revealjs:`. A project's
#' `_quarto.yml` is not seen from R.
#'
#' @return Logical
#' @keywords internal
#' @noRd
quarto_auto_stretch <- function() {
  meta <- tryCatch(rmarkdown::metadata, error = function(e) list())
  if (!is.list(meta)) {
    return(TRUE)
  }
  value <- meta[["auto-stretch"]]
  revealjs <- if (is.list(meta[["format"]])) meta[["format"]][["revealjs"]]
  if (is.list(revealjs) && !is.null(revealjs[["auto-stretch"]])) {
    value <- revealjs[["auto-stretch"]]
  }
  !isFALSE(value)
}

#' HTML as a raw block of Markdown
#'
#' @param html Lines of HTML
#' @return Character string of Markdown
#' @keywords internal
#' @noRd
raw_html_block <- function(html) {
  paste(xfun::fenced_block(html, attrs = "=html"), collapse = "\n")
}

#' A chart in place of a figure in Quarto
#'
#' The `.maidr-knitr` wrapper is Markdown around the raw block of the
#' chart, which pandoc reads as a div, rather than part of the block: the
#' page is the same, but Quarto's dashboard reads a div there. It makes no
#' card of a chunk whose output is only raw blocks, and gathers such
#' chunks, one after another, into one card titled by the first. And it
#' takes a `.cell-output-display` holding only a raw HTML block with the
#' text `bsli` in it for a bslib component, and lifts it out of its card:
#' its pattern `'bslib-'` is a Lua pattern, whose `b-` matches as few b's
#' as it can, none. A chart with a `bslib` or `subslice` bar would be in no
#' card at all. The wrapper is an HTML tag, not a fenced div, which pandoc
#' reads as a div in a chunk indented beyond the list item it is in, too.
#'
#' The chart is in a `.cell-output-display` div, as Quarto's plot hook
#' writes a figure (`quarto_output_display()`), but in a `results = "asis"`
#' chunk, where it writes none. There it is in a div of no class instead:
#' a layout around the chunk (`::: {layout-ncol=2}`) makes a div it holds
#' a cell of its own, given the cell's class and style in place of the
#' div's own, and puts a raw block it holds in a div of no class.
#'
#' @param wrapper The wrapper's opening tag
#' @param chart Lines of HTML: the chart, its alt text and its caption
#' @param options The figure's chunk options
#' @return Character string of Markdown
#' @keywords internal
#' @noRd
quarto_chart <- function(wrapper, chart, options) {
  block <- paste0(wrapper, "\n\n", raw_html_block(chart), "\n\n</div>")
  if (identical(options$results, "asis")) {
    return(paste0("\n\n<div>\n\n", block, "\n\n</div>\n\n"))
  }
  quarto_output_display(block)
}

#' Whether Quarto lays a chunk's figures out as a panel
#'
#' Quarto makes a panel of a chunk with a `layout`, `layout-ncol` or
#' `layout-nrow` (`layout.ncol`, `layout.nrow` while knitr turned the dash
#' into a dot) or of one with a `fig.ncol` or `fig.sep`, from which its
#' chunk hook makes one. Each block of a `.cell-output-display` div of the
#' chunk is then a cell of the panel; a div is the cell itself, given the
#' cell's class and its style in place of its own. A chart's wrapper keeps
#' its own when it is part of the raw block, which Quarto puts in a div of
#' the cell's.
#'
#' @param options The figure's chunk options
#' @return Logical
#' @keywords internal
#' @noRd
quarto_lays_out <- function(options) {
  keys <- c(
    "layout", "layout-ncol", "layout-nrow", "layout.ncol", "layout.nrow",
    "fig.ncol", "fig.sep"
  )
  any(vapply(keys, function(key) !is.null(options[[key]]), logical(1)))
}

#' A figure's output as Quarto's plot hook writes it
#'
#' In a `.cell-output-display` div, which Quarto's filters take for an
#' output of the cell.
#'
#' @param x Markdown of the figure
#' @return Character string of Markdown
#' @keywords internal
#' @noRd
quarto_output_display <- function(x) {
  paste0("\n\n::: {.cell-output-display}\n\n", x, "\n\n:::\n\n")
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
#' Quarto's plot hook writes is (`quarto_output_display()`).
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
  quarto_output_display(paste0(
    "::: {#", id, "}\n\n",
    block, "\n\n",
    if (!is.null(caption)) paste0(caption, "\n\n"),
    ":::"
  ))
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

#' A name for a chart with no alt text, caption or title
#'
#' Its kind, from the type of its first layer, and what it plots against
#' what when both axes are labelled: "Bar chart of n by kind".
#'
#' @param json The maidr-data JSON
#' @return One string; "Chart" when the JSON cannot be read
#' @keywords internal
#' @noRd
knitr_chart_kind <- function(json) {
  layer <- tryCatch(
    jsonlite::parse_json(json)$subplots[[1L]][[1L]]$layers[[1L]],
    error = function(e) NULL
  )
  type <- if (is.character(layer$type) && length(layer$type) == 1L) layer$type else ""
  kinds <- c(
    hist = "Histogram", point = "Scatter plot", heat = "Heat map", box = "Box plot",
    smooth = "Smoothed line", violin_box = "Violin plot", violin_kde = "Violin plot",
    word_cloud = "Word cloud", treemap = "Treemap", contour = "Contour plot"
  )
  kind <- if (type %in% names(kinds)) {
    kinds[[type]]
  } else if (nzchar(type)) {
    words <- gsub("_", " ", type, fixed = TRUE)
    paste0(toupper(substr(words, 1L, 1L)), substring(words, 2L), " chart")
  } else {
    "Chart"
  }
  label <- function(axis) {
    text <- if (is.list(axis)) axis$label else axis
    if (is.character(text) && length(text) == 1L && nzchar(trimws(text))) text
  }
  x <- label(layer$axes$x)
  y <- label(layer$axes$y)
  if (is.null(x) || is.null(y)) kind else sprintf("%s of %s by %s", kind, y, x)
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
