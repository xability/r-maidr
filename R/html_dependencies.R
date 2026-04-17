#' MAIDR JavaScript library version bundled with this package
#'
#' @keywords internal
MAIDR_VERSION <- "3.59.0"

#' Get the MAIDR CDN base URL
#'
#' Uses @latest to always fetch the most recent version from CDN.
#'
#' @return CDN URL string
#' @keywords internal
maidr_cdn_url <- function() {
  "https://cdn.jsdelivr.net/npm/maidr@latest/dist"
}

#' Register JS/CSS dependencies for maidr with auto-detection
#'
#' Creates HTML dependencies for MAIDR JavaScript and CSS files.
#' Behavior is controlled by the `maidr.use_bundled` option:
#' - If `TRUE`: Always use local bundled files (works offline, reproducible)
#' - If `FALSE`: Always use CDN (requires internet)
#' - If `NULL` (default): Auto-detect based on internet availability
#'
#' @return A list containing one htmlDependency object
#' @keywords internal
#' @examples
#' \dontrun{
#' # Force bundled version (offline mode)
#' options(maidr.use_bundled = TRUE)
#'
#' # Force CDN version
#' options(maidr.use_bundled = FALSE)
#'
#' # Auto-detect (default)
#' options(maidr.use_bundled = NULL)
#' }
maidr_html_dependencies <- function() {

  # Check user preference, fallback to auto-detect

  use_bundled <- getOption("maidr.use_bundled", default = NULL)

  if (is.null(use_bundled)) {
    # Auto-detect: use CDN if internet available, otherwise local files
    use_cdn <- curl::has_internet()
  } else {
    # Respect user preference
    use_cdn <- !use_bundled
  }

  if (use_cdn) {
    # CDN dependency - smaller HTML, relies on internet
    maidr_dep <- htmltools::htmlDependency(
      name = "maidr",
      version = MAIDR_VERSION,
      src = c(href = maidr_cdn_url()),
      script = "maidr.js",
      stylesheet = "maidr.css"
    )
  } else {
    # Local dependency - works offline, copies files to lib/ folder
    maidr_dep <- htmltools::htmlDependency(
      name = "maidr",
      version = MAIDR_VERSION,
      package = "maidr",
      src = sprintf("htmlwidgets/lib/maidr-%s", MAIDR_VERSION),
      script = "maidr.js",
      stylesheet = "maidr.css"
    )
  }

  list(maidr_dep)
}

#' Get paths to local MAIDR assets
#'
#' Returns the file paths to the locally bundled MAIDR JavaScript and CSS files.
#'
#' @return A named list with 'js' and 'css' file paths
#' @keywords internal
maidr_local_assets <- function() {
  base_path <- system.file(
    sprintf("htmlwidgets/lib/maidr-%s", MAIDR_VERSION),
    package = "maidr"
  )

  list(
    js = file.path(base_path, "maidr.js"),
    css = file.path(base_path, "maidr.css"),
    version = MAIDR_VERSION
  )
}
