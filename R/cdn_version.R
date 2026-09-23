# Which published maidr.js a CDN document loads.
#
# The CDN paths (`show()` / `save_html()` with `use_cdn = TRUE`, and the
# widget, knitr and Shiny paths when they detect a connection) load the
# latest published maidr.js, as the Python binding does. The bundled copy,
# used by every `use_cdn = FALSE` document, stays `MAIDR_VERSION` and is
# never touched by anything here.
#
# "Latest" is resolved to a concrete version, once per R session, rather than
# emitted as jsDelivr's `@latest` tag. A version URL is immutable: jsDelivr
# and the browser cache it for good, and the page loads exactly the release
# that was current when it was written. `@latest` is a mutable alias that
# jsDelivr serves with a cache lifetime of up to seven days, so a reader can
# be handed a week-old build and two documents rendered on the same day can
# load different ones.
#
# Settings, highest precedence first:
#
# 1. `options(maidr.cdn_version = ...)`
# 2. the `MAIDR_CDN_VERSION` environment variable
#
# Each takes a concrete version ("4.9.0", optionally "v"-prefixed),
# "bundled" (the bundled `MAIDR_VERSION`, no request) or "latest" (the
# `@latest` tag, no request). Anything else warns once and is ignored, which
# leaves the lookup in charge. A lookup that fails, or answers with a version
# older than the bundled one, gives the bundled version. The lookup's time budget is
# `options(maidr.cdn_timeout = ...)` or `MAIDR_CDN_TIMEOUT`, in seconds.

# The two tags a setting may name instead of a version.
MAIDR_CDN_LATEST_TAG <- "latest"
MAIDR_CDN_BUNDLED_TAG <- "bundled"

# Asked in order. jsDelivr's data API comes first because it is the authority
# on what cdn.jsdelivr.net will actually serve; the npm registry's dist-tags
# are the fallback. Both answer with a few bytes of JSON.
MAIDR_CDN_RESOLVERS <- list(
  list(
    url = "https://data.jsdelivr.com/v1/packages/npm/maidr/resolved?specifier=latest",
    field = "version"
  ),
  list(
    url = "https://registry.npmjs.org/-/package/maidr/dist-tags",
    field = "latest"
  )
)

# Seconds for the whole lookup, shared across both endpoints rather than
# given to each, so the fallback cannot double how long a first render waits.
MAIDR_CDN_DEFAULT_TIMEOUT <- 3

# Clamps on a configured budget. Below the floor no round trip can finish, so
# every lookup would fail and the session would never see a newer release;
# above the ceiling a value most plausibly meant as milliseconds would hang a
# render for minutes.
MAIDR_CDN_MIN_TIMEOUT <- 0.1
MAIDR_CDN_MAX_TIMEOUT <- 30

# A resolver answer is a few hundred bytes; anything much larger is not one.
MAIDR_CDN_MAX_RESPONSE_BYTES <- 65536

# Semantic version: MAJOR.MINOR.PATCH, an optional pre-release and build.
# Every repetition consumes a literal ".", which no identifier contains, so
# matching stays linear. `\z` rather than `$`, which would accept a trailing
# newline -- and the version goes into a URL.
MAIDR_SEMVER_PATTERN <- paste0(
  "^(?:0|[1-9][0-9]*)\\.(?:0|[1-9][0-9]*)\\.(?:0|[1-9][0-9]*)",
  "(?:-(?:0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*)",
  "(?:\\.(?:0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*))*)?",
  "(?:\\+[0-9A-Za-z-]+(?:\\.[0-9A-Za-z-]+)*)?\\z"
)

# Session state: whether the lookup has run, what it found (NULL when it
# failed), and which settings have already been warned about.
.maidr_cdn_state <- new.env(parent = emptyenv())

#' Get the MAIDR CDN base URL
#'
#' The jsDelivr directory holding the maidr.js that CDN documents load. The
#' version in it comes from [maidr_cdn_version()]: the latest published
#' maidr.js, resolved once per session, unless a setting pins it.
#'
#' No `integrity` (SRI) attribute goes with it. A hash can only be written
#' for bytes known in advance, which here means the bundled version; the CDN
#' paths now load whatever version is current, whose hash this package cannot
#' know. The bundled copy needs none: it is shipped with the package, not
#' fetched from a third party.
#'
#' @return CDN URL string, without a trailing slash
#' @keywords internal
maidr_cdn_url <- function() {
  sprintf("https://cdn.jsdelivr.net/npm/maidr@%s/dist", maidr_cdn_version())
}

