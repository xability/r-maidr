#!/usr/bin/env Rscript
# Render the R Markdown page the knitr smoke test drives.
#
# A knitted HTML page shows its charts inline: each is the page's own <svg>,
# its ids prefixed, and the page loads maidr.js once for all of them
# (R/knitr_inline.R). The tests read what the knit writes; none of them runs
# maidr.js on it, so a page where the charts are written correctly and no
# chart can be used would pass them. This writes one document with charts of
# every system, several to a page and to a chunk, and renders it the way an
# author does, with `rmarkdown::render()` and nothing but `library(maidr)` in
# its setup chunk; `knitr-smoke.mjs` then uses each chart from the keyboard
# in headless Chromium.
#
# The document holds, in this order -- the order `knitr-smoke.mjs` expects
# them in, with the values it expects each to announce:
#
#   * a ggplot2 bar chart, and a ggplot2 facet of two panels;
#   * two ggplot2 charts printed with print() in a loop, in one chunk;
#   * a lattice bar chart;
#   * two Base R charts in one chunk, a bar plot and a line;
#   * a ggplot2 bar chart in a chunk of `fig.width = 10, fig.height = 4`,
#     a Base R bar plot in one of `fig.width = 5, fig.height = 8`, and a
#     Base R 2 x 2 `par(mfrow)` grid in one of `fig.width = 10,
#     fig.height = 4`, whose short panels R thins the tick labels of: the
#     others are at html_document's own 7 x 5 in;
#   * a ggplot2 bar chart in the second tab of a {.tabset}, hidden when the
#     page loads;
#   * a grid drawing maidr does not read, which stays knitr's own figure.
#
# Every chart's values are its own, so an announcement names the chart it
# came from. The page is self-contained: maidr.js is embedded once, and no
# file beside it is needed.
#
#     Rscript .github/scripts/knitr-smoke.R <out-dir>

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1) {
  stop("usage: knitr-smoke.R <out-dir>", call. = FALSE)
}
out <- args[1]
dir.create(out, showWarnings = FALSE, recursive = TRUE)

rmd <- file.path(out, "charts.Rmd")
writeLines(c(
  "---",
  "title: \"maidr knitr smoke\"",
  "output:",
  "  html_document:",
  "    self_contained: true",
  "---",
  "",
  "```{r setup, include = FALSE}",
  "library(maidr)",
  "library(ggplot2)",
  "library(lattice)",
  "```",
  "",
  "## ggplot2",
  "",
  "```{r gg-bar}",
  "bars <- data.frame(kind = c(\"alpha\", \"beta\", \"gamma\"), n = c(11, 12, 13))",
  "ggplot(bars, aes(kind, n)) + geom_col() + labs(title = \"GG bar chart\")",
  "```",
  "",
  "```{r gg-facet}",
  "sides <- data.frame(",
  "  x = rep(1:3, 2),",
  "  y = c(21, 22, 23, 24, 25, 26),",
  "  side = rep(c(\"left\", \"right\"), each = 3)",
  ")",
  "ggplot(sides, aes(x, y)) + geom_point() + facet_wrap(~side) +",
  "  labs(title = \"GG facet chart\")",
  "```",
  "",
  "```{r gg-loop}",
  "for (i in 1:2) {",
  "  loop <- data.frame(item = paste0(\"loop\", i, c(\"a\", \"b\")), v = 30 + 10 * i + 0:1)",
  "  print(ggplot(loop, aes(item, v)) + geom_col() + labs(title = paste(\"Loop chart\", i)))",
  "}",
  "```",
  "",
  "## lattice",
  "",
  "```{r lattice-bar}",
  "lat <- data.frame(k = c(\"lat1\", \"lat2\", \"lat3\"), v = c(61, 62, 63))",
  "barchart(v ~ k, data = lat, origin = 0, main = \"Lattice bar chart\")",
  "```",
  "",
  "## Base R",
  "",
  "```{r base-two}",
  "barplot(c(71, 72, 73), names.arg = c(\"base1\", \"base2\", \"base3\"),",
  "  main = \"Base bar chart\")",
  "plot(1:3, c(81, 82, 83), type = \"l\", main = \"Base line chart\")",
  "```",
  "",
  "## Sizes",
  "",
  "```{r sized-wide, fig.width = 10, fig.height = 4}",
  "wide <- data.frame(span = c(\"wide1\", \"wide2\", \"wide3\"), n = c(101, 102, 103))",
  "ggplot(wide, aes(span, n)) + geom_col() + labs(title = \"Wide bar chart\")",
  "```",
  "",
  "```{r sized-tall, fig.width = 5, fig.height = 8}",
  "barplot(c(111, 112, 113), names.arg = c(\"tall1\", \"tall2\", \"tall3\"),",
  "  main = \"Tall bar chart\")",
  "```",
  "",
  "```{r sized-grid, fig.width = 10, fig.height = 4}",
  "par(mfrow = c(2, 2))",
  "for (i in 1:4) {",
  "  plot(1:10, seq(121, 125, length.out = 10) + 10 * (i - 1),",
  "    main = \"Base grid chart\", xlab = \"step\", ylab = \"level\")",
  "}",
  "```",
  "",
  "## Tabs {.tabset}",
  "",
  "### Shown",
  "",
  "The chart is in the next tab, hidden when the page loads.",
  "",
  "### Hidden",
  "",
  "```{r tab-chart}",
  "tab <- data.frame(tab = c(\"hid1\", \"hid2\"), v = c(91, 92))",
  "ggplot(tab, aes(tab, v)) + geom_col() + labs(title = \"Hidden tab chart\")",
  "```",
  "",
  "## A drawing maidr does not read",
  "",
  "```{r static, fig.alt = \"A plain grey circle\"}",
  "grid::grid.newpage()",
  "grid::grid.circle(gp = grid::gpar(fill = \"grey\"))",
  "```"
), rmd)

rmarkdown::render(rmd, output_file = "charts.html", quiet = TRUE, envir = new.env())
