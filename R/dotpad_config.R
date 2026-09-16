# The shipped DotPad SDK manifest, parsed once. Every render path asks for
# it several times over and it cannot change while the package is loaded.
.maidr_dotpad_cache <- new.env(parent = emptyenv())

#' Where maidr.js loads the DotPad SDK from
#'
#' maidr.js does not bundle the DotPad tactile-display SDK: its braille engine
#' is a 14 MB liblouis build that every document would carry for the few
#' readers who own the device. So the first time a reader connects a DotPad,
#' maidr.js imports the SDK from the vendor's published copy on jsDelivr,
#' pinned to a commit. That is the one path an offline document
#' (`use_cdn = FALSE`) still takes to the network. The document renders,
#' sonifies and brailles without it; only connecting a DotPad needs it, unless
#' the page names its own copy of the SDK, or one was downloaded with
#' [maidr_download_dotpad_sdk()] for `save_html()` to carry.
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

# ==============================================================================
# Carrying a copy of the SDK
# ==============================================================================

#' The DotPad SDK maidr.js is pinned to
#'
#' maidr.js loads the SDK from one commit of a repository on jsDelivr, and
#' this is that pin, with the size and digests of every file a copy consists
#' of. It is read from `inst/dotpad-sdk.json`, a copy of the
#' `dist/dotpad-sdk.json` the maidr npm package ships as the single source of
#' truth for its own pin. `.github/scripts/fetch-maidr-bundle.sh` refreshes
#' the file with the bundle, so the two cannot drift once the bundled
#' maidr.js is one that ships it. The maidr.js this package bundles (see
#' `MAIDR_VERSION`) predates the file and still falls back to earlier commits
#' of the vendor's repository when nothing on the page names a copy. That
#' fallback is exactly what a downloaded copy or a configured URL replaces,
#' so what a document loads is this pin either way; the bundle catches up at
#' its next refresh (`tools/update-maidr-assets.R`).
#'
#' The files are served from `xability/dotpad-sdk-guide`, a mirror of the
#' vendor's `dotincorp/dotpad-sdk-guide`. The vendor publishes SDK 3.0.3
#' only as a zip archive, which jsDelivr cannot serve a file out of, so the
#' mirror carries the extracted files, byte-verified against the archive;
#' the manifest's `upstream` entry records the vendor commit, the archive
#' path and its SHA-256.
#'
#' The pin matters beyond immutability. Earlier commits of the vendor's
#' repository carry a corrupt `liblouis.data`: its `.gitattributes` said
#' `* text=auto` and the file is braille-table text with no NUL byte in it,
#' so git rewrote its line endings on commit. It is an Emscripten package
#' addressed by absolute byte offsets, so every table after the first dropped
#' byte was read from the wrong place and the braille line silently fell back
#' to grade 1. The pinned files carry the intact bytes.
#'
#' The liblouis build is LGPL-2.1-or-later. Its licence text and the sources
#' of the WebAssembly wrapper are listed because the vendor's README asks
#' anyone who redistributes the SDK to keep them beside the runtime files,
#' which is the LGPL's relinking requirement.
#'
#' Read once per session: every render path asks for the manifest several
#' times over, and the answer cannot change while the package is loaded.
#'
#' @return A list: `version`, `repository`, `commit`, `base_url`, `module`,
#'   `asset_dir`, and `files`, a data frame with one row per file (`path`,
#'   `bytes`, `md5`, `sha256`).
#' @keywords internal
maidr_dotpad_sdk_manifest <- function() {
  cached <- .maidr_dotpad_cache$manifest
  if (!is.null(cached)) {
    return(cached)
  }
  manifest <- maidr_dotpad_read_manifest()
  .maidr_dotpad_cache$manifest <- manifest
  manifest
}