#' The maidr.js version CDN documents load
#'
#' In order: the `maidr.cdn_version` option, the `MAIDR_CDN_VERSION`
#' environment variable, then the latest published version, looked up once
#' per session by [maidr_resolve_cdn_version()].
#'
#' When the lookup fails -- offline, blocked, timed out, or an answer that is
#' not a version -- this returns the bundled version, `MAIDR_VERSION`, as
#' py-maidr does (xability/py-maidr#295). The alternative, jsDelivr's
#' `@latest` tag, is a mutable alias that jsDelivr serves with a cache
#' lifetime of up to seven days, so degrading to it would let a browser
#' replay a week-old build in exactly the case the lookup exists to cover.
#' The bundled version is a real published release, its URL is immutable,
#' and it is the copy `use_cdn = FALSE` would have served anyway. What it
#' costs is that a network hiccup leaves the session on a possibly older
#' release. `@latest` is still emitted when it is asked for by name, with
#' `options(maidr.cdn_version = "latest")`.
#'
#' A resolver answer older than the bundled version is refused the same way
#' (see [maidr_is_older_than_bundled()]): nothing obliges a resolver, or
#' whatever sits between it and this session, to answer with the current
#' release, and the bundled version is the one known to have shipped with
#' this package.
#'
#' @return A single string: a semantic version, or `"latest"` when that tag
#'   was pinned
#' @keywords internal
maidr_cdn_version <- function() {
  pin <- maidr_cdn_version_pin()
  if (!is.null(pin)) {
    return(pin)
  }

  resolved <- maidr_resolve_cdn_version()
  if (is.null(resolved) || maidr_is_older_than_bundled(resolved)) {
    return(MAIDR_VERSION)
  }
  resolved
}

#' Is a resolved version older than the bundled one?
#'
#' Semantic version precedence, as py-maidr's `_is_older_than_bundled`
#' applies it: MAJOR.MINOR.PATCH compared numerically with
#' [numeric_version()]; on a tie, a pre-release sorts below the release it
#' precedes (`4.9.0-rc.1` < `4.9.0`), and two pre-releases compare
#' identifier by identifier, numeric ones numerically and below alphanumeric
#' ones, alphanumeric ones in ASCII order, a shorter run below a longer one
#' it begins. Build metadata (`+build.5`) carries no precedence and is
#' ignored.
#'
#' A version that cannot be compared is not called older: the resolver's
#' answer, already checked to be a semantic version, stays in place.
#'
#' @param resolved The version the resolver answered with
#' @param bundled The version bundled with this package
#' @return `TRUE` when `resolved` sorts below `bundled`
#' @keywords internal
maidr_is_older_than_bundled <- function(resolved, bundled = MAIDR_VERSION) {
  split_version <- function(version) {
    version <- sub("\\+.*$", "", version)
    dash <- regexpr("-", version, fixed = TRUE)
    if (dash < 0) {
      return(list(release = version, pre = character(0)))
    }
    list(
      release = substr(version, 1L, dash - 1L),
      pre = strsplit(substring(version, dash + 1L), ".", fixed = TRUE)[[1]]
    )
  }

  a <- split_version(resolved)
  b <- split_version(bundled)
  order <- tryCatch(
    {
      ra <- numeric_version(a$release)
      rb <- numeric_version(b$release)
      if (ra < rb) -1L else if (ra > rb) 1L else 0L
    },
    error = function(e) NA_integer_
  )
  if (is.na(order)) {
    return(FALSE)
  }
  if (order != 0L) {
    return(order < 0L)
  }

  # Same release: a pre-release is older than the release itself.
  if (length(a$pre) == 0L) {
    return(FALSE)
  }
  if (length(b$pre) == 0L) {
    return(TRUE)
  }
  maidr_compare_prerelease(a$pre, b$pre) < 0L
}

