#!/usr/bin/env Rscript
# Render the Quarto documents the Quarto smoke test drives.
#
# Quarto, rendering R chunks with 'knitr', shows maidr's charts inline as R
# Markdown does, and its formats put them where `knitr-smoke.R`'s page does
# not. This writes a document of each, with nothing but `library(maidr)` in
# its setup chunk, and renders it with the Quarto CLI on the PATH, the way
# an author does; `quarto-smoke.mjs` then uses the charts from the keyboard
# in headless Chromium:
#
#   * `dash.qmd`, a dashboard of two R charts, each with a title of its own:
#     Quarto puts each in a bslib card of its own, titled by its chunk,
#     which a reader can show full screen;
#   * `deck.qmd`, a reveal.js deck with a chart on its second slide, after
#     a link taken out of the tab order, as pandoc takes the anchors of a
#     code block's lines; a chart in a captioned figure on its third; and a
#     slide after them;
#   * `fig.qmd`, an HTML page with a chart in a captioned figure narrower
#     than the page's column, which Quarto centres unless told otherwise;
#     then a chart and a grid drawing at Quarto's 7 x 5 in.
#
#     Rscript .github/scripts/quarto-smoke.R <out-dir>

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1) {
  stop("usage: quarto-smoke.R <out-dir>", call. = FALSE)
}
out <- args[1]
dir.create(out, showWarnings = FALSE, recursive = TRUE)

quarto <- Sys.which("quarto")
if (!nzchar(quarto)) {
  stop("the Quarto CLI is not on the PATH", call. = FALSE)
}
# The R that runs this, which has maidr installed, runs the chunks.
Sys.setenv(QUARTO_R = R.home("bin"))

setup <- c(
  "```{r}",
  "#| include: false",
  "library(maidr)",
  "library(ggplot2)",
  "```",
  ""
)
# A drawing maidr does not read, which stays Quarto's own figure, for the
# size a chart is shown at to be checked against.
drawing <- c(
  "grid::grid.newpage()",
  "grid::grid.circle(gp = grid::gpar(fill = \"grey\"))"
)

documents <- list(
  dash = c(
    "---",
    "title: \"maidr dashboard smoke\"",
    "format: dashboard",
    "---",
    "",
    setup,
    "## Row",
    "",
    "```{r}",
    "#| title: Cylinders",
    "cyl <- data.frame(cyl = c(\"cyl4\", \"cyl6\", \"cyl8\"), n = c(11, 7, 14))",
    "ggplot(cyl, aes(cyl, n)) + geom_col()",
    "```",
    "",
    "```{r}",
    "#| title: Gears",
    "barplot(c(gear3 = 15, gear4 = 12, gear5 = 5))",
    "```"
  ),
  deck = c(
    "---",
    "title: \"maidr deck smoke\"",
    "format: revealjs",
    "---",
    "",
    setup,
    "## A chart",
    "",
    "[The end](#the-end){tabindex=\"-1\"}",
    "",
    "```{r}",
    "slide <- data.frame(kind = c(\"slide1\", \"slide2\", \"slide3\"), n = c(21, 22, 23))",
    "ggplot(slide, aes(kind, n)) + geom_col()",
    "```",
    "",
    "## A figure",
    "",
    "```{r}",
    "#| label: fig-gears",
    "#| fig-cap: Gears",
    "barplot(c(gear3 = 15, gear4 = 12, gear5 = 5))",
    "```",
    "",
    "## The end",
    "",
    "Thanks."
  ),
  fig = c(
    "---",
    "title: \"maidr figure smoke\"",
    "format: html",
    "---",
    "",
    setup,
    "```{r}",
    "#| label: fig-cylinders",
    "#| fig-cap: Cars by cylinder",
    "#| fig-width: 4",
    "#| fig-height: 3",
    "ggplot(mtcars, aes(factor(cyl))) + geom_bar()",
    "```",
    "",
    "```{r}",
    "ggplot(mtcars, aes(factor(gear))) + geom_bar()",
    "```",
    "",
    "```{r}",
    "#| fig-alt: A plain grey circle",
    drawing,
    "```"
  )
)

for (name in names(documents)) {
  qmd <- file.path(out, paste0(name, ".qmd"))
  writeLines(documents[[name]], qmd)
  status <- system2(quarto, c("render", shQuote(qmd), "--quiet"))
  if (!identical(status, 0L)) {
    stop("quarto render ", qmd, " failed with status ", status, call. = FALSE)
  }
}
