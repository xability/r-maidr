# maidr in a running knit: R/knitr_lifecycle.R, with R/knitr_inline.R's
# test of which documents show charts inline, and the page dependencies in
# R/html_dependencies.R.
#
# A document needs only library(maidr): the first maidr chart, figure or
# Base R call of a knit installs maidr's hooks into it.

# ==============================================================================
# Helpers
# ==============================================================================

#' Put back what a test changes in maidr's and knitr's global state
#'
#' Interception is switched on and off by maidr_on()/maidr_off(), which also
#' install and remove the Base R wrappers; knitr's hooks are put back as they
#' were, since a plain knitr::knit() leaves its option hooks behind.
local_knitr_state <- function(env = parent.frame()) {
  patching <- maidr:::is_patching_active()
  saved <- options("maidr.auto_show", "maidr.base_r", "maidr.ggplot2", "maidr.lattice")
  hooks <- knitr::knit_hooks$get()
  opts_hooks <- knitr::opts_hooks$get()
  enabled <- maidr:::.maidr_knitr_state$enabled
  withr::defer(
    {
      if (patching) maidr::maidr_on() else maidr::maidr_off()
      knitr::knit_hooks$restore(hooks)
      knitr::opts_hooks$restore(opts_hooks)
      knitr::knit_meta(clean = TRUE)
      state <- maidr:::.maidr_knitr_state
      state$enabled <- enabled
      options(saved)
      maidr:::clear_all_device_storage()
    },
    envir = env
  )
  maidr::maidr_on()
  invisible(NULL)
}

#' Knit Markdown text as R Markdown would for a pandoc output format
#'
#' knitr::knit() sets up its Markdown hooks only when every hook is still its
#' default, so the knit starts from the defaults, as a document does in a
#' new session. The setup chunk names the output format, as R Markdown does,
#' and installs maidr into the knit as `library(maidr)` does when it loads
#' maidr; maidr is already loaded here.
#'
#' @param chunks Lines of the document after its setup chunk
#' @param dir Where knitr writes figures (and the cache)
#' @param to The pandoc output format
#' @return The knitted Markdown, as one string
knit_for <- function(chunks, dir, to = "html") {
  hooks <- knitr::knit_hooks$get()
  knitr::knit_hooks$restore()
  on.exit(knitr::knit_hooks$restore(hooks), add = TRUE)
  maidr:::clear_all_device_storage()
  document <- c(
    "```{r setup, include = FALSE}",
    sprintf("knitr::opts_knit$set(rmarkdown.pandoc.to = %s)", deparse(to)),
    sprintf(
      "knitr::opts_chunk$set(fig.path = %s, cache.path = %s)",
      deparse(file.path(dir, "figure", "")), deparse(file.path(dir, "cache", ""))
    ),
    "maidr:::ensure_knitr_integration()",
    "```",
    "",
    chunks
  )
  old <- setwd(dir)
  on.exit(setwd(old), add = TRUE)
  paste(knitr::knit(text = document, quiet = TRUE, envir = new.env()), collapse = "\n")
}

#' The figure files a knit wrote, by chunk label, as file extensions
figure_types <- function(dir) {
  files <- list.files(file.path(dir, "figure"))
  stats::setNames(tools::file_ext(files), sub("-[0-9]+\\.[a-z]+$", "", files))
}

# ==============================================================================
# Page dependencies
# ==============================================================================

test_that("the knitr page loads maidr.js deferred, with its maths stylesheet declared", {
  deps <- maidr:::maidr_knitr_dependencies()
  names <- vapply(deps, function(dep) dep$name, character(1))
  testthat::expect_identical(utils::tail(names, 2L), c("maidr", "maidr-knitr"))

  bundle <- deps[[which(names == "maidr")]]
  testthat::expect_identical(bundle$script, list(list(src = "maidr.js", defer = NA)))
  testthat::expect_identical(unname(unlist(bundle$attachment)), "maidr-math.css")
  testthat::expect_false(bundle$all_files)
  html <- as.character(htmltools::renderDependencies(list(bundle)))
  testthat::expect_match(html, '<script src="[^"]*maidr.js" defer>')
  testthat::expect_match(html, 'id="maidr-math-attachment" rel="attachment"', fixed = TRUE)

  # The configuration still comes first, and the page bundle of the frames
  # is not needed.
  testthat::expect_identical(
    names[seq_len(length(names) - 2L)],
    vapply(
      Filter(function(dep) dep$name != "maidr", maidr:::maidr_html_dependencies(use_cdn = FALSE)),
      function(dep) dep$name, character(1)
    )
  )
  testthat::expect_false("maidr-page-bundle" %in% names)
})

