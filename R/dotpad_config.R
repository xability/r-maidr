#' Where maidr.js loads the DotPad SDK from
#'
#' maidr.js does not bundle the DotPad tactile-display SDK: it ships without a
#' licence permitting redistribution, so the first time a reader connects a
#' DotPad, maidr.js imports the SDK from the vendor's published copy on
#' jsDelivr. That is the one path an offline document (`use_cdn = FALSE`)
#' still takes to the network. The document renders, sonifies and brailles
#' without it; only connecting a DotPad needs it, unless the page names its
#' own copy of the SDK.
#'
#' maidr.js reads two globals off the page before it loads:
#' `window.MAIDR_DOTPAD_SDK_URL`, the SDK ES module, and
#' `window.MAIDR_DOTPAD_ASSET_BASE_URL`, the directory holding the braille
#' engine's `liblouis.js`, `.wasm` and `.data` files (by default the `lib/`
#' folder beside the module). This reads the R-side settings for them: the
#' options `maidr.dotpad_sdk_url` and `maidr.dotpad_asset_base_url`, falling
#' back to the environment variables `MAIDR_DOTPAD_SDK_URL` and
#' `MAIDR_DOTPAD_ASSET_BASE_URL`, which carry the same names as the globals.
#' An empty value counts as unset.
#'
#' @return A list with `sdk_url` and `asset_base_url`, each a single string
#'   or `NULL` when unset.
#' @seealso [maidr-options]
#' @keywords internal
maidr_dotpad_config <- function() {
  list(
    sdk_url = maidr_dotpad_setting(
      "maidr.dotpad_sdk_url",
      "MAIDR_DOTPAD_SDK_URL"
    ),
    asset_base_url = maidr_dotpad_setting(
      "maidr.dotpad_asset_base_url",
      "MAIDR_DOTPAD_ASSET_BASE_URL"
    )
  )
}

#' Read one DotPad setting from an option, then an environment variable
#'
#' @param option Name of the R option
#' @param envvar Name of the environment variable consulted when the option
#'   is unset or empty
#' @return A single non-empty string, or `NULL`
#' @keywords internal
maidr_dotpad_setting <- function(option, envvar) {
  value <- getOption(option)

  if (!is.null(value)) {
    if (!is.character(value) || length(value) != 1 || is.na(value)) {
      stop(
        sprintf("Option `%s` must be a single string (a URL) or NULL.", option),
        call. = FALSE
      )
    }
  }

  if (is.null(value) || !nzchar(value)) {
    value <- Sys.getenv(envvar, unset = "")
  }

  if (!nzchar(value)) {
    return(NULL)
  }

  value
}

#' `<script>` tag that declares the DotPad SDK globals
#'
#' Emitted ahead of `maidr.js` wherever this package loads the bundle, so
#' maidr.js finds the globals already set when it reads them. Nothing is
#' emitted when neither setting is configured: maidr.js then falls back to
#' the vendor's copy on jsDelivr, as documented in [maidr-options].
#'
#' @param config The settings, as returned by [maidr_dotpad_config()]
#' @return A character string: the tag, or `""` when nothing is configured
#' @keywords internal
maidr_dotpad_config_script <- function(config = maidr_dotpad_config()) {
  globals <- c(
    MAIDR_DOTPAD_SDK_URL = config$sdk_url,
    MAIDR_DOTPAD_ASSET_BASE_URL = config$asset_base_url
  )

  if (length(globals) == 0) {
    return("")
  }

  assignments <- sprintf(
    "  window.%s = %s;",
    names(globals),
    vapply(globals, maidr_js_string_literal, character(1), USE.NAMES = FALSE)
  )

  paste(c("<script>", assignments, "</script>"), collapse = "\n")
}

#' Encode a string as a JavaScript literal safe inside a `<script>` element
#'
#' JSON is a subset of JavaScript, so `jsonlite` does the quoting. It leaves
#' `/` alone, though, and an HTML parser ends the surrounding `<script>` at
#' the first `</` it sees whatever the JavaScript around it says, so that
#' sequence is escaped too.
#'
#' @param x A single string
#' @return The quoted literal
#' @keywords internal
maidr_js_string_literal <- function(x) {
  literal <- as.character(jsonlite::toJSON(x, auto_unbox = TRUE))
  gsub("</", "<\\/", literal, fixed = TRUE)
}

#' The DotPad SDK globals as an htmltools dependency
#'
#' For the paths that assemble their document from dependencies rather than
#' a template: `show()`, `save_html()` and the knitr widget. The globals ride
#' in the dependency's `head`, and the dependency is listed ahead of the
#' `maidr` one so the head lands before the bundle's `<script>`.
#'
#' @param config The settings, as returned by [maidr_dotpad_config()]
#' @return An `htmltools::htmlDependency()`, or `NULL` when nothing is
#'   configured
#' @keywords internal
maidr_dotpad_config_dependency <- function(config = maidr_dotpad_config()) {
  script <- maidr_dotpad_config_script(config)
  if (!nzchar(script)) {
    return(NULL)
  }

  htmltools::htmlDependency(
    name = "maidr-dotpad-config",
    version = "1.0.0",
    src = c(href = ""),
    all_files = FALSE,
    head = script
  )
}