#' Compare two pre-release identifier runs by semver precedence
#'
#' @param a,b Character vectors of dot-separated identifiers
#' @return `-1`, `0` or `1`
#' @keywords internal
maidr_compare_prerelease <- function(a, b) {
  for (i in seq_len(min(length(a), length(b)))) {
    order <- maidr_compare_identifier(a[[i]], b[[i]])
    if (order != 0L) {
      return(order)
    }
  }
  sign(length(a) - length(b))
}

#' Compare two pre-release identifiers by semver precedence
#'
#' Numeric identifiers compare numerically and sort below alphanumeric ones;
#' alphanumeric ones compare in ASCII order, whatever the locale's collation.
#'
#' @param x,y Single identifiers
#' @return `-1`, `0` or `1`
#' @keywords internal
maidr_compare_identifier <- function(x, y) {
  x_numeric <- grepl("^[0-9]+$", x)
  y_numeric <- grepl("^[0-9]+$", y)
  if (x_numeric != y_numeric) {
    return(if (x_numeric) -1L else 1L)
  }
  if (identical(x, y)) {
    return(0L)
  }
  if (x_numeric) {
    return(as.integer(sign(as.numeric(x) - as.numeric(y))))
  }
  if (sort(c(x, y), method = "radix")[[1]] == x) -1L else 1L
}

#' The CDN version a setting pins, if any
#'
#' Reads the `maidr.cdn_version` option, then the `MAIDR_CDN_VERSION`
#' environment variable; an unset or blank option falls through to the
#' variable. A value that is not a usable pin warns once and is ignored, so
#' the latest version is looked up as though nothing were set: a mistyped
#' version says "I want a particular release", not "stay off the network",
#' and the latest is closer to that than failing the render would be.
#'
#' @return A semantic version, `"latest"`, or `NULL` when nothing usable is
#'   set
#' @keywords internal
maidr_cdn_version_pin <- function() {
  value <- getOption("maidr.cdn_version")
  source <- "Option `maidr.cdn_version`"

  blank <- is.character(value) && length(value) == 1 && !is.na(value) &&
    !nzchar(trimws(value))
  if (is.null(value) || blank) {
    value <- Sys.getenv("MAIDR_CDN_VERSION", unset = "")
    source <- "Environment variable `MAIDR_CDN_VERSION`"
    if (!nzchar(trimws(value))) {
      return(NULL)
    }
  }

  maidr_normalize_cdn_pin(value, source)
}

#' Turn a CDN version setting into the version a URL names
#'
#' @param value The setting as given
#' @param source What the setting is called, for the warning
#' @return A semantic version, `"latest"`, or `NULL` (with a warning, once per
#'   distinct value) when `value` is not usable
#' @keywords internal
maidr_normalize_cdn_pin <- function(value, source) {
  if (is.character(value) && length(value) == 1 && !is.na(value)) {
    candidate <- trimws(value)
    tag <- tolower(candidate)
    if (identical(tag, MAIDR_CDN_LATEST_TAG)) {
      return(MAIDR_CDN_LATEST_TAG)
    }
    if (identical(tag, MAIDR_CDN_BUNDLED_TAG)) {
      return(MAIDR_VERSION)
    }
    # Accepted with a leading "v", which is how release notes and git tags
    # spell a version.
    candidate <- sub("^[vV]", "", candidate)
    if (maidr_is_semver(candidate)) {
      return(candidate)
    }
  }

  shown <- paste(maidr_cdn_deparse(value), collapse = " ")
  maidr_cdn_warn_once(
    paste(source, shown),
    sprintf(
      paste0(
        "%s is %s, which is not a maidr.js version such as \"%s\", ",
        "\"bundled\" or \"latest\"; it is ignored, and CDN documents load ",
        "the latest published maidr.js."
      ),
      source, shown, MAIDR_VERSION
    )
  )
  NULL
}

#' Deparse a setting for a message, bounded in length
#'
#' @param value Any R value
#' @return A single string of at most 80 characters
#' @keywords internal
maidr_cdn_deparse <- function(value) {
  shown <- paste(deparse(value, width.cutoff = 60L), collapse = " ")
  if (nchar(shown) > 80L) {
    shown <- paste0(substr(shown, 1L, 77L), "...")
  }
  shown
}

