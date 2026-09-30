# Running under webR (R compiled to WebAssembly, in a browser or Node).
#
# There is no desktop browser to hand a file to, so `show()` cannot call
# `utils::browseURL()`. The document is instead rendered to one self-contained
# string (webR's virtual file system is not reachable from a page's URLs, so
# the `lib/` folder a saved document points at would not resolve) and shown in
# an iframe on the page, or handed to whatever the host page provides.

#' Whether R is running under webR
#' @return TRUE when R was built for Emscripten
#' @keywords internal
is_webr <- function() {
  identical(R.version$os, "emscripten")
}

read_text_file <- function(path) {
  paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
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
  html <- read_text_file(file)
  read_asset <- function(path) {
    full <- file.path(base, utils::URLdecode(path))
    if (!file.exists(full)) {
      return(NULL)
    }
    read_text_file(full)
  }
  # A URL scheme, a //host URL or an absolute path is not beside the file.
  is_local <- function(path) {
    !grepl("^([a-z][a-z0-9+.-]*:|//|/)", path, ignore.case = TRUE)
  }

  replace_all <- function(html, pattern, build) {
    hits <- regmatches(html, gregexpr(pattern, html, perl = TRUE))[[1]]
    for (tag in unique(hits)) {
      path <- sub(pattern, "\\1", tag, perl = TRUE)
      body <- if (is_local(path)) read_asset(path) else NULL
      if (!is.null(body)) {
        # regmatches<- inserts the text as it is, every occurrence of the tag.
        found <- gregexpr(tag, html, fixed = TRUE)
        regmatches(html, found) <- list(rep(build(body), length(found[[1]])))
      }
    }
    html
  }

  # htmltools writes double-quoted attributes; single-quoted ones are left alone.
  # "</script" or "</style" inside an inline body would end it early.
  html <- replace_all(
    html,
    '<script[^>]*?\\ssrc="([^"]+)"[^>]*></script>',
    function(body) {
      body <- gsub("</script", "<\\\\/script", body, ignore.case = TRUE)
      paste0("<script>", body, "</script>")
    }
  )
  replace_all(
    html,
    '<link(?=[^>]*\\srel="stylesheet")[^>]*?\\shref="([^"]+)"[^>]*>',
    function(body) {
      body <- gsub("</style", "<\\\\/style", body, ignore.case = TRUE)
      paste0("<style>", body, "</style>")
    }
  )
}

#' JavaScript that shows a finished document on the page
#'
#' Hands it to `globalThis.maidrWebRShow(html)` when the page defines one.
#' Otherwise the document goes into an iframe, in the element with id
#' `maidr-output` when the page has one, else at the end of `<body>`. The frame
#' is sized to its content, and carries the
#' listener [maidr_iframe_host_script()] gives every MAIDR frame, so the
#' keyboard can leave the chart.
#'
#' @param html The self-contained document, a string
#' @return A JavaScript expression that evaluates to `true`
#' @keywords internal
maidr_webr_show_js <- function(html) {
  host_code <- sub("^<script>", "", maidr_iframe_host_script())
  host_code <- sub("</script>$", "", host_code)
  js <- paste0(
    "(function(html, hostCode) {",
    "if (typeof globalThis.maidrWebRShow === 'function') {",
    "globalThis.maidrWebRShow(html); return true;",
    "}",
    "if (!window.__maidrIframeHost) { (new Function(hostCode))(); }",
    "var host = document.getElementById('maidr-output') || document.body;",
    "window.__maidrWebRFrames = (window.__maidrWebRFrames || 0) + 1;",
    "var f = document.createElement('iframe');",
    "f.id = 'maidr-iframe-webr-' + window.__maidrWebRFrames;",
    "f.title = 'MAIDR chart';",
    "f.setAttribute('allow', 'bluetooth; serial');",
    "f.setAttribute('role', 'img');",
    "f.tabIndex = 0;",
    "f.style.cssText = 'width:100%%;height:450px;border:none;display:block;",
    "margin:0 auto;outline:none';",
    "f.addEventListener('load', function() {",
    "var doc = f.contentDocument;",
    "if (!doc || !doc.body || !window.ResizeObserver) { return; }",
    # The document sizes itself to the viewport (`min-height: 100vh`, and a
    # chart capped at `100vh`), which is the frame. Left alone, fitting the
    # frame to its content would feed back and grow it without end.
    "var free = doc.createElement('style');",
    "free.textContent = '.maidr-page { min-height: 0 !important; } ' +",
    "'.maidr-page svg { max-height: none !important; }';",
    "doc.head.appendChild(free);",
    "function fit() {",
    "var bottom = 0;",
    "Array.prototype.forEach.call(doc.body.children, function(el) {",
    "bottom = Math.max(bottom, el.getBoundingClientRect().bottom);",
    "});",
    "f.style.height = (Math.max(Math.ceil(bottom), 100) + 8) + 'px';",
    "}",
    # The chart is laid out, and maidr.js adds to the page, after the frame
    # loads, so the size is taken again whenever the content changes.
    "var pending = false;",
    "function later() {",
    "if (pending) { return; }",
    "pending = true;",
    "requestAnimationFrame(function() { pending = false; fit(); });",
    "}",
    "new ResizeObserver(later).observe(doc.body);",
    "new MutationObserver(later).observe(doc.body, {",
    "childList: true, subtree: true, attributes: true",
    "});",
    "f.contentWindow.addEventListener('resize', later);",
    "fit();",
    "});",
    "f.srcdoc = html;",
    "host.appendChild(f);",
    "return true;",
    "})(%s, %s)"
  )
  sprintf(
    js,
    jsonlite::toJSON(html, auto_unbox = TRUE),
    jsonlite::toJSON(host_code, auto_unbox = TRUE)
  )
}

#' Hand a finished document to the page webR runs in
#'
#' In order: the function in `options(maidr.webr_display)`, called with the
#' HTML string; then the page, see `maidr_webr_show_js()`; otherwise, when
#' there is no page to reach, the document is written to a file and its path is
#' reported.
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

  # The `webr` package ships with webR and is not on CRAN (a different package
  # of that name is), so it is reached by name rather than declared.
  webr_pkg <- "webr"
  failure <- NULL
  shown <- tryCatch(
    {
      eval_js <- get("eval_js", envir = asNamespace(webr_pkg), inherits = FALSE)
      call <- maidr_webr_show_js(html)
      isTRUE(eval_js(call))
    },
    error = function(e) {
      failure <<- conditionMessage(e)
      FALSE
    }
  )
  if (shown) {
    return(invisible(NULL))
  }

  file <- tempfile(fileext = ".html")
  writeLines(html, file, useBytes = TRUE)
  message(
    "Running under webR: could not show the chart on the page",
    if (!is.null(failure)) paste0(" (", failure, ")"),
    ". It is saved at ", file, ". Define `globalThis.maidrWebRShow(html)` on the page ",
    "or set `options(maidr.webr_display = function(html) ...)` to show it."
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
