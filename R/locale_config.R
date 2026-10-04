# ==============================================================================
# Where maidr.js finds its languages
# ==============================================================================
#
# maidr.js (4.8.0 and later) speaks English on its own and every other
# language from a locale pack, `locale-<code>.js`, which it fetches from beside
# itself when a reader's language is chosen or detected (xability/maidr#1252).
# This package bundles only maidr.js: the eight packs come to 0.8 MB, and the
# installed package is already over CRAN's size guideline. So a document that
# loads the bundled copy -- from `lib/`, or inlined, where it has no URL at
# all -- tells maidr.js where the packs of that same version are instead,
# through `window.maidrLocaleBaseUrl`: jsDelivr, unless the session names
# another place. English still needs nothing from the network; another
# language is fetched when the reader is online and stays English, as before,
# when they are not. A document that loads maidr.js from the CDN declares
# nothing, because the packs are beside that copy already.

#' Where maidr.js should fetch its locale packs from
#'
#' Reads the `maidr.locale_base_url` option, then the `MAIDR_LOCALE_BASE_URL`
#' environment variable (see [maidr-options]). A place either of them names is
#' declared in every document. `""` or `FALSE` declares nothing. Left unset,
#' a document that loads the bundled maidr.js gets the packs of the bundled
#' version on jsDelivr, and one that loads maidr.js from the CDN gets nothing,
#' since its packs sit beside that copy.
#'
#' @param use_cdn Whether the document loads maidr.js from the CDN
#' @return A directory URL, or `NULL` when nothing is to be declared
#' @keywords internal
maidr_locale_base_url <- function(use_cdn = FALSE) {
  value <- getOption("maidr.locale_base_url")

  if (isFALSE(value)) {
    return(NULL)
  }
  if (!is.null(value) &&
        (!is.character(value) || length(value) != 1 || is.na(value))) {
    stop(
      "Option `maidr.locale_base_url` must be a single string (a URL), ",
      "\"\" or FALSE to declare nothing, or NULL.",
      call. = FALSE
    )
  }

  if (is.null(value)) {
    value <- Sys.getenv("MAIDR_LOCALE_BASE_URL", unset = NA)
  }
  if (is.na(value)) {
    if (isTRUE(use_cdn)) {
      return(NULL)
    }
    return(sprintf("https://cdn.jsdelivr.net/npm/maidr@%s/dist/", MAIDR_VERSION))
  }
  if (!nzchar(value)) {
    return(NULL)
  }

  value
}

#' The locale pack location as a `<script>` element
#'
#' For the documents assembled from a template. It keeps a location the page
#' already declared, so an author's own tag wins whichever comes first.
#'
#' @param url As returned by [maidr_locale_base_url()]
#' @return The element, or `""` when `url` is `NULL`
#' @keywords internal
maidr_locale_config_script <- function(url = maidr_locale_base_url()) {
  if (is.null(url)) {
    return("")
  }

  sprintf(
    "<script>\n  window.maidrLocaleBaseUrl = window.maidrLocaleBaseUrl || %s;\n</script>",
    maidr_js_string_literal(url)
  )
}

#' The locale pack location as an htmltools dependency
#'
#' For the paths that assemble their document from dependencies: `show()`,
#' `save_html()`, the htmlwidget and knitr. htmltools writes a dependency's
#' `head` after its scripts, so the location rides in a dependency of its own,
#' listed ahead of the `maidr` one, as [maidr_dotpad_config_dependency()] does.
#'
#' @param use_cdn Whether the document loads maidr.js from the CDN
#' @return An `htmltools::htmlDependency()`, or `NULL` when nothing is to be
#'   declared
#' @keywords internal
maidr_locale_config_dependency <- function(use_cdn = FALSE) {
  script <- maidr_locale_config_script(maidr_locale_base_url(use_cdn))
  if (!nzchar(script)) {
    return(NULL)
  }

  maidr_head_dependency("maidr-locale-config", script)
}