#' Is a string a semantic version?
#'
#' @param x Value to test
#' @return `TRUE` for a single string of at most 128 characters in semantic
#'   version form, otherwise `FALSE`
#' @keywords internal
maidr_is_semver <- function(x) {
  is.character(x) && length(x) == 1 && !is.na(x) && nchar(x) <= 128L &&
    grepl(MAIDR_SEMVER_PATTERN, x, perl = TRUE)
}

#' Warn once per session for a given key
#'
#' A bad setting is read on every render, and one warning is enough.
#'
#' @param key What identifies this warning
#' @param message The warning
#' @return `NULL`, invisibly
#' @keywords internal
maidr_cdn_warn_once <- function(key, message) {
  warned <- .maidr_cdn_state$warned
  if (!key %in% warned) {
    .maidr_cdn_state$warned <- c(warned, key)
    warning(message, call. = FALSE)
  }
  invisible(NULL)
}

#' The latest published maidr.js version, looked up once per session
#'
#' The first call asks the resolvers (see [maidr_fetch_latest_cdn_version()])
#' and caches the answer, a failure included, so a machine that cannot reach
#' them pays the time budget once rather than on every render. Reset with
#' [maidr_reset_cdn_cache()].
#'
#' @return A semantic version, or `NULL` when the lookup failed
#' @keywords internal
maidr_resolve_cdn_version <- function() {
  if (isTRUE(.maidr_cdn_state$attempted)) {
    return(.maidr_cdn_state$version)
  }

  version <- maidr_fetch_latest_cdn_version(maidr_cdn_timeout())
  # Recorded only after the lookup returns, so an interrupt (Ctrl+C) during
  # it leaves nothing cached and the next render simply asks again.
  .maidr_cdn_state$version <- version
  .maidr_cdn_state$attempted <- TRUE
  version
}

#' Forget the looked-up CDN version and the warnings already given
#'
#' For tests, and for a long-lived session that wants to pick up a release
#' published since its first render.
#'
#' @return `NULL`, invisibly
#' @keywords internal
maidr_reset_cdn_cache <- function() {
  .maidr_cdn_state$attempted <- NULL
  .maidr_cdn_state$version <- NULL
  .maidr_cdn_state$warned <- NULL
  invisible(NULL)
}

#' Ask the resolvers which maidr.js version `latest` is
#'
#' Tries jsDelivr's data API, then the npm registry, within one shared time
#' budget: each request gets whatever the budget has left, and curl enforces
#' it as a limit on the whole transfer, name resolution included. Never
#' raises and never warns -- a failed lookup must not fail a render -- so
#' every failure, whether the network, an HTTP status, or an answer that is
#' not JSON or not a version, is `NULL`.
#'
#' @param budget Seconds for the whole lookup
#' @return A semantic version, or `NULL`
#' @keywords internal
maidr_fetch_latest_cdn_version <- function(budget) {
  deadline <- proc.time()[["elapsed"]] + budget

  for (resolver in MAIDR_CDN_RESOLVERS) {
    remaining <- deadline - proc.time()[["elapsed"]]
    if (remaining <= 0) {
      break
    }

    version <- tryCatch(
      suppressWarnings(maidr_parse_resolver_response(
        maidr_cdn_resolver_request(resolver$url, remaining),
        resolver$field
      )),
      error = function(e) NULL
    )
    if (!is.null(version)) {
      return(version)
    }
  }

  NULL
}