#' Parse the shipped DotPad SDK manifest
#'
#' Split from [maidr_dotpad_sdk_manifest()] so the read happens once and the
#' parsing is testable on its own. Every field is checked, because the file
#' is not authored here: `fetch-maidr-bundle.sh` copies whatever
#' `dist/dotpad-sdk.json` the pinned `maidr.js` release ships. A field that
#' changed shape upstream is named as a bad manifest rather than surfacing
#' later as a `vapply` type error.
#'
#' @param path Where to read from. Defaults to the installed `inst/` copy.
#' @return The manifest, in the shape [maidr_dotpad_sdk_manifest()] returns.
#' @keywords internal
maidr_dotpad_read_manifest <- function(path = NULL) {
  if (is.null(path)) {
    path <- system.file("dotpad-sdk.json", package = "maidr", mustWork = TRUE)
  }
  pins <- jsonlite::fromJSON(path, simplifyVector = FALSE)
  text_field <- function(name) {
    value <- pins[[name]]
    if (!is.character(value) || length(value) != 1L || !nzchar(value)) {
      stop(
        sprintf("dotpad-sdk.json names no %s: the manifest is not one", name),
        call. = FALSE
      )
    }
    value
  }
  slashed <- function(name) {
    value <- text_field(name)
    if (!endsWith(value, "/")) {
      # Both are pasted straight onto a file's path. Without the slash the
      # URLs come out joined, and the only sign is a 404 per file.
      stop(
        sprintf("dotpad-sdk.json gives %s no trailing slash", name),
        call. = FALSE
      )
    }
    value
  }
  version <- text_field("version")
  repository <- text_field("repository")
  commit <- text_field("commit")
  base_url <- slashed("baseUrl")
  module <- text_field("module")
  asset_dir <- slashed("assetDir")
  # Keyed by path, not a bare array. An array parses to a list with no
  # names, which would leave a manifest of no files rather than an error --
  # and no files is what every "is the copy complete" check reads as
  # complete, since all() of nothing is TRUE.
  if (!is.list(pins$files) || length(pins$files) == 0L) {
    stop("dotpad-sdk.json names no files", call. = FALSE)
  }
  paths <- names(pins$files)
  if (is.null(paths) || !all(nzchar(paths)) || anyDuplicated(paths) != 0L) {
    stop(
      "dotpad-sdk.json does not name its files: 'files' is not an object keyed by path",
      call. = FALSE
    )
  }
  entry <- function(file_path, name, check) {
    file <- pins$files[[file_path]]
    value <- if (is.list(file)) file[[name]] else NULL
    if (is.null(value) || !check(value)) {
      stop(
        sprintf("dotpad-sdk.json gives %s no usable %s", file_path, name),
        call. = FALSE
      )
    }
    value
  }
  is_size <- function(value) {
    is.numeric(value) && length(value) == 1L && value > 0
  }
  is_digest <- function(width) {
    function(value) {
      is.character(value) && length(value) == 1L &&
        grepl(sprintf("^[0-9a-f]{%d}$", width), value)
    }
  }
  files <- data.frame(
    path = paths,
    bytes = vapply(paths, entry, numeric(1),
      name = "bytes", check = is_size, USE.NAMES = FALSE
    ),
    md5 = vapply(paths, entry, character(1),
      name = "md5", check = is_digest(32), USE.NAMES = FALSE
    ),
    sha256 = vapply(paths, entry, character(1),
      name = "sha256", check = is_digest(64), USE.NAMES = FALSE
    ),
    stringsAsFactors = FALSE
  )
  list(
    version = version,
    repository = repository,
    commit = commit,
    base_url = base_url,
    module = module,
    asset_dir = asset_dir,
    files = files
  )
}

#' Where a downloaded copy of the DotPad SDK lives
#'
#' The option `maidr.dotpad_sdk_dir`, then the environment variable
#' `MAIDR_DOTPAD_SDK_DIR`, then a per-user cache directory from
#' [tools::R_user_dir()] (`~/.cache/R/maidr/dotpad-sdk/<version>` on Linux,
#' where the version is the manifest's, `3.0.3` today).
#' Nothing is created by asking.
#'
#' @return A single path
#' @keywords internal
maidr_dotpad_sdk_dir <- function() {
  configured <- maidr_dotpad_setting("maidr.dotpad_sdk_dir", "MAIDR_DOTPAD_SDK_DIR")
  if (!is.null(configured)) {
    return(path.expand(configured))
  }
  file.path(
    tools::R_user_dir("maidr", "cache"),
    "dotpad-sdk",
    maidr_dotpad_sdk_manifest()$version
  )
}

#' Download one file of the SDK
#'
#' A seam for the tests, which replace it rather than reach the network.
#'
#' Bounded rather than left to hang: a connection that takes more than half
#' a minute to open, or that delivers under a kilobyte a second for a full
#' minute, fails like any other error. A slow link still gets the 14 MB
#' engine; a stalled one does not hold the session for good.
#'
#' @param url Where the file is
#' @param destfile Where to write it
#' @return `destfile`, invisibly
#' @keywords internal
maidr_dotpad_download_file <- function(url, destfile) {
  handle <- curl::new_handle(
    connecttimeout = 30L,
    low_speed_limit = 1024L,
    low_speed_time = 60L
  )
  curl::curl_download(url, destfile, mode = "wb", quiet = TRUE, handle = handle)
  invisible(destfile)
}

