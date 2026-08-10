#' MAIDR JavaScript library version bundled with this package
#'
#' @keywords internal
MAIDR_VERSION <- "4.0.0"

#' Get the MAIDR CDN base URL
#'
#' Pinned to the same version as the bundled assets: the maidr-data JSON
#' emitted by this package is written against that frontend version, so an
#' unpinned `@latest` CDN could silently break rendering when upstream
#' releases a breaking change.
#'
#' @return CDN URL string
#' @keywords internal
maidr_cdn_url <- function() {
  sprintf("https://cdn.jsdelivr.net/npm/maidr@%s/dist", MAIDR_VERSION)
}

#' Register JS dependencies for maidr
#'
#' Creates the HTML dependency for the MAIDR JavaScript bundle.
#' Behavior is controlled by the `use_cdn` parameter:
#' - If `TRUE`: Use CDN (requires internet)
#' - If `FALSE` (default): Use local bundled files (works offline)
#' - If `NULL`: Same as `FALSE` - use local bundled files
#'
#' We default to local bundled assets for deterministic rendering. Previously
#' we auto-detected via `curl::has_internet()`; when internet was available
#' the CDN path was selected, which combined with a (now-fixed) malformed
#' nested-`<html>` HTML scaffold caused base R chart SVGs to render squished
#' in the upper-left of the viewport. Local assets match the ggplot path that
#' has always rendered correctly. Users who want CDN can still pass
#' `use_cdn = TRUE` explicitly.
#'
#' No stylesheet is declared. MAIDR styles its interface at runtime, and
#' since maidr 3.75.1 the published `maidr.css` is a placeholder with no
#' rules in it. The one stylesheet that does carry rules, `maidr-math.css`
#' (KaTeX, for LaTeX in AI chat responses), is fetched by `maidr.js` itself,
#' resolved against the URL it was loaded from -- the CDN directory, or the
#' `lib/` folder htmltools copies the bundle into.
#'
#' @param use_cdn Logical. If `TRUE`, use CDN. If `FALSE` or `NULL` (default),
#'   use bundled files.
#' @return A list containing one htmlDependency object
#' @keywords internal
maidr_html_dependencies <- function(use_cdn = NULL) {

  # Default to local bundled assets for deterministic offline-capable rendering
  if (is.null(use_cdn)) {
    use_cdn <- FALSE
  }

  if (use_cdn) {
    # CDN dependency - smaller HTML, relies on internet
    maidr_dep <- htmltools::htmlDependency(
      name = "maidr",
      version = MAIDR_VERSION,
      src = c(href = maidr_cdn_url()),
      script = "maidr.js"
    )
  } else {
    # Local dependency - works offline, copies files to lib/ folder
    maidr_dep <- htmltools::htmlDependency(
      name = "maidr",
      version = MAIDR_VERSION,
      package = "maidr",
      src = sprintf("htmlwidgets/lib/maidr-%s", MAIDR_VERSION),
      script = "maidr.js"
    )
  }

  list(maidr_dep)
}

#' Get paths to local MAIDR assets
#'
#' Returns the file paths to the locally bundled MAIDR JavaScript and KaTeX
#' stylesheet. The stylesheet is `maidr-math.css`, with its base64 web fonts
#' stripped by `.github/scripts/fetch-maidr-bundle.sh` to keep the installed
#' package under CRAN's size limit; KaTeX's layout rules are intact and only
#' the glyphs fall back to system fonts.
#'
#' @return A named list with 'js' and 'math_css' file paths
#' @keywords internal
maidr_local_assets <- function() {
  base_path <- system.file(
    sprintf("htmlwidgets/lib/maidr-%s", MAIDR_VERSION),
    package = "maidr"
  )

  list(
    js = file.path(base_path, "maidr.js"),
    math_css = file.path(base_path, "maidr-math.css"),
    version = MAIDR_VERSION
  )
}

# Session cache for inlined asset tags (the JS bundle is several MB;
# re-reading it from disk for every rendered plot is wasteful in
# documents with many plots) and for the internet-availability probe.
.maidr_asset_cache <- new.env(parent = emptyenv())

#' How long a cached internet probe stays trusted, in seconds
#'
#' Five minutes: long enough that knitting a document with dozens of plots
#' still probes at most once or twice, short enough that connectivity that
#' changed under a long-lived session is picked up while the user is still
#' looking at it.
#'
#' @keywords internal
MAIDR_INTERNET_CACHE_TTL <- 300

#' Check internet availability, with a time-boxed cache
#'
#' curl::has_internet() can block for seconds on offline machines, so the
#' result is cached rather than probed per plot. The cache is time-boxed to
#' MAIDR_INTERNET_CACHE_TTL seconds so a stale answer self-heals: a transient
#' failure does not pin the rest of the session to inlining the multi-megabyte
#' bundle, and a session that goes offline after a successful probe stops
#' emitting documents that point at a CDN it can no longer reach.
#'
#' @return TRUE if internet appears available
#' @keywords internal
maidr_internet_available <- function() {
  cached <- .maidr_asset_cache$internet
  checked_at <- .maidr_asset_cache$internet_checked_at

  if (!is.null(cached) && !is.null(checked_at)) {
    age <- as.numeric(difftime(Sys.time(), checked_at, units = "secs"))
    # A negative age means the clock moved backwards; re-probe rather than
    # trust a cache entry that is apparently from the future.
    if (!is.na(age) && age >= 0 && age < MAIDR_INTERNET_CACHE_TTL) {
      return(cached)
    }
  }

  result <- tryCatch(curl::has_internet(), error = function(e) FALSE)
  .maidr_asset_cache$internet <- isTRUE(result)
  .maidr_asset_cache$internet_checked_at <- Sys.time()
  .maidr_asset_cache$internet
}

#' Get `<style>`/`<script>` tags with the bundled assets inlined
#'
#' Reads the bundled maidr.js/maidr-math.css once per session and caches the
#' assembled tags.
#'
#' KaTeX is inlined rather than left to `maidr.js` to fetch, because these
#' tags go into a standalone document whose script is inline: it has no URL
#' of its own, so the runtime has nothing to resolve the stylesheet against.
#'
#' @return A named list with `css_tag` and `js_tag` strings
#' @keywords internal
maidr_inline_asset_tags <- function() {
  cached <- .maidr_asset_cache$tags
  if (!is.null(cached)) {
    return(cached)
  }

  assets <- maidr_local_assets()
  css_content <- paste(readLines(assets$math_css, warn = FALSE), collapse = "\n")
  js_content <- paste(readLines(assets$js, warn = FALSE), collapse = "\n")

  tags <- list(
    css_tag = sprintf("<style>\n%s\n</style>", css_content),
    js_tag = sprintf("<script>\n%s\n</script>", js_content)
  )
  .maidr_asset_cache$tags <- tags
  tags
}