test_that("the knitr page script and stylesheet are installed, and named apart from maidr's", {
  dep <- maidr:::maidr_knitr_dependency()
  dir <- system.file(dep$src$file, package = dep$package)
  testthat::expect_true(file.exists(file.path(dir, dep$script)))
  testthat::expect_true(file.exists(file.path(dir, dep$stylesheet)))
  # maidr.js takes a stylesheet named maidr-*.css for its own when it looks
  # for maidr-math.css.
  pattern <- "(?:^|/)maidr(?:[.-]\\w+)*\\.css(?:$|[?#])"
  testthat::expect_false(grepl(pattern, dep$stylesheet, perl = TRUE))
  testthat::expect_false(grepl(
    pattern, file.path(sprintf("%s-%s", dep$name, dep$version), dep$stylesheet),
    perl = TRUE
  ))
  # No switch for tests is left in what ships.
  js <- paste(readLines(file.path(dir, dep$script)), collapse = "\n")
  testthat::expect_false(grepl("NoShims", js, fixed = TRUE))
})

test_that("save_html() and the widgets keep their bundle as it was", {
  for (use_cdn in c(FALSE, TRUE)) {
    deps <- maidr:::maidr_html_dependencies(use_cdn = use_cdn)
    bundle <- deps[[length(deps)]]
    testthat::expect_identical(bundle$script, "maidr.js")
    testthat::expect_null(bundle$attachment)
  }
})

# ==============================================================================
# Where a chart goes
# ==============================================================================

test_that("charts are inline only in HTML that pandoc writes as a page", {
  ok_for <- function(to, args = NULL, knitting = TRUE) {
    knitr::opts_knit$set(rmarkdown.pandoc.to = to, rmarkdown.pandoc.args = args)
    withr::local_options(knitr.in.progress = if (knitting) TRUE)
    maidr:::inline_output_ok()
  }
  withr::defer(knitr::opts_knit$delete(c("rmarkdown.pandoc.to", "rmarkdown.pandoc.args")))
  rmd <- function(...) file.path("/library/rmarkdown/rmd", ...)

  for (to in c("html", "html4", "html5", "revealjs", "slidy", "s5", "slideous")) {
    testthat::expect_true(ok_for(to), info = to)
  }
  testthat::expect_true(ok_for("html", c("--template", rmd("h", "default.html"))))
  others <- c("markdown", "markdown_strict", "gfm", "commonmark", "epub", "epub3", "latex", "docx")
  for (to in others) {
    testthat::expect_false(ok_for(to), info = to)
  }
  testthat::expect_false(ok_for(NULL))
  testthat::expect_false(ok_for("html", knitting = FALSE))
  # A fragment has no <head> for maidr.js; remark.js shows a raw HTML block
  # as code; paged.js rebuilds the page before a chart could be bound.
  testthat::expect_false(ok_for("html", c("--template", rmd("fragment", "default.html"))))
  testthat::expect_false(ok_for("html", "--template=/lib/xaringan/rmarkdown/templates/x.html"))
  testthat::expect_false(ok_for("html", c("--template", "C:\\lib\\pagedown\\paged.html")))
})

test_that("an HTML document knitted without pandoc keeps its charts in iframes", {
  testthat::skip_on_cran()
  skip_if_no_render()
  local_knitr_state()
  dir <- withr::local_tempdir("maidr-knit-")
  testthat::local_mocked_bindings(maidr_internet_available = function() FALSE, .package = "maidr")

  # knitr::knit() of an .Rmd, with no pandoc format named: Markdown.
  hooks <- knitr::knit_hooks$get()
  knitr::knit_hooks$restore()
  on.exit(knitr::knit_hooks$restore(hooks), add = TRUE)
  page <- paste(knitr::knit(
    text = c(
      "```{r}", "ggplot2::ggplot(mtcars, ggplot2::aes(factor(cyl))) + ggplot2::geom_bar()", "```"
    ),
    quiet = TRUE, envir = new.env()
  ), collapse = "\n")
  testthat::expect_match(page, "<iframe", fixed = TRUE)
  testthat::expect_false(grepl("data-maidr-knitr", page, fixed = TRUE))
})

