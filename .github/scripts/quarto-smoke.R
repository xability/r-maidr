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
#   * `dash.qmd`, a dashboard of R charts at 3 x 2 in, smaller than their
#     cards, each with a title of its own: Quarto puts each in a bslib card
#     of its own, titled by its chunk, which a reader can show full screen;
#     beside the first two a grid drawing maidr does not read, an image
#     Quarto fills its card with, which the charts fill theirs as; and below
#     them, in a row too short for maidr's braille field below a chart, a
#     scatter plot and a bar plot;
#   * `deck.qmd`, a reveal.js deck with a 4 x 3 in chart on its second
#     slide, after a link taken out of the tab order, as pandoc takes the
#     anchors of a code block's lines; a chart in a captioned figure on its
#     third; a 4 x 3 in grid drawing on its fourth, after a line of text,
#     which Quarto stretches as the lone figure of its slide, as the chart
#     of the second is stretched; a slide after them; and two slides where
#     Quarto stretches no figure, a 4 x 3 in chart below a line of text on
#     a slide marked `.nostretch` and one in the left of two columns;
#   * `fig.qmd`, an HTML page with a chart in a captioned figure narrower
#     than the page's column, which Quarto centres unless told otherwise;
#     then a chart and a grid drawing at Quarto's 7 x 5 in, and a chart and
#     a drawing at `out-width: 100%`, wider than their own size.
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
    "fig-width: 3",
    "fig-height: 2",
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
    "```",
    "",
    "```{r}",
    "#| title: Picture",
    drawing,
    "```",
    "",
    "## Row {height=20%}",
    "",
    "```{r}",
    "#| title: Points",
    "points <- data.frame(x = c(1, 2, 3), y = c(31, 12, 23))",
    "ggplot(points, aes(x, y)) + geom_point(size = 3)",
    "```",
    "",
    "```{r}",
    "#| title: Counts",
    "barplot(c(short1 = 4, short2 = 5, short3 = 6))",
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
    "#| fig-width: 4",
    "#| fig-height: 3",
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
    "## A picture",
    "",
    "A grey circle.",
    "",
    "```{r}",
    "#| fig-width: 4",
    "#| fig-height: 3",
    drawing,
    "```",
    "",
    "## The end",
    "",
    "Thanks.",
    "",
    "## Not stretched {.nostretch}",
    "",
    "A line of text.",
    "",
    "```{r}",
    "#| fig-width: 4",
    "#| fig-height: 3",
    "ggplot(slide, aes(kind, n)) + geom_col()",
    "```",
    "",
    "## In a column",
    "",
    ":::: {.columns}",
    "::: {.column width=\"50%\"}",
    "",
    "```{r}",
    "#| fig-width: 4",
    "#| fig-height: 3",
    "ggplot(slide, aes(kind, n)) + geom_col()",
    "```",
    "",
    ":::",
    "::: {.column width=\"50%\"}",
    "Beside the chart.",
    ":::",
    "::::"
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
    "```",
    "",
    "```{r}",
    "#| out-width: 100%",
    "ggplot(mtcars, aes(factor(carb))) + geom_bar()",
    "```",
    "",
    "```{r}",
    "#| fig-alt: A wide grey circle",
    "#| out-width: 100%",
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
