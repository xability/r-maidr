#' MAIDR JavaScript library version bundled with this package
#'
#' @keywords internal
MAIDR_VERSION <- "4.10.0"

#' Register JS dependencies for maidr
#'
#' Creates the HTML dependency for the MAIDR JavaScript bundle.
#' Behavior is controlled by the `use_cdn` parameter:
#' - If `TRUE`: Use CDN (requires internet): the latest published maidr.js,
#'   as [maidr_cdn_url()] resolves it, unless `maidr.cdn_version` pins one
#' - If `FALSE` (default): Use local bundled files (works offline, and makes
#'   no network request)
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
#' When a DotPad SDK location is configured (see [maidr-options]), a
#' `maidr-dotpad-config` dependency precedes the `maidr` one: its `head`
#' declares the `window.MAIDR_DOTPAD_*` globals, and listing it first is what
#' puts them ahead of the bundle's `<script>` in the rendered document.
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
#' @return A list of htmlDependency objects: the `maidr` bundle, preceded by
#'   `maidr-dotpad-config` when a DotPad SDK location is configured
#' @keywords internal
maidr_html_dependencies <- function(use_cdn = NULL) {

  # Default to local bundled assets for deterministic offline-capable rendering
  if (is.null(use_cdn)) {
    use_cdn <- FALSE
  }

  if (use_cdn) {
    # CDN dependency - smaller HTML, relies on internet. The URL names the
    # version actually loaded; `version` stays the bundled one because
    # htmltools parses it with numeric_version() to deduplicate, which
    # rejects "latest" and pre-release versions. It only ranks duplicates
    # of this dependency; nothing reads it into the page.
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

  # NULL when nothing is configured, and dropped, so the list is unchanged
  # for everyone who has not asked for a local SDK.
  Filter(Negate(is.null), list(maidr_dotpad_config_dependency(), maidr_dep))
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
  css_content <- paste(
    readLines(assets$math_css, warn = FALSE, encoding = "UTF-8"),
    collapse = "\n"
  )
  js_content <- paste(
    readLines(assets$js, warn = FALSE, encoding = "UTF-8"),
    collapse = "\n"
  )

  tags <- list(
    css_tag = sprintf("<style>\n%s\n</style>", css_content),
    js_tag = sprintf("<script>\n%s\n</script>", js_content)
  )
  .maidr_asset_cache$tags <- tags
  tags
}

# `type`s of the two inert `<script>` elements that carry a document's own copy
# of the bundle. A browser neither fetches nor runs a script of a type it does
# not know, and pandoc keeps the `type` of every script it embeds -- the one
# attribute it keeps when it inlines one -- so the chart frames find the copy
# by it, whether the document embeds its resources or links them.
MAIDR_PAGE_JS_TYPE <- "text/x-maidr-js"
MAIDR_PAGE_MATH_CSS_TYPE <- "text/x-maidr-math-css"

#' The bundle a knitted document carries for its charts
#'
#' The knitr paths put each chart in a `srcdoc` iframe whose `<script>` loads
#' maidr.js from the CDN. That document lives in an attribute, where neither
#' pandoc's `--embed-resources` (R Markdown's `self_contained`, Quarto's
#' `embed-resources`) nor anything else that rewrites a page's resources can
#' see it, so a self-contained document still needed the network to make its
#' charts accessible, and offline they were plain pictures.
#'
#' This dependency gives the document one copy of the bundle that the tooling
#' does see: linked from the `_files` folder, or embedded into the page when
#' the document is self-contained. Its scripts are of a type no browser runs,
#' so the page itself is left alone; a chart frame whose CDN load fails reads
#' the copy from its parent instead (see [maidr_cdn_loader_script()]).
#'
#' @return A single htmltools::htmlDependency()
#' @keywords internal
maidr_page_bundle_dependency <- function() {
  htmltools::htmlDependency(
    name = "maidr-page-bundle",
    version = MAIDR_VERSION,
    package = "maidr",
    src = sprintf("htmlwidgets/lib/maidr-%s", MAIDR_VERSION),
    script = list(
      list(src = "maidr.js", type = MAIDR_PAGE_JS_TYPE),
      list(src = "maidr-math.css", type = MAIDR_PAGE_MATH_CSS_TYPE)
    ),
    all_files = FALSE
  )
}

#' Script that loads maidr.js from the CDN, falling back to the page's copy
#'
#' Goes into a chart frame's `srcdoc` in place of a plain CDN `<script>`. When
#' the CDN load fails -- offline, blocked -- it looks in the parent document
#' for the copy [maidr_page_bundle_dependency()] put there. A `srcdoc` frame
#' shares its parent's origin, so it can read it.
#'
#' The copy arrives in one of two shapes, and both are handled: a `src` (the
#' `_files` folder, or a `data:` URL) or inline text, which is what pandoc
#' turns a script into when it embeds it. maidr.js initialises itself when it
#' runs, so nothing is called once it has loaded. KaTeX, which it fetches only
#' when an AI response carries maths, is pointed at the page's copy through
#' `window.maidrMathStylesheetUrl`, or added as a `<style>` when inline.
#'
#' @param cdn_js_url URL of maidr.js on the CDN
#' @return Character string holding a `<script>` element
#' @keywords internal
maidr_cdn_loader_script <- function(cdn_js_url) {
  sprintf('<script>
    (function () {
      function report(reason) {
        if (window.console) {
          console.warn("maidr: maidr.js could not be loaded from the CDN, and " +
            reason + "; this chart is not interactive.");
        }
      }
      function fromPage() {
        var page;
        try {
          page = window.parent.document;
        } catch (e) {
          report("the page around this chart could not be read");
          return;
        }
        var js = page.querySelector(\'script[type="%s"]\');
        if (!js) {
          report("the page carries no copy of it");
          return;
        }
        var css = page.querySelector(\'script[type="%s"]\');
        if (css && css.src) {
          window.maidrMathStylesheetUrl = css.src;
        } else if (css) {
          var style = document.createElement("style");
          style.textContent = css.text;
          document.head.appendChild(style);
          var mark = document.createElement("link");
          mark.setAttribute("data-maidr-math", "");
          document.head.appendChild(mark);
        }
        var s = document.createElement("script");
        if (js.src) {
          s.src = js.src;
          s.onerror = function () { report("the page\'s copy did not load"); };
        } else {
          s.text = js.text;
        }
        document.head.appendChild(s);
      }
      var s = document.createElement("script");
      s.src = "%s";
      s.onerror = fromPage;
      document.head.appendChild(s);
    })();
  </script>', MAIDR_PAGE_JS_TYPE, MAIDR_PAGE_MATH_CSS_TYPE, cdn_js_url)
}