# ==============================================================================
# The knit's hooks
# ==============================================================================

test_that("knitr's cache keeps a chunk's meta under the name maidr appends to", {
  # maidr_knitr_chunk_hook() adds the page dependencies to it, so a cached
  # chunk brings maidr.js back.
  testthat::expect_identical(knitr:::cache_meta_name("abc"), ".abc_meta")
})

test_that("maidr installs into a knit over the hooks it finds, and maidr_off() puts them back", {
  local_knitr_state()
  dir <- withr::local_tempdir("maidr-knit-")
  dev_hook <- function(options) options
  attr(dev_hook, "test") <- "the document's"
  knitr::opts_hooks$set(dev = dev_hook)

  page <- knit_for(c(
    "```{r, results = 'asis'}",
    "mine <- function(x, options) 'mine'",
    "knitr::knit_hooks$set(plot = mine)",
    "maidr:::ensure_knitr_integration()",
    "plot <- knitr::knit_hooks$get('plot')",
    "dev <- knitr::opts_hooks$get('dev')",
    "cat('WRAPPED', maidr:::is_maidr_knitr_hook(plot), identical(attr(plot, 'previous'), mine),",
    "  identical(attr(attr(dev, 'previous'), 'test'), \"the document's\"),",
    "  maidr:::is_maidr_knitr_hook(knitr::knit_hooks$get('chunk')), '\\n')",
    "maidr:::ensure_knitr_integration()",
    "cat('ONCE', identical(knitr::knit_hooks$get('plot'), plot), '\\n')",
    "maidr::maidr_off()",
    "cat('OFF', identical(knitr::knit_hooks$get('plot'), mine),",
    "  identical(attr(knitr::opts_hooks$get('dev'), 'test'), \"the document's\"),",
    "  maidr:::is_maidr_knitr_hook(knitr::knit_hooks$get('chunk')),",
    "  is.null(knitr::opts_knit$get('maidr.integrated')), '\\n')",
    "maidr::maidr_on()",
    "cat('ON', maidr:::is_maidr_knitr_hook(knitr::knit_hooks$get('plot')), '\\n')",
    "```"
  ), dir)

  testthat::expect_match(page, "WRAPPED TRUE TRUE TRUE TRUE", fixed = TRUE)
  testthat::expect_match(page, "ONCE TRUE", fixed = TRUE)
  testthat::expect_match(page, "OFF TRUE TRUE FALSE TRUE", fixed = TRUE)
  testthat::expect_match(page, "ON TRUE", fixed = TRUE)
})

test_that("the dev hook a plain knit() leaves behind does nothing in a later knit", {
  local_knitr_state()
  dir <- withr::local_tempdir("maidr-knit-")
  knit_for(c("```{r}", "1", "```"), dir)
  # knit() puts back opts_knit, but not the option hooks.
  testthat::expect_true(maidr:::is_maidr_knitr_hook(knitr::opts_hooks$get("dev")))
  testthat::expect_null(knitr::opts_knit$get("maidr.integrated"))

  # A later knit of HTML that maidr is never installed into keeps its png.
  hooks <- knitr::knit_hooks$get()
  knitr::knit_hooks$restore()
  withr::defer(knitr::knit_hooks$restore(hooks))
  knitr::opts_knit$set(rmarkdown.pandoc.to = "html")
  withr::defer(knitr::opts_knit$delete("rmarkdown.pandoc.to"))
  withr::local_dir(dir)
  knitr::knit(
    text = c("```{r grid, fig.path = 'later/'}", "grid::grid.newpage(); grid::grid.rect()", "```"),
    quiet = TRUE, envir = new.env()
  )
  testthat::expect_identical(tools::file_ext(list.files(file.path(dir, "later"))), "png")
})

# ==============================================================================
# The device of a chunk's figures
# ==============================================================================

