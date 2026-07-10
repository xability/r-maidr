#!/usr/bin/env Rscript
# Strip the embedded base64 @font-face (KaTeX) blocks from the bundled
# maidr.css. These fonts are ~1.4 MB and push the installed package over
# CRAN's 5 MB soft size limit. Removing them only affects KaTeX *math
# typography* (glyphs fall back to system fonts); maidr's accessibility
# payload (SVG + maidr-data JSON + sonification) is unaffected.
#
# IMPORTANT: re-run this after every bundled-MAIDR update, because pulling a
# fresh maidr.css from the CDN restores the full KaTeX font data.
#
# Usage (from the package root):
#   Rscript tools/trim-maidr-css.R [version]
# If [version] is omitted, the first inst/htmlwidgets/lib/maidr-* dir is used.

args <- commandArgs(trailingOnly = TRUE)

if (length(args) >= 1L) {
  css_path <- sprintf("inst/htmlwidgets/lib/maidr-%s/maidr.css", args[[1L]])
} else {
  dirs <- list.dirs("inst/htmlwidgets/lib", recursive = FALSE)
  dirs <- dirs[grepl("^maidr-", basename(dirs))]
  if (length(dirs) == 0L) {
    stop("No inst/htmlwidgets/lib/maidr-* directory found.", call. = FALSE)
  }
  css_path <- file.path(dirs[[1L]], "maidr.css")
}

if (!file.exists(css_path)) {
  stop("CSS file not found: ", css_path, call. = FALSE)
}

css <- paste(readLines(css_path, warn = FALSE), collapse = "\n")
before <- nchar(css, type = "bytes")
n_blocks <- length(attr(gregexpr("@font-face\\{", css)[[1L]], "match.length"))

# @font-face blocks contain no nested braces (base64/url/format have none),
# so a non-greedy [^}]* is safe.
css <- gsub("@font-face\\{[^}]*\\}", "", css, perl = TRUE)

writeLines(css, css_path)
after <- nchar(css, type = "bytes")
cat(sprintf(
  "Stripped %d @font-face block(s) from %s: %d -> %d bytes\n",
  n_blocks, css_path, before, after
))
