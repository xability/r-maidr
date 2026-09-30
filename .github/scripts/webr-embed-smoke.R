#!/usr/bin/env Rscript
# Write the JavaScript `show()` sends to the page when it runs under webR.
#
# Under webR the chart is shown by running a script on the page that adds an
# iframe (R/webr_support.R). There is no webR in CI, but the script is plain
# JavaScript built from the chart's document, so it can be made here and run in
# a browser by `webr-embed-smoke.mjs`: the same document `show()` builds for
# webR, handed to the same function, written to a file.
#
#     Rscript .github/scripts/webr-embed-smoke.R <out-dir>

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1) {
  stop("usage: webr-embed-smoke.R <out-dir>", call. = FALSE)
}
out <- args[1]
dir.create(out, showWarnings = FALSE, recursive = TRUE)

suppressPackageStartupMessages({
  library(maidr)
  library(ggplot2)
})
options(maidr.auto_show = FALSE)

three <- data.frame(x = c("a", "b", "c"), y = c(3, 5, 2))
plot <- ggplot(three, aes(x, y)) + geom_col()

document <- maidr:::maidr_webr_document(
  maidr:::create_maidr_html(plot, use_cdn = FALSE)
)
writeLines(maidr:::maidr_webr_show_js(document), file.path(out, "show.js"), useBytes = TRUE)
