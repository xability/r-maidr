# Which knitted documents show maidr charts inline.
#
# In HTML output that pandoc writes as a page, a chart can be the page's own
# <svg>, in a raw HTML block, with the page loading maidr.js once for all of
# them (`maidr_knitr_dependencies()`). Other HTML output keeps a chart in an
# iframe of its own, and any other format the plot as its library draws it.

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
#' could bind a chart in it.
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