#' Why a file is not the one the manifest describes, or `NULL`
#'
#' Size first, because it is the failure with a story: the corrupt
#' `liblouis.data` that motivated the pin was 7,685 bytes short, and a size
#' says so where a digest only says "different".
#'
#' Then the digests base R can compute: MD5 always, and SHA-256 too from
#' R 4.5, which added `tools::sha256sum()`. The manifest carries both so the
#' stronger check is used wherever it is available without adding a
#' dependency for the older R this package supports.
#'
#' @param path The file on disk
#' @param expected One row of the manifest's `files`
#' @return A string naming the difference, or `NULL` when there is none
#' @keywords internal
maidr_dotpad_file_mismatch <- function(path, expected) {
  if (!file.exists(path)) {
    return("missing")
  }
  size <- file.info(path)$size
  if (size != expected$bytes) {
    return(sprintf("expected %d bytes, got %d", as.integer(expected$bytes), as.integer(size)))
  }
  digest <- unname(tools::md5sum(path))
  if (!identical(digest, expected$md5)) {
    return(sprintf("expected md5 %s, got %s", expected$md5, digest))
  }
  sha256sum <- get0("sha256sum", envir = asNamespace("tools"), mode = "function")
  if (!is.null(sha256sum)) {
    digest <- unname(sha256sum(path))
    if (!identical(digest, expected$sha256)) {
      return(sprintf("expected sha256 %s, got %s", expected$sha256, digest))
    }
  }
  NULL
}

#' Download the DotPad SDK for use offline
#'
#' maidr.js drives a [DotPad tactile display](https://maidr.ai/docs/TACTILE_DISPLAY.html)
#' through the vendor's SDK, which it does not bundle: the braille engine
#' inside it is a 14 MB liblouis build, and every document would carry it for
#' the few readers who own the device. By default maidr.js imports the
#' vendor's published copy from jsDelivr, pinned to a commit, the first time
#' a DotPad is connected -- the one path an offline document
#' (`use_cdn = FALSE`) still takes to the network.
#'
#' This fetches that pinned copy once -- the module, the liblouis build, and
#' the LGPL licence text and wrapper sources the vendor asks redistributors to
#' keep beside it -- verifying every file against its recorded size and
#' digests (MD5, and SHA-256 on R 4.5 or later), and writes a `manifest.json`
#' beside them naming the commit they came from.
#' From then on [show()] and [save_html()] copy it into `lib/dotpad-sdk-<version>/`
#' next to every `use_cdn = FALSE` document and tell maidr.js where it is, so
#' a reader connects a DotPad without the network. A file already present and
#' correct is left alone, so a second call costs nothing.
#'
#' A page served from somewhere else -- an intranet host, or a knitr document,
#' whose charts live in `srcdoc` frames with no base URL for a relative path
#' to resolve against -- names its copy by URL instead, through the options
#' `maidr.dotpad_sdk_url` and `maidr.dotpad_asset_base_url`; see
#' [maidr-options]. A configured URL wins over a downloaded copy.
#'
#' @param dir Where to write. Defaults to the option `maidr.dotpad_sdk_dir`,
#'   the environment variable `MAIDR_DOTPAD_SDK_DIR`, or a per-user cache
#'   directory.
#' @param force Refetch files that are already present and correct.
#' @param quiet Say nothing about what was fetched.
#' @return The directory, invisibly.
#' @examples
#' \dontrun{
#' maidr_download_dotpad_sdk() # about 14 MB, once
#' save_html(p, "chart.html", use_cdn = FALSE) # carries the SDK in lib/
#' }
#' @seealso [maidr-options] for naming a copy by URL
#' @export
maidr_download_dotpad_sdk <- function(dir = maidr_dotpad_sdk_dir(), force = FALSE, quiet = FALSE) {
  manifest <- maidr_dotpad_sdk_manifest()
  dir <- path.expand(dir)
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)

  # Each file is fetched beside its target and renamed over it, so a reader
  # of the directory never sees a half-written file as the real one. Whatever
  # is left with that suffix when this returns -- by error or interrupt -- is
  # a fetch that did not finish, and goes.
  on.exit(
    unlink(list.files(dir, pattern = "\\.part$", recursive = TRUE, full.names = TRUE)),
    add = TRUE
  )

  for (i in seq_len(nrow(manifest$files))) {
    entry <- manifest$files[i, ]
    target <- file.path(dir, entry$path)
    if (!force && is.null(maidr_dotpad_file_mismatch(target, entry))) {
      next
    }
    url <- paste0(manifest$base_url, entry$path)
    dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
    partial <- paste0(target, ".part")
    maidr_dotpad_download_file(url, partial)
    problem <- maidr_dotpad_file_mismatch(partial, entry)
    if (!is.null(problem)) {
      stop(
        sprintf("DotPad SDK file %s from %s: %s", entry$path, url, problem),
        call. = FALSE
      )
    }
    file.rename(partial, target)
    if (!quiet) {
      message(sprintf("fetched %s (%s bytes)", entry$path, format(entry$bytes, big.mark = ",")))
    }
  }

  record <- list(
    version = manifest$version,
    repository = manifest$repository,
    commit = manifest$commit,
    baseUrl = manifest$base_url,
    module = manifest$module,
    assetDir = manifest$asset_dir,
    files = stats::setNames(
      lapply(seq_len(nrow(manifest$files)), function(i) {
        list(
          bytes = manifest$files$bytes[i],
          sha256 = manifest$files$sha256[i],
          md5 = manifest$files$md5[i]
        )
      }),
      manifest$files$path
    )
  )
  writeLines(
    jsonlite::toJSON(record, auto_unbox = TRUE, pretty = TRUE),
    file.path(dir, "manifest.json")
  )
  if (!quiet) {
    message(sprintf(
      "DotPad SDK %s (%s) is in %s",
      manifest$version,
      substr(manifest$commit, 1, 7),
      dir
    ))
  }
  invisible(dir)
}

