#!/usr/bin/env Rscript
# Strip the embedded base64 @font-face (KaTeX) blocks from the bundled MAIDR
# stylesheets. These fonts are ~1.4 MB and push the installed package over
# CRAN's 5 MB soft size limit. Removing them only affects KaTeX *math
# typography* (glyphs fall back to system fonts); maidr's accessibility
# payload (SVG + maidr-data JSON + sonification) is unaffected.
#
# WHICH FILE CARRIES THE FONTS DEPENDS ON THE BUNDLED VERSION.  maidr.js used
# to inline KaTeX into `maidr.css`; it now publishes the stylesheet separately
# as `maidr-math.css` and fetches it at runtime only for the AI chat responses
# that actually contain maths.  So this trims whichever of the two is present
# and still carries @font-face blocks, and reports the ones that had none.
#
# On a bundle new enough to have split them out, `maidr.css` is a few hundred
# bytes and there is nothing left in it to strip -- the saving has already been
# made upstream, and the only file worth trimming is `maidr-math.css`.
#
# IMPORTANT: re-run this after every bundled-MAIDR update, because pulling a
# fresh bundle restores the full KaTeX font data.
#
# Usage (from the package root):
#   Rscript tools/trim-maidr-css.R [version]
# If [version] is omitted, the first inst/htmlwidgets/lib/maidr-* dir is used.

args <- commandArgs(trailingOnly = TRUE)

if (length(args) >= 1L) {
  bundle_dir <- sprintf("inst/htmlwidgets/lib/maidr-%s", args[[1L]])
} else {
  dirs <- list.dirs("inst/htmlwidgets/lib", recursive = FALSE)
  dirs <- dirs[grepl("^maidr-", basename(dirs))]
  if (length(dirs) == 0L) {
    stop("No inst/htmlwidgets/lib/maidr-* directory found.", call. = FALSE)
  }
  bundle_dir <- dirs[[1L]]
}

if (!dir.exists(bundle_dir)) {
  stop("Bundle directory not found: ", bundle_dir, call. = FALSE)
}

#' Strip every @font-face block from one stylesheet, in place.
#'
#' @param css_path Path to the stylesheet. Missing files are skipped: which of
#'   the two stylesheets exists depends on the bundled maidr.js version.
#' @return Invisibly, the number of blocks removed.
trim_font_faces <- function(css_path) {
  if (!file.exists(css_path)) {
    return(invisible(0L))
  }

  css <- paste(readLines(css_path, warn = FALSE), collapse = "\n")
  before <- nchar(css, type = "bytes")
  matches <- gregexpr("@font-face\\{", css)[[1L]]
  n_blocks <- if (matches[[1L]] == -1L) 0L else length(matches)

  if (n_blocks == 0L) {
    cat(sprintf("No @font-face blocks in %s; nothing to strip\n", css_path))
    return(invisible(0L))
  }

  # @font-face blocks contain no nested braces (base64/url/format have none),
  # so a non-greedy [^}]* is safe.
  css <- gsub("@font-face\\{[^}]*\\}", "", css, perl = TRUE)

  writeLines(css, css_path)
  after <- nchar(css, type = "bytes")
  cat(sprintf(
    "Stripped %d @font-face block(s) from %s: %d -> %d bytes\n",
    n_blocks, css_path, before, after
  ))
  invisible(n_blocks)
}

# Both are attempted so the script works across the version boundary without
# the caller having to know which side of it the bundle sits on.
stripped <- sum(vapply(
  c("maidr.css", "maidr-math.css"),
  function(name) trim_font_faces(file.path(bundle_dir, name)),
  integer(1L)
))

if (stripped == 0L) {
  cat("Nothing to trim: this bundle carries no inlined fonts.\n")
}