test_that("knitr's default png becomes svglite in HTML, and every other choice is kept", {
  testthat::skip_on_cran()
  local_knitr_state()
  dir <- withr::local_tempdir("maidr-knit-")
  knitr::opts_template$set(maidr_png = list(dev = "png"))
  withr::defer(knitr::opts_template$delete("maidr_png"))
  engines <- knitr::knit_engines$get()
  withr::defer(knitr::knit_engines$restore(engines))
  # An engine that, like Python's, writes its figures in the format dev names.
  knitr::knit_engines$set(maidrdev = function(options) paste0("DEV=", options$dev))
  draw <- "grid::grid.newpage(); grid::grid.rect()"

  page <- knit_for(c(
    "```{r default}", draw, "```",
    "```{r header, dev = 'png'}", draw, "```",
    "```{r pipe}", "#| dev: png", draw, "```",
    "```{r template, opts.label = 'maidr_png'}", draw, "```",
    "```{r cached, cache = TRUE}", draw, "```",
    "```{r cairo, dev.args = list(type = 'cairo')}", draw, "```",
    "```{r ext, fig.ext = 'png'}", draw, "```",
    "```{maidrdev engine}", "x", "```",
    "```{r}", "knitr::opts_chunk$set(dev = 'jpeg')", "```",
    "```{r document}", draw, "```"
  ), dir)

  testthat::expect_identical(
    figure_types(dir)[
      c("default", "header", "pipe", "template", "cached", "cairo", "ext", "document")
    ],
    c(
      default = "svg", header = "png", pipe = "png", template = "png",
      cached = "png", cairo = "png", ext = "png", document = "jpeg"
    )
  )
  testthat::expect_match(page, "DEV=png", fixed = TRUE)
})

test_that("options(maidr.knitr_dev = FALSE), other formats and maidr_off() keep png", {
  testthat::skip_on_cran()
  local_knitr_state()
  draw <- "grid::grid.newpage(); grid::grid.rect()"

  opted_out <- withr::local_tempdir("maidr-knit-")
  withr::with_options(
    list(maidr.knitr_dev = FALSE),
    knit_for(c("```{r chart}", draw, "```"), opted_out)
  )
  testthat::expect_identical(unname(figure_types(opted_out)), "png")

  for (to in c("latex", "docx", "gfm")) {
    other <- withr::local_tempdir("maidr-knit-")
    knit_for(c("```{r chart}", draw, "```"), other, to = to)
    testthat::expect_identical(unname(figure_types(other)), "png", info = to)
  }

  off <- withr::local_tempdir("maidr-knit-")
  knit_for(c(
    "```{r before}", draw, "```",
    "```{r}", "maidr::maidr_off()", "```",
    "```{r after}", draw, "```",
    "```{r}", "maidr::maidr_on()", "```",
    "```{r again}", draw, "```"
  ), off)
  testthat::expect_identical(
    figure_types(off)[c("before", "after", "again")],
    c(before = "svg", after = "png", again = "svg")
  )
})

# ==============================================================================
# Documents
# ==============================================================================

test_that("a PDF document's charts are what they are without maidr", {
  testthat::skip_on_cran()
  skip_if_no_render()
  testthat::skip_if_not_installed("lattice")
  local_knitr_state()
  chunks <- c(
    "```{r gg}",
    "ggplot2::ggplot(mtcars, ggplot2::aes(factor(cyl))) + ggplot2::geom_bar()",
    "```",
    "```{r lattice}",
    "lattice::xyplot(mpg ~ wt, data = mtcars)",
    "```",
    "```{r base}",
    "barplot(c(a = 1, b = 2))",
    "```"
  )
  with_maidr <- withr::local_tempdir("maidr-knit-")
  page <- knit_for(chunks, with_maidr, to = "latex")
  without <- withr::local_tempdir("maidr-knit-")
  maidr::maidr_off()
  plain <- knit_for(chunks, without, to = "latex")

  testthat::expect_false(grepl("data-maidr-knitr|<iframe|\\{=html\\}", page))
  testthat::expect_identical(
    gsub(with_maidr, "DIR", page, fixed = TRUE),
    gsub(without, "DIR", plain, fixed = TRUE)
  )
  files <- list.files(file.path(with_maidr, "figure"))
  testthat::expect_identical(files, list.files(file.path(without, "figure")))
  testthat::expect_identical(
    unname(tools::md5sum(file.path(with_maidr, "figure", files))),
    unname(tools::md5sum(file.path(without, "figure", files)))
  )
})
