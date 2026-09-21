#!/usr/bin/env Rscript
# Render the charts the highlight smoke test drives, as offline documents.
#
# One HTML file per chart into the directory named on the command line, each
# carrying the bundled maidr.js (`use_cdn = FALSE`) so what the browser loads
# is the bundle this tree ships and nothing served from a CDN. The set is the
# layer types whose frontend model reads `selectors` as one string for every
# mark -- the ones the 4.0 bundle refresh silently stopped highlighting
# (#316) -- plus line, smooth and heat, which kept working through it and
# show that the browser side of the test is alive.
#
# Every fixture is drawn so that the first cell Right Arrow lands on has a
# mark: a stacked bar with an empty first cell would highlight nothing and
# say nothing about the contract.
#
#     Rscript .github/scripts/highlight-smoke.R <out-dir>

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1) {
  stop("usage: highlight-smoke.R <out-dir>", call. = FALSE)
}
out <- args[1]
dir.create(out, showWarnings = FALSE, recursive = TRUE)

suppressPackageStartupMessages({
  library(maidr)
  library(ggplot2)
})
options(maidr.auto_show = FALSE)

write_ggplot <- function(name, plot) {
  save_html(plot, file.path(out, paste0(name, ".html")), use_cdn = FALSE)
}

three <- data.frame(x = c("a", "b", "c"), y = c(3, 5, 2))
crossed <- data.frame(
  cat = rep(c("a", "b", "c"), times = 2),
  grp = rep(c("u", "v"), each = 3),
  val = c(10, 20, 30, 55, 65, 75)
)
heat <- data.frame(
  x = rep(c("a", "b", "c"), 3),
  y = rep(c("p", "q", "r"), each = 3),
  v = as.numeric(1:9)
)

write_ggplot("ggplot2-bar", ggplot(three, aes(x, y)) + geom_col())
write_ggplot("ggplot2-point", ggplot(mtcars, aes(wt, mpg)) + geom_point())
write_ggplot("ggplot2-hist", ggplot(mtcars, aes(mpg)) + geom_histogram(bins = 8))
write_ggplot(
  "ggplot2-dodged",
  ggplot(crossed, aes(cat, val, fill = grp)) + geom_col(position = "dodge")
)
write_ggplot(
  "ggplot2-stacked",
  ggplot(crossed, aes(cat, val, fill = grp)) + geom_col()
)
write_ggplot(
  "ggplot2-normalized",
  ggplot(crossed, aes(cat, val, fill = grp)) + geom_col(position = "fill")
)
write_ggplot(
  "ggplot2-pie",
  ggplot(three, aes(x = "", y = y, fill = x)) + geom_col() + coord_polar("y")
)
write_ggplot(
  "ggplot2-line",
  ggplot(data.frame(x = 1:10, y = (1:10)^2), aes(x, y)) + geom_line()
)
write_ggplot(
  "ggplot2-smooth",
  ggplot(mtcars, aes(wt, mpg)) +
    geom_smooth(se = FALSE, method = "loess", formula = y ~ x)
)
write_ggplot("ggplot2-heat", ggplot(heat, aes(x, y, fill = v)) + geom_tile())

maidr_on()
write_base_r <- function(name, draw) {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  draw()
  save_html(file = file.path(out, paste0(name, ".html")), use_cdn = FALSE)
}

counts <- matrix(1:6, 2, dimnames = list(c("u", "v"), c("a", "b", "c")))
write_base_r("base-barplot", function() barplot(c(a = 3, b = 5, c = 2)))
write_base_r("base-hist", function() hist(mtcars$mpg))
write_base_r("base-plot", function() plot(mtcars$wt, mtcars$mpg))
write_base_r("base-pie", function() pie(c(a = 3, b = 5, c = 2)))
write_base_r("base-dotchart", function() dotchart(c(a = 3, b = 5, c = 2)))
write_base_r("base-lollipop", function() plot(1:5, c(2, 4, 1, 5, 3), type = "h"))
write_base_r("base-dodged", function() barplot(counts, beside = TRUE))
write_base_r("base-stacked", function() barplot(counts))
write_base_r("base-line", function() plot(1:10, (1:10)^2, type = "l"))

cat(length(list.files(out, pattern = "\\.html$")), "documents written to", out, "\n")