#' Whether a directory holds a complete copy of the SDK
#'
#' Complete means every file in the manifest is present at its recorded
#' size. The digests are checked when the copy is made, not on every
#' render, so this costs a handful of `file.info()` calls.
#'
#' @param dir Where to look
#' @return `TRUE` or `FALSE`
#' @keywords internal
maidr_dotpad_sdk_available <- function(dir = maidr_dotpad_sdk_dir()) {
  files <- maidr_dotpad_sdk_manifest()$files
  # With nothing to check against, no directory is a complete copy. all()
  # of nothing is TRUE, which would make every directory one.
  if (nrow(files) == 0L) {
    return(FALSE)
  }
  paths <- file.path(dir, files$path)
  sizes <- file.info(paths)$size
  all(!is.na(sizes) & sizes == files$bytes)
}

#' A downloaded SDK as an htmltools dependency
#'
#' For the documents `show()` and `save_html()` write. htmltools copies the
#' directory into `<libdir>/dotpad-sdk-<version>/` when the document is saved, and
#' the dependency's `head` declares the two globals with that relative path,
#' so the saved page finds its copy wherever the folder is moved to, as long
#' as the two move together. `libdir` is what [htmltools::save_html()] is
#' called with; its default is what this package uses.
#'
#' @param dir A complete copy, as [maidr_dotpad_sdk_available()] reports
#' @param libdir The `libdir` the document is saved with
#' @return An `htmltools::htmlDependency()`
#' @keywords internal
maidr_dotpad_sdk_dependency <- function(dir = maidr_dotpad_sdk_dir(), libdir = "lib") {
  manifest <- maidr_dotpad_sdk_manifest()
  name <- "dotpad-sdk"
  href <- paste0(libdir, "/", name, "-", manifest$version)
  script <- maidr_dotpad_config_script(list(
    sdk_url = paste0(href, "/", manifest$module),
    asset_base_url = paste0(href, "/", manifest$asset_dir)
  ))
  htmltools::htmlDependency(
    name = name,
    version = manifest$version,
    src = c(file = dir),
    all_files = TRUE,
    head = script
  )
}

#' The local SDK dependency, when a document going offline should carry one
#'
#' Applies only to `use_cdn = FALSE`: that is the document whose reader has no
#' network, and the one whose `lib/` folder already travels with it. A session
#' that names its own copy by URL keeps that -- either URL option, set alone
#' or together, wins -- and one that never downloaded the SDK gets exactly
#' what it did before.
#'
#' Either option, not only the module's. Both this dependency and the URL
#' one write the same globals, and the later `head` wins in the browser, so
#' a document carrying both with only the engine's URL configured would load
#' the module from `lib/` and the engine from that URL: the offline copy's
#' worst half, and the network dependency `use_cdn = FALSE` exists to remove.
#'
#' @param use_cdn The document's `use_cdn`, with `NULL` meaning `FALSE`
#' @return An `htmltools::htmlDependency()`, or `NULL`
#' @keywords internal
maidr_dotpad_local_dependency <- function(use_cdn = NULL) {
  if (isTRUE(use_cdn)) {
    return(NULL)
  }
  config <- maidr_dotpad_config()
  if (!is.null(config$sdk_url) || !is.null(config$asset_base_url)) {
    return(NULL)
  }
  dir <- maidr_dotpad_sdk_dir()
  if (!maidr_dotpad_sdk_available(dir)) {
    return(NULL)
  }
  maidr_dotpad_sdk_dependency(dir)
}