#' Fetch one resolver endpoint
#'
#' The only function in this package that makes the version lookup's
#' request, so tests replace it and never reach the network.
#'
#' @param url Endpoint URL
#' @param timeout Seconds allowed for the whole transfer
#' @return The response body as a string; an error on any failure
#' @keywords internal
maidr_cdn_resolver_request <- function(url, timeout) {
  timeout_ms <- max(1L, as.integer(ceiling(timeout * 1000)))
  handle <- curl::new_handle(
    timeout_ms = timeout_ms,
    connecttimeout_ms = timeout_ms,
    maxfilesize = MAIDR_CDN_MAX_RESPONSE_BYTES,
    followlocation = TRUE,
    useragent = "r-maidr"
  )
  curl::handle_setheaders(handle, Accept = "application/json")

  response <- curl::curl_fetch_memory(url, handle = handle)
  if (response$status_code != 200L) {
    stop(sprintf("HTTP %d from %s", response$status_code, url), call. = FALSE)
  }
  if (length(response$content) > MAIDR_CDN_MAX_RESPONSE_BYTES) {
    stop(sprintf("oversized response from %s", url), call. = FALSE)
  }

  body <- rawToChar(response$content)
  Encoding(body) <- "UTF-8"
  body
}

#' Read the version out of a resolver's answer
#'
#' @param body The response body, JSON
#' @param field The top-level field that holds the version
#' @return A semantic version, or `NULL` when the answer holds none
#' @keywords internal
maidr_parse_resolver_response <- function(body, field) {
  payload <- jsonlite::fromJSON(body, simplifyVector = FALSE)
  if (!is.list(payload) || is.null(names(payload))) {
    return(NULL)
  }

  version <- payload[[field]]
  if (!is.character(version) || length(version) != 1 || is.na(version)) {
    return(NULL)
  }

  version <- trimws(version)
  if (!maidr_is_semver(version)) {
    return(NULL)
  }
  version
}

#' The time budget for the CDN version lookup, in seconds
#'
#' The `maidr.cdn_timeout` option, then the `MAIDR_CDN_TIMEOUT` environment
#' variable, then 3 seconds. A value that is not a positive number warns once
#' and the default applies -- `0` does not mean "skip the lookup"; that is
#' `maidr.cdn_version = "latest"` or `"bundled"`. A value outside 0.1 to 30
#' seconds warns once and is clamped: below the floor every lookup would time
#' out, and above the ceiling a value meant as milliseconds would hang a
#' render.
#'
#' @return A number of seconds in `[0.1, 30]`
#' @keywords internal
maidr_cdn_timeout <- function() {
  value <- getOption("maidr.cdn_timeout")
  source <- "Option `maidr.cdn_timeout`"
  if (is.null(value)) {
    value <- Sys.getenv("MAIDR_CDN_TIMEOUT", unset = "")
    source <- "Environment variable `MAIDR_CDN_TIMEOUT`"
    if (!nzchar(trimws(value))) {
      return(MAIDR_CDN_DEFAULT_TIMEOUT)
    }
  }

  maidr_bound_cdn_timeout(value, source)
}

#' Check a configured CDN lookup budget and clamp it
#'
#' @param value The setting as given
#' @param source What the setting is called, for the warning
#' @return A number of seconds in `[0.1, 30]`
#' @keywords internal
maidr_bound_cdn_timeout <- function(value, source) {
  shown <- maidr_cdn_deparse(value)
  numeric_like <- length(value) == 1 && (is.numeric(value) || is.character(value))
  seconds <- if (numeric_like) suppressWarnings(as.numeric(value)) else NA_real_

  if (!is.finite(seconds) || seconds <= 0) {
    maidr_cdn_warn_once(
      paste(source, shown),
      sprintf(
        paste0(
          "%s is %s, which is not a positive number of seconds; the %s-second ",
          "default applies. To skip the CDN version lookup, set ",
          "`options(maidr.cdn_version = \"latest\")` or \"bundled\"."
        ),
        source, shown, MAIDR_CDN_DEFAULT_TIMEOUT
      )
    )
    return(MAIDR_CDN_DEFAULT_TIMEOUT)
  }

  bounded <- min(max(seconds, MAIDR_CDN_MIN_TIMEOUT), MAIDR_CDN_MAX_TIMEOUT)
  if (bounded != seconds) {
    maidr_cdn_warn_once(
      paste(source, shown),
      sprintf(
        paste0(
          "%s is %s seconds, outside %s to %s; %s seconds is used. The value ",
          "is in seconds."
        ),
        source, shown, MAIDR_CDN_MIN_TIMEOUT, MAIDR_CDN_MAX_TIMEOUT, bounded
      )
    )
  }
  bounded
}
