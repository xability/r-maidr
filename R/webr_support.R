# Running under webR (R compiled to WebAssembly, in a browser or Node).
#
# There is no desktop browser to hand a file to, so `show()` cannot call
# `utils::browseURL()`. The document is instead rendered to one self-contained
# string (webR's virtual file system is not reachable from a page's URLs, so
# the `lib/` folder a saved document points at would not resolve) and handed
# to whatever the host page provides.

#' Whether R is running under webR
#' @return TRUE when R was built for Emscripten
#' @keywords internal
is_webr <- function() {
  identical(R.version$os, "emscripten")
}

#' Turn a saved document into one self-contained string
#'
#' Replaces each local `<script src>` and `<link rel="stylesheet" href>` that
#' points beside the file with its contents.
#'
#' @param file Path of an HTML document saved with its dependencies beside it
#' @return The document as a single string
#' @keywords internal
maidr_inline_local_assets <- function(file) {
  base <- dirname(file)
  html <- paste(readLines(file, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  read_asset <- function(path) {
    full <- file.path(base, utils::URLdecode(path))
    if (!file.exists(full)) {
      return(NULL)
    }
    paste(readLines(full, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  }
  is_local <- function(path) !grepl("^([a-z][a-z0-9+.-]*:|//|/)", path, ignore.case = TRUE)

  replace_all <- function(html, pattern, build) {
    hits <- regmatches(html, gregexpr(pattern, html, perl = TRUE))[[1]]
    for (tag in unique(hits)) {
      path <- sub(pattern, "\\1", tag, perl = TRUE)
      body <- if (is_local(path)) read_asset(path) else NULL
      if (!is.null(body)) {
        pos <- regexpr(tag, html, fixed = TRUE)
        html <- paste0(
          substr(html, 1L, pos - 1L),
          build(body),
          substring(html, pos + attr(pos, "match.length"))
        )
      }
    }
    html
  }

  # "</script" inside an inline script would end it early.
  html <- replace_all(
    html,
    '<script[^>]*?\\ssrc="([^"]+)"[^>]*></script>',
    function(body) paste0("<script>", gsub("</script", "<\\\\/script", body, ignore.case = TRUE), "</script>")
  )
  replace_all(
    html,
    '<link[^>]*?\\shref="([^"]+)"[^>]*>',
    function(body) paste0("<style>", body, "</style>")
  )
}

#' Hand a finished document to the page webR runs in
#'
#' In order: the function in `options(maidr.webr_display)`, called with the
#' HTML string; `globalThis.maidrWebRShow(html)` when the page defines it;
#' otherwise the document is written to a file and its path is reported.
#'
#' @param html The self-contained document, a string
#' @return Invisibly, the file path when nothing showed the document
#' @keywords internal
maidr_webr_display <- function(html) {
  hook <- getOption("maidr.webr_display")
  if (is.function(hook)) {
    hook(html)
    return(invisible(NULL))
  }

  if (requireNamespace("webr", quietly = TRUE)) {
    shown <- tryCatch(
      {
        payload <- jsonlite::toJSON(html, auto_unbox = TRUE)
        call <- sprintf(
          "typeof globalThis.maidrWebRShow === 'function' ? (globalThis.maidrWebRShow(%s), true) : false",
          payload
        )
        isTRUE(getExportedValue("webr", "eval_js")(call))
      },
      error = function(e) FALSE
    )
    if (shown) {
      return(invisible(NULL))
    }
  }

  file <- tempfile(fileext = ".html")
  writeLines(html, file, useBytes = TRUE)
  message(
    "Running under webR: no browser to open. The chart is saved at ", file,
    ". Define `globalThis.maidrWebRShow(html)` on the page or set ",
    "`options(maidr.webr_display = function(html) ...)` to show it."
  )
  invisible(file)
}

#' Show an htmltools document under webR
#' @param html_doc An htmltools HTML document object
#' @keywords internal
display_html_webr <- function(html_doc) {
  dir <- tempfile("maidr-webr-")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  file <- file.path(dir, "index.html")
  htmltools::save_html(html_doc, file = file, libdir = "lib")
  maidr_webr_display(maidr_inline_local_assets(file))
}
