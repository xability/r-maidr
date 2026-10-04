# Knitting documents in a test: R/knitr_inline.R, R/knitr_lifecycle.R and
# R/knitr_figure_map.R, and what their pages hold.

#' Put back what a test changes in maidr's and knitr's global state
#'
#' Interception is switched on and off by maidr_on()/maidr_off(), which also
#' install and remove the Base R wrappers; knitr's hooks are put back as they
#' were, since a plain knitr::knit() leaves its option hooks behind.
local_knitr_state <- function(env = parent.frame()) {
  patching <- maidr:::is_patching_active()
  saved <- options("maidr.auto_show", "maidr.base_r", "maidr.ggplot2", "maidr.lattice")
  hooks <- knitr::knit_hooks$get()
  opts_hooks <- knitr::opts_hooks$get()
  enabled <- maidr:::.maidr_knitr_state$enabled
  withr::defer(
    {
      if (patching) maidr::maidr_on() else maidr::maidr_off()
      knitr::knit_hooks$restore(hooks)
      knitr::opts_hooks$restore(opts_hooks)
      knitr::knit_meta(clean = TRUE)
      state <- maidr:::.maidr_knitr_state
      state$enabled <- enabled
      options(saved)
      maidr:::clear_all_device_storage()
      figures <- maidr:::.maidr_knit_figures
      figures$objects <- list()
      maidr:::forget_replayed_tokens()
    },
    envir = env
  )
  maidr::maidr_on()
  invisible(NULL)
}

#' Knit Markdown text as R Markdown would for a pandoc output format
#'
#' knitr::knit() sets up its Markdown hooks only when every hook is still its
#' default, so the knit starts from the defaults, as a document does in a
#' new session. The setup chunk names the output format, as R Markdown does,
#' and installs maidr into the knit as `library(maidr)` does when it loads
#' maidr; maidr is already loaded here.
#'
#' @param chunks Lines of the document after its setup chunk
#' @param dir Where knitr writes figures (and the cache)
#' @param to The pandoc output format
#' @return The knitted Markdown, as one string
knit_for <- function(chunks, dir, to = "html") {
  hooks <- knitr::knit_hooks$get()
  knitr::knit_hooks$restore()
  on.exit(knitr::knit_hooks$restore(hooks), add = TRUE)
  maidr:::clear_all_device_storage()
  document <- c(
    "```{r setup, include = FALSE}",
    sprintf("knitr::opts_knit$set(rmarkdown.pandoc.to = %s)", deparse(to)),
    sprintf(
      "knitr::opts_chunk$set(fig.path = %s, cache.path = %s)",
      deparse(file.path(dir, "figure", "")), deparse(file.path(dir, "cache", ""))
    ),
    "maidr:::ensure_knitr_integration()",
    "```",
    "",
    chunks
  )
  old <- setwd(dir)
  on.exit(setwd(old), add = TRUE)
  paste(knitr::knit(text = document, quiet = TRUE, envir = new.env()), collapse = "\n")
}

#' The inline charts of a page: each svg, as its own xml2 document
inline_charts <- function(html) {
  doc <- xml2::read_html(html, encoding = "UTF-8")
  lapply(
    xml2::xml_find_all(doc, "//svg[@data-maidr-knitr]"),
    function(svg) xml2::read_xml(as.character(svg), options = c("HUGE", "NOBLANKS"))
  )
}

#' What each inline chart of a page shows, in page order
#'
#' Each chart as `"<layer type>:<points>"`, its layers joined by `+` and its
#' subplots by `|`.
chart_summaries <- function(page) {
  vapply(inline_charts(page), function(svg) {
    data <- jsonlite::parse_json(xml2::xml_attr(svg, "data-maidr-knitr"))
    cells <- unlist(data$subplots, recursive = FALSE)
    paste(vapply(cells, function(cell) {
      paste(vapply(cell$layers, function(layer) {
        paste0(layer$type, ":", length(layer$data))
      }, character(1)), collapse = "+")
    }, character(1)), collapse = "|")
  }, character(1))
}

#' The charts and figures of a knitted page, in page order
#'
#' A chart as its title, `: ` and what `chart_summaries()` gives for it; a
#' figure knitr included, as Markdown or as an `<img>`, as `figure ` and its
#' file's name.
figure_sequence <- function(page) {
  charts <- inline_charts(page)
  summaries <- chart_summaries(page)
  pattern <- 'data-maidr-knitr=|!\\[[^]]*\\]\\([^)]+\\)|<img src="[^"]+"'
  found <- regmatches(page, gregexpr(pattern, page))[[1]]
  chart <- 0L
  vapply(found, function(item) {
    if (!startsWith(item, "data-maidr-knitr")) {
      file <- sub('^(!\\[[^]]*\\]\\(|<img src=")([^)"]+)[)"]$', "\\2", item)
      return(paste("figure", basename(file)))
    }
    chart <<- chart + 1L
    data <- jsonlite::parse_json(xml2::xml_attr(charts[[chart]], "data-maidr-knitr"))
    paste0(if (is.character(data$title)) data$title else "", ": ", summaries[[chart]])
  }, character(1), USE.NAMES = FALSE)
}

#' The name each inline chart of a page has until maidr.js mounts it
#'
#' Its `aria-label`, or the text of the elements its `aria-labelledby` names.
chart_names <- function(page) {
  doc <- xml2::read_html(page, encoding = "UTF-8")
  vapply(xml2::xml_find_all(doc, "//svg[@data-maidr-knitr]"), function(svg) {
    label <- xml2::xml_attr(svg, "aria-label")
    if (!is.na(label)) {
      return(label)
    }
    ids <- strsplit(xml2::xml_attr(svg, "aria-labelledby"), " ", fixed = TRUE)[[1]]
    texts <- vapply(ids, function(id) {
      xml2::xml_text(xml2::xml_find_first(doc, sprintf("//*[@id = '%s']", id)))
    }, character(1))
    paste(texts, collapse = " ")
  }, character(1))
}
