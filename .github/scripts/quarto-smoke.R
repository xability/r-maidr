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
#     Quarto puts them in a bslib card, which a reader can show full screen.
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
