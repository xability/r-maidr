# Charts shown inline in knitted HTML: R/knitr_inline.R, R/knitr_lifecycle.R
# and the page dependencies in R/html_dependencies.R.
#
# A document needs only library(maidr): the first maidr chart, figure or
# Base R call of a knit installs maidr's hooks into it, and each chart is the
# page's own <svg>, with ids no other chart on the page has, bound by
# knitr-inline.js to the one maidr.js the page loads.

# ==============================================================================
# Helpers
# ==============================================================================

#' The figure files a knit wrote, by chunk label, as file extensions
figure_types <- function(dir) {
  files <- list.files(file.path(dir, "figure"))
  stats::setNames(tools::file_ext(files), sub("-[0-9]+\\.[a-z]+$", "", files))
}

#' The strings under every `selectors` or `selector` key of parsed maidr-data
selector_strings <- function(x) {
  if (!is.list(x)) {
    return(character())
  }
  keys <- if (is.null(names(x))) character(length(x)) else names(x)
  keyed <- keys %in% c("selectors", "selector")
  c(
    unlist(x[keyed], use.names = FALSE),
    unlist(lapply(x[!keyed], selector_strings), use.names = FALSE)
  )
}

#' Expect every id a chart's selectors name to be an id of its own svg
#'
#' `#id` tokens, `[id='..']` and `[id^='..']`, unescaped as CSS escapes them;
#' and every id of the svg, and of its JSON figure, to start with one prefix
#' that no other chart of the page has.
expect_own_selectors <- function(svg) {
  ids <- xml2::xml_attr(xml2::xml_find_all(svg, "//*[@id]"), "id")
  testthat::expect_gt(length(ids), 0L)
  prefix <- unique(sub("^(m[a-z0-9]+-).*$", "\\1", ids))
  testthat::expect_length(prefix, 1L)
  testthat::expect_true(all(startsWith(ids, prefix)))

  data <- jsonlite::parse_json(xml2::xml_attr(svg, "data-maidr-knitr"))
  testthat::expect_true(startsWith(data$id, prefix))
  selectors <- selector_strings(data)
  testthat::expect_gt(length(selectors), 0L)
  unescape <- function(x) gsub("\\\\(.)", "\\1", x)
  named <- unescape(unlist(regmatches(
    selectors, gregexpr("(?<=#)(?:[A-Za-z0-9_-]|\\\\.)+", selectors, perl = TRUE)
  )))
  exact <- unescape(unlist(regmatches(
    selectors, gregexpr("(?<=\\[id=['\"])[^'\"]*", selectors, perl = TRUE)
  )))
  starts <- unescape(unlist(regmatches(
    selectors, gregexpr("(?<=\\[id\\^=['\"])[^'\"]*", selectors, perl = TRUE)
  )))
  testthat::expect_true(all(c(named, exact) %in% ids))
  testthat::expect_true(all(vapply(starts, function(s) any(startsWith(ids, s)), logical(1))))
  testthat::expect_true(all(startsWith(c(named, exact, starts), prefix)))
  invisible(prefix)
}

#' A small maidr chart's SVG, as create_maidr_html() returns it for knitr
bar_chart_svg <- function(title = NULL) {
  plot <- create_test_ggplot_bar() + ggplot2::labs(title = title)
  suppressWarnings(maidr:::create_maidr_html(plot, shiny = TRUE))
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
    knitr::opts_knit$set(
      rmarkdown.pandoc.to = to, rmarkdown.pandoc.args = args, out.format = "markdown"
    )
    withr::local_options(knitr.in.progress = if (knitting) TRUE)
    maidr:::inline_output_ok()
  }
  withr::defer(knitr::opts_knit$delete(
    c("rmarkdown.pandoc.to", "rmarkdown.pandoc.args", "out.format")
  ))
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
  hooks <- knitr::knit_hooks$get()
  knitr::knit_hooks$restore()
  on.exit(knitr::knit_hooks$restore(hooks), add = TRUE)
  withr::local_dir(dir)

  writeLines(c(
    "<html><body>",
    "<!--begin.rcode chart",
    "ggplot2::ggplot(mtcars, ggplot2::aes(factor(cyl))) + ggplot2::geom_bar()",
    "end.rcode-->",
    "</body></html>"
  ), "chart.Rhtml")
  out <- knitr::knit("chart.Rhtml", quiet = TRUE, envir = new.env())
  page <- paste(readLines(out), collapse = "\n")
  testthat::expect_match(page, "<iframe", fixed = TRUE)
  testthat::expect_false(grepl("data-maidr-knitr", page, fixed = TRUE))
})

test_that("Markdown, EPUB and xaringan output draw their charts as knitr's figures", {
  testthat::skip_on_cran()
  skip_if_no_render()
  local_knitr_state()
  dir <- withr::local_tempdir("maidr-knit-")
  testthat::local_mocked_bindings(maidr_internet_available = function() TRUE, .package = "maidr")
  chunks <- c(
    "```{r gg}",
    "ggplot2::ggplot(mtcars, ggplot2::aes(factor(cyl))) + ggplot2::geom_bar()",
    "```",
    "```{r base}",
    "barplot(c(a = 1, b = 2))",
    "```"
  )
  knitr::knit_meta(clean = TRUE)

  # GitHub drops an iframe, and rmarkdown refuses to render a Markdown
  # document that declares the page bundle an online frame brings; so does
  # the EPUB writer, unless the document allows HTML.
  for (to in c("gfm", "markdown_strict", "epub3")) {
    page <- knit_for(chunks, dir, to = to)
    testthat::expect_false(grepl("<iframe|data-maidr-knitr", page), info = to)
    testthat::expect_identical(
      lengths(regmatches(page, gregexpr("!\\[\\]\\(", page))), 2L,
      info = to
    )
    testthat::expect_length(knitr::knit_meta(clean = TRUE), 0L)
  }

  # xaringan's remark.js shows a raw HTML block as text on the slide.
  xaringan <- c(
    "```{r, include = FALSE}",
    "knitr::opts_knit$set(rmarkdown.pandoc.args = c(",
    "  '--template', '/lib/xaringan/rmarkdown/templates/xaringan/resources/default.html'",
    "))",
    "```",
    chunks
  )
  page <- knit_for(xaringan, dir)
  testthat::expect_false(grepl("<iframe|data-maidr-knitr", page))
  testthat::expect_identical(lengths(regmatches(page, gregexpr("!\\[\\]\\(", page))), 2L)
  testthat::expect_length(knitr::knit_meta(clean = TRUE), 0L)
})

test_that("an EPUB book and a xaringan deck render with maidr loaded", {
  testthat::skip_on_cran()
  skip_if_no_render()
  testthat::skip_if_not_installed("rmarkdown")
  testthat::skip_if_not_installed("bookdown")
  testthat::skip_if_not_installed("xaringan")
  testthat::skip_if_not(rmarkdown::pandoc_available("2.0"), "pandoc is not available")
  local_knitr_state()
  dir <- withr::local_tempdir("maidr-epub-")
  body <- c(
    "```{r, include = FALSE}", "library(maidr)", "maidr_on()", "```",
    "```{r gg}", "ggplot2::ggplot(mtcars, ggplot2::aes(factor(cyl))) + ggplot2::geom_bar()", "```",
    "```{r base}", "barplot(c(a = 1, b = 2))", "```"
  )
  writeLines(
    c("---", "title: book", "output: bookdown::epub_book", "---", body),
    file.path(dir, "book.Rmd")
  )
  writeLines(
    c("---", "title: deck", "output: xaringan::moon_reader", "---", body),
    file.path(dir, "deck.Rmd")
  )

  epub <- rmarkdown::render(file.path(dir, "book.Rmd"), quiet = TRUE, envir = new.env())
  testthat::expect_true(file.exists(epub))
  deck <- rmarkdown::render(file.path(dir, "deck.Rmd"), quiet = TRUE, envir = new.env())
  html <- paste(readLines(deck, warn = FALSE), collapse = "\n")
  testthat::expect_false(grepl("<iframe|data-maidr-knitr", html))
  testthat::expect_identical(lengths(regmatches(html, gregexpr("!\\[\\]\\(", html))), 2L)
})

test_that("a patchwork maidr does not make a chart is drawn as patchwork draws it", {
  testthat::skip_on_cran()
  skip_if_no_render()
  testthat::skip_if_not_installed("patchwork")
  local_knitr_state()
  dir <- withr::local_tempdir("maidr-knit-")
  # The same plots printed, which print() hands to patchwork's own method,
  # never maidr's.
  setup <- c(
    "```{r plots}",
    "library(patchwork)",
    "one <- ggplot2::ggplot(mtcars, ggplot2::aes(factor(cyl))) + ggplot2::geom_bar()",
    "two <- ggplot2::ggplot(mtcars, ggplot2::aes(factor(gear))) + ggplot2::geom_bar()",
    "```"
  )
  returned <- c("```{r returned}", "one + two", "```")
  control <- c("```{r control}", "print(one + two)", "```")
  same_figures <- function(page) {
    figures <- file.path(dir, regmatches(page, gregexpr("figure/[^)]+[.]png", page))[[1]])
    testthat::expect_identical(basename(figures), c("returned-1.png", "control-1.png"))
    unname(tools::md5sum(figures[[1]])) == unname(tools::md5sum(figures[[2]]))
  }

  # Markdown output, and an HTML page after maidr_off().
  testthat::expect_true(same_figures(knit_for(c(setup, returned, control), dir, to = "gfm")))
  off <- c("```{r off}", "maidr::maidr_off()", "```")
  testthat::expect_true(same_figures(knit_for(c(setup, off, returned, control), dir)))
})

# ==============================================================================
# The emitter
# ==============================================================================

test_that("an inline chart is a named svg in a raw block, its data set aside", {
  skip_if_no_render()
  out <- maidr:::knitr_inline_chart(bar_chart_svg("Three bars"), list(label = "bars"))

  # A raw HTML block of its own, between blank lines.
  testthat::expect_match(out, "^\n\n\n```+ \\{=html\\}\n<div class=\"maidr-knitr\">\n<svg ")
  testthat::expect_match(out, "</div>\n```+\n\n$")
  page <- xml2::read_html(out)
  wrapper <- xml2::xml_find_first(page, "//div[@class = 'maidr-knitr']")
  svg <- xml2::read_xml(as.character(xml2::xml_find_first(wrapper, "./svg")))
  testthat::expect_identical(xml2::xml_attr(svg, "role"), "img")
  testthat::expect_identical(unname(chart_names(out)), "Three bars")
  testthat::expect_identical(xml2::xml_attr(svg, "class"), "maidr-knitr-svg")
  testthat::expect_true(is.na(xml2::xml_attr(svg, "maidr-data")))
  testthat::expect_false(grepl("maidr-data=", out, fixed = TRUE))
  testthat::expect_false(grepl("<?xml", out, fixed = TRUE))
  expect_own_selectors(svg)
  # The title is the name, and stays the description once maidr names the
  # chart itself.
  alt <- xml2::xml_find_first(wrapper, "./span[@class = 'maidr-knitr-alt']")
  testthat::expect_identical(xml2::xml_text(alt), "Three bars")
  testthat::expect_identical(xml2::xml_attr(alt, "hidden"), "")
  testthat::expect_match(xml2::xml_attr(alt, "id"), "^m[a-z0-9]+-alt$")
  testthat::expect_identical(xml2::xml_attr(svg, "aria-labelledby"), xml2::xml_attr(alt, "id"))
})

test_that("a chart is named by fig.alt, then fig.cap, then its title, then its kind", {
  skip_if_no_render()
  name_of <- function(out) unname(chart_names(out))
  titled <- bar_chart_svg("Title")

  both <- maidr:::knitr_inline_chart(titled, list(fig.alt = "Alt", fig.cap = "Cap"))
  testthat::expect_identical(name_of(both), "Alt")
  testthat::expect_match(
    both, '<span class="maidr-knitr-alt" id="m[a-z0-9]+-alt" hidden>Alt</span>'
  )
  testthat::expect_match(
    both, '<p class="caption maidr-knitr-caption" id="m[a-z0-9]+-caption">Cap</p>'
  )
  testthat::expect_match(both, '<div class="figure maidr-knitr">', fixed = TRUE)

  captioned <- maidr:::knitr_inline_chart(titled, list(fig.cap = "Cap"))
  testthat::expect_identical(name_of(captioned), "Cap")
  # The caption is already the description.
  testthat::expect_false(grepl("maidr-knitr-alt", captioned, fixed = TRUE))

  untitled <- maidr:::knitr_inline_chart(bar_chart_svg(), list())
  testthat::expect_identical(name_of(untitled), "Bar chart of y by x")
  testthat::expect_identical(maidr:::knitr_chart_kind("{}"), "Chart")
  testthat::expect_identical(
    maidr:::knitr_chart_kind('{"subplots":[[{"layers":[{"type":"stacked_bar"}]}]]}'),
    "Stacked bar chart"
  )
  testthat::expect_false(grepl("maidr-knitr-alt", untitled, fixed = TRUE))
  testthat::expect_false(grepl("maidr-knitr-caption", untitled, fixed = TRUE))
})

test_that("a caption is picked for its figure and escaped", {
  skip_if_no_render()
  svg <- bar_chart_svg()

  # The chunk's second figure takes the second caption.
  second <- maidr:::knitr_inline_chart(svg, list(fig.cap = c("First", "Second")), index = 2L)
  testthat::expect_identical(unname(chart_names(second)), "Second")

  escaped <- maidr:::knitr_inline_chart(svg, list(fig.cap = "if a<b & c then &copy; done"))
  testthat::expect_match(escaped, ">if a&lt;b &amp; c then &amp;copy; done</p>", fixed = TRUE)
  testthat::expect_identical(unname(chart_names(escaped)), "if a<b & c then &copy; done")
})

test_that("a chart's name is never written into an attribute bookdown rewrites", {
  skip_if_no_render()
  svg <- bar_chart_svg()
  # bookdown replaces a text reference with its HTML across the whole page,
  # attributes included: the svg names the elements that hold the text.
  for (options in list(list(fig.cap = "(ref:cap)"), list(fig.alt = "(ref:alt)"))) {
    out <- maidr:::knitr_inline_chart(svg, options)
    start <- regmatches(out, regexpr("<svg[^>]*>", out))
    testthat::expect_false(grepl("(ref:", start, fixed = TRUE))
    testthat::expect_match(start, 'aria-labelledby="m[a-z0-9]+-(alt|caption)"')
  }
})

test_that("bookdown labels a captioned chart, and Quarto writes the caption itself", {
  skip_if_no_render()
  svg <- bar_chart_svg()
  withr::defer(knitr::opts_knit$delete(c("bookdown.internal.label", "quarto.version")))

  knitr::opts_knit$set(bookdown.internal.label = TRUE)
  one <- maidr:::knitr_inline_chart(svg, list(label = "bars", fig.cap = "Bars", fig.lp = "fig:"))
  testthat::expect_match(one, '<div class="figure maidr-knitr">', fixed = TRUE)
  testthat::expect_match(one, '-caption">(#fig:bars) Bars</p>', fixed = TRUE)
  options <- list(
    label = "bars", fig.cap = "B", fig.lp = "fig:", fig.show = "asis", fig.num = 2L, fig.cur = 2L
  )
  two <- maidr:::knitr_inline_chart(svg, options, index = 2L, figure = TRUE)
  testthat::expect_match(two, '-caption">(#fig:bars-2) B</p>', fixed = TRUE)
  # A chart written for no chunk, as inline code's is, has no label.
  unlabelled <- maidr:::knitr_inline_chart(svg, list(fig.cap = "Bars"))
  testthat::expect_match(unlabelled, '-caption">Bars</p>', fixed = TRUE)
  knitr::opts_knit$delete("bookdown.internal.label")

  knitr::opts_knit$set(quarto.version = "1.7.32")
  # A figure the plot hook replaces is not captioned by Quarto, unless it is
  # given to Quarto as the figure of a fig- chunk, which it captions with
  # the figure's sub-caption, if any, and numbers.
  figure <- maidr:::knitr_inline_chart(
    svg, list(label = "unnamed-chunk-2", fig.cap = "Bars"),
    figure = TRUE
  )
  testthat::expect_match(
    figure, '<p class="caption maidr-knitr-caption" id="m[a-z0-9]+-caption">Bars</p>'
  )
  options <- list(label = "fig-bars", fig.cap = "Bars", fig.num = 1L, fig.cur = 1L)
  figure <- maidr:::knitr_inline_chart(svg, options, figure = TRUE)
  testthat::expect_false(grepl("maidr-knitr-caption", figure, fixed = TRUE))
  testthat::expect_match(
    figure, "^\\s*::: \\{\\.cell-output-display\\}\\s*::: \\{#fig-bars\\}\\s*``` ?\\{=html\\}"
  )
  testthat::expect_match(figure, "```\\s*Bars\\s*:::\\s*:::\\s*$")
  options <- utils::modifyList(options, list(fig.num = 2L, fig.cur = 2L, fig.subcap = "Right"))
  figure <- maidr:::knitr_inline_chart(svg, options, index = 2L, figure = TRUE)
  testthat::expect_match(figure, "::: {#fig-bars-2}", fixed = TRUE)
  testthat::expect_match(figure, 'aria-label="Right"', fixed = TRUE)
  testthat::expect_match(figure, "```\\s*Right\\s*:::")
})

test_that("fig.align and the author's out.width lay the chart out", {
  skip_if_no_render()
  svg <- bar_chart_svg()
  testthat::local_mocked_bindings(
    chunk_sets_option = function(options, name) TRUE,
    .package = "maidr"
  )
  centred <- maidr:::knitr_inline_chart(svg, list(fig.align = "center", out.width = "50%"))
  testthat::expect_match(
    centred, '<div class="maidr-knitr maidr-knitr-center" style="width: 50%;">',
    fixed = TRUE
  )
  testthat::expect_match(
    maidr:::knitr_inline_chart(svg, list(fig.align = "default", out.width = 300)),
    '<div class="maidr-knitr" style="width: 300px;">', fixed = TRUE
  )
  testthat::expect_match(
    maidr:::knitr_inline_chart(svg, list(out.width = "\\linewidth")),
    '<div class="maidr-knitr">', fixed = TRUE
  )

  # Figures held to the end of the chunk at such a width sit in a row, which
  # the last of them ends, as knitr's images do.
  held <- list(fig.show = "hold", fig.align = "default", out.width = "50%", fig.num = 2L)
  first <- maidr:::knitr_inline_chart(svg, c(held, fig.cur = 1L), figure = TRUE)
  last <- maidr:::knitr_inline_chart(svg, c(held, fig.cur = 2L), index = 2L, figure = TRUE)
  row <- '<div class="maidr-knitr maidr-knitr-row" style="width: 50%;">'
  testthat::expect_match(first, row, fixed = TRUE)
  testthat::expect_false(grepl("maidr-knitr-row-end", first, fixed = TRUE))
  testthat::expect_match(last, row, fixed = TRUE)
  testthat::expect_match(last, '</div>\n<div class="maidr-knitr-row-end"></div>\n```')
  # Captioned once, below the last; the caption of the one before it
  # describes that chart.
  captioned <- c(held, fig.cap = list(c("Left", "Right")))
  first <- maidr:::knitr_inline_chart(svg, c(captioned, fig.cur = 1L), figure = TRUE)
  testthat::expect_false(grepl('class="caption', first, fixed = TRUE))
  testthat::expect_match(
    first, '<span class="maidr-knitr-alt" id="m[a-z0-9]+-alt" hidden>Left</span>'
  )
  last <- maidr:::knitr_inline_chart(svg, c(captioned, fig.cur = 2L), index = 2L, figure = TRUE)
  testthat::expect_match(last, '-caption">Right</p>', fixed = TRUE)
  # Not when aligned, as knitr's images are blocks then, nor at full width.
  for (change in list(list(fig.align = "center"), list(out.width = NULL))) {
    options <- utils::modifyList(c(held, fig.cur = 1L), change)
    out <- maidr:::knitr_inline_chart(svg, options, figure = TRUE)
    testthat::expect_false(grepl("maidr-knitr-row", out, fixed = TRUE))
  }
})

test_that("an out.width the chunk sets, in either spelling, is its chart's width", {
  skip_if_no_render()
  local_knitr_state()
  dir <- withr::local_tempdir("maidr-knit-")
  page <- knit_for(c(
    "```{r dashed}", "#| out-width: 50%", "barplot(c(a = 1))", "```",
    "```{r dotted}", "#| out.width: 40%", "barplot(c(a = 1))", "```",
    "```{r header, out.width = '30%'}", "barplot(c(a = 1))", "```",
    "```{r none}", "barplot(c(a = 1))", "```"
  ), dir)
  testthat::expect_identical(
    regmatches(page, gregexpr('<div class="maidr-knitr"[^>]*>', page))[[1]],
    c(
      '<div class="maidr-knitr" style="width: 50%;">',
      '<div class="maidr-knitr" style="width: 40%;">',
      '<div class="maidr-knitr" style="width: 30%;">',
      '<div class="maidr-knitr">'
    )
  )
})

test_that("a chart that cannot be shown inline goes in an iframe, with one warning", {
  skip_if_no_render()
  local_knitr_state()
  testthat::local_mocked_bindings(
    inline_output_ok = function() TRUE,
    maidr_internet_available = function() FALSE,
    .package = "maidr"
  )
  withr::defer(knitr::opts_knit$delete("maidr.inline_warned"))
  # A <style> in an inline svg would style the whole page: refused.
  svg <- sub("</svg>$", "<style>rect{fill:red}</style></svg>", as.character(bar_chart_svg()))

  testthat::expect_warning(
    first <- maidr:::knitr_chart_output(svg, list(label = "a")),
    "could not be shown inline"
  )
  testthat::expect_match(first, "<iframe", fixed = TRUE)
  testthat::expect_no_warning(second <- maidr:::knitr_chart_output(svg, list(label = "b")))
  testthat::expect_match(second, "<iframe", fixed = TRUE)
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
    "cat('UNMARKED', maidr:::knit_figures_active(), '\\n')",
    "maidr:::ensure_knitr_integration()",
    "plot <- knitr::knit_hooks$get('plot')",
    "dev <- knitr::opts_hooks$get('dev')",
    "cat('WRAPPED', maidr:::is_maidr_knitr_hook(plot), identical(attr(plot, 'previous'), mine),",
    "  identical(attr(attr(dev, 'previous'), 'test'), \"the document's\"),",
    "  maidr:::is_maidr_knitr_hook(knitr::knit_hooks$get('chunk')), '\\n')",
    "set <- function(hook, f) any(vapply(getHook(hook), identical, NA, f))",
    "pages <- function() c(",
    "  set('before.plot.new', maidr:::knit_before_plot_new),",
    "  set('before.grid.newpage', maidr:::knit_before_grid_newpage),",
    "  is.function(getOption('maidr.knit.replayed')))",
    "evaluate <- function() maidr:::is_maidr_knitr_hook(knitr::knit_hooks$get('evaluate'))",
    "cat('MARKERS', evaluate(), pages(), '\\n')",
    "maidr:::ensure_knitr_integration()",
    "cat('ONCE', identical(knitr::knit_hooks$get('plot'), plot), '\\n')",
    "maidr::maidr_off()",
    "cat('OFF', identical(knitr::knit_hooks$get('plot'), mine),",
    "  identical(attr(knitr::opts_hooks$get('dev'), 'test'), \"the document's\"),",
    "  maidr:::is_maidr_knitr_hook(knitr::knit_hooks$get('chunk')),",
    "  is.null(knitr::opts_knit$get('maidr.integrated')),",
    "  evaluate(), pages(), '\\n')",
    "maidr::maidr_on()",
    "cat('ON', maidr:::is_maidr_knitr_hook(knitr::knit_hooks$get('plot')), '\\n')",
    "```"
  ), dir)

  # A chart drawn while a plot hook of the document's is knitr's leaves no
  # marker that nothing would read.
  testthat::expect_match(page, "UNMARKED FALSE", fixed = TRUE)
  testthat::expect_match(page, "WRAPPED TRUE TRUE TRUE TRUE", fixed = TRUE)
  testthat::expect_match(page, "MARKERS TRUE TRUE TRUE TRUE", fixed = TRUE)
  testthat::expect_match(page, "ONCE TRUE", fixed = TRUE)
  testthat::expect_match(page, "OFF TRUE TRUE FALSE TRUE FALSE FALSE FALSE FALSE", fixed = TRUE)
  testthat::expect_match(page, "ON TRUE", fixed = TRUE)
})

test_that("a knit takes its hooks out, and one left by a failed knit does nothing later", {
  local_knitr_state()
  dir <- withr::local_tempdir("maidr-knit-")
  knitr::opts_hooks$delete("dev")
  knit_for(c("```{r}", "1", "```"), dir)
  # knit() puts back opts_knit, but not the option hooks: maidr's document
  # hook does.
  testthat::expect_null(knitr::opts_hooks$get("dev"))
  testthat::expect_null(knitr::opts_knit$get("maidr.integrated"))
  testthat::expect_false(maidr:::is_maidr_knitr_hook(knitr::knit_hooks$get("document")))

  # A knit that stops with an error leaves its dev hook behind. A later knit
  # of HTML that maidr is never installed into keeps its png all the same.
  knitr::opts_hooks$set(dev = maidr:::maidr_knitr_dev_hook(NULL))
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
    "```{r animate, fig.show = 'animate', animation.hook = function(x, options) ''}",
    "for (i in 1:2) barplot(c(a = i, b = 2))", "```",
    "```{r process, fig.process = function(x) x}", draw, "```",
    "```{maidrdev engine}", "x", "```",
    "```{r}", "knitr::opts_chunk$set(dev = 'jpeg')", "```",
    "```{r document}", draw, "```"
  ), dir)

  testthat::expect_identical(
    figure_types(dir)[
      c(
        "default", "header", "pipe", "template", "cached", "cairo", "ext", "animate",
        "process", "document"
      )
    ],
    c(
      default = "svg", header = "png", pipe = "png", template = "png",
      cached = "png", cairo = "png", ext = "png", animate = "png", process = "png",
      document = "jpeg"
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

test_that("an animation knitr makes with gifski keeps its png frames", {
  testthat::skip_on_cran()
  skip_if_no_render()
  testthat::skip_if_not_installed("rmarkdown")
  testthat::skip_if_not_installed("gifski")
  testthat::skip_if_not(rmarkdown::pandoc_available("2.0"), "pandoc is not available")
  local_knitr_state()
  dir <- withr::local_tempdir("maidr-anim-")
  rmd <- file.path(dir, "anim.Rmd")
  writeLines(c(
    "---", "title: anim", "output:", "  html_document:", "    self_contained: false", "---",
    # maidr is loaded already: maidr_on() installs it into the knit, as
    # library(maidr) does in a session of its own, before the next chunk.
    "```{r}", "library(maidr)", "maidr_on()", "```",
    "```{r anim, fig.show = 'animate', animation.hook = 'gifski'}",
    "for (i in 1:3) barplot(c(a = i, b = 4 - i))",
    "```"
  ), rmd)

  out <- rmarkdown::render(rmd, quiet = TRUE, envir = new.env())
  html <- paste(readLines(out, warn = FALSE), collapse = "\n")
  testthat::expect_match(html, '<img src="anim_files/figure-html/anim-[^"]*[.]gif"')
  testthat::expect_false(grepl("data-maidr-knitr=", html, fixed = TRUE))
})

test_that("flexdashboard's phone copy of a default png figure gives way to svglite", {
  testthat::skip_on_cran()
  local_knitr_state()
  dir <- withr::local_tempdir("maidr-knit-")
  # flexdashboard's dev hook, as of 0.6: a png figure is drawn twice, the
  # second time at its phone size, to an .mb.png file.
  knitr::opts_hooks$set(dev = function(options) {
    if (identical(options$dev, "png")) {
      options$dev <- c("png", "png")
      options$fig.ext <- c("png", "mb.png")
      options$fig.width <- c(options$fig.width, 3.75)
      options$fig.height <- c(options$fig.height, 4.8)
    }
    options
  })
  draw <- "grid::grid.newpage(); grid::grid.rect()"

  knit_for(c(
    "```{r default}", draw, "```",
    "```{r header, dev = 'png'}", draw, "```",
    "```{r cached, cache = TRUE}", draw, "```"
  ), dir)

  testthat::expect_setequal(
    list.files(file.path(dir, "figure")),
    c("default-1.svg", "header-1.png", "header-1.mb.png", "cached-1.png", "cached-1.mb.png")
  )
})

# ==============================================================================
# Documents
# ==============================================================================

# One document with charts of every system, several to a chunk, a chart
# printed with print(), and a chunk that prints a ggplot2 chart and draws a
# Base R one on the same device. Its setup chunk only attaches maidr, which
# these tests have loaded already: maidr installs itself into the knit from
# the first chart.
several_charts_rmd <- function(dir, self_contained) {
  rmd <- file.path(dir, "charts.Rmd")
  writeLines(c(
    "---",
    "title: Several charts",
    "output:",
    "  html_document:",
    sprintf("    self_contained: %s", tolower(self_contained)),
    "---",
    "",
    "```{r setup, message = FALSE}",
    "library(maidr)",
    "library(ggplot2)",
    "```",
    "",
    "```{r gg, fig.cap = 'Cars by cylinder'}",
    "ggplot(mtcars, aes(factor(cyl))) + geom_bar()",
    "```",
    "",
    "```{r gg2}",
    "ggplot(mtcars, aes(wt, mpg)) + geom_point() + labs(title = 'Weight and mileage')",
    "ggplot(mtcars, aes(factor(gear))) + geom_bar()",
    "```",
    "",
    "```{r lattice}",
    "lattice::xyplot(mpg ~ wt, data = mtcars)",
    "```",
    "",
    "```{r lattice2}",
    "lattice::barchart(c(p = 3, q = 4, r = 2))",
    "```",
    "",
    "```{r base, fig.alt = 'Three bars'}",
    "barplot(c(a = 3, b = 5, c = 2))",
    "```",
    "",
    "```{r base2}",
    "hist(mtcars$mpg)",
    "```",
    "",
    "```{r printed}",
    "print(ggplot(mtcars, aes(factor(am))) + geom_bar())",
    "```",
    "",
    "```{r mixed}",
    "print(ggplot(mtcars, aes(factor(vs))) + geom_bar())",
    "plot(mtcars$wt, mtcars$mpg)",
    "```"
  ), rmd)
  rmd
}

expect_several_charts <- function(out) {
  html <- paste(readLines(out, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  doc <- xml2::read_html(out, encoding = "UTF-8")
  testthat::expect_length(xml2::xml_find_all(doc, "//iframe"), 0L)

  charts <- inline_charts(out)
  testthat::expect_length(charts, 10L)
  prefixes <- vapply(charts, expect_own_selectors, character(1))
  testthat::expect_false(anyDuplicated(prefixes) > 0L)
  ids <- xml2::xml_attr(xml2::xml_find_all(doc, "//*[@id]"), "id")
  testthat::expect_false(anyDuplicated(ids) > 0L)
  # In the order the document draws them.
  types <- vapply(charts, function(svg) {
    data <- jsonlite::parse_json(xml2::xml_attr(svg, "data-maidr-knitr"))
    data$subplots[[1]][[1]]$layers[[1]]$type
  }, character(1))
  testthat::expect_identical(
    types,
    c("bar", "point", "bar", "point", "bar", "bar", "hist", "bar", "bar", "point")
  )
  testthat::expect_identical(
    unname(chart_names(out)[c(1, 2, 6)]),
    c("Cars by cylinder", "Weight and mileage", "Three bars")
  )
  testthat::expect_match(html, ">Cars by cylinder</p>", fixed = TRUE)

  # maidr.js, once; and the script that binds the charts.
  testthat::expect_identical(
    lengths(regmatches(html, gregexpr("window.maidrLive={", html, fixed = TRUE))) +
      length(xml2::xml_find_all(doc, "//script[contains(@src, 'maidr.js')]")),
    1L
  )
  testthat::expect_identical(
    lengths(regmatches(html, gregexpr("window.__maidrKnitr = true", html, fixed = TRUE))) +
      length(xml2::xml_find_all(doc, "//script[contains(@src, 'knitr-inline.js')]")),
    1L
  )
  # The printed chart, and both figures of the chunk that mixes a printed
  # chart with a Base R one, are charts in place of knitr's figures.
  testthat::expect_length(xml2::xml_find_all(doc, "//img"), 0L)
  invisible(html)
}

test_that("only library(maidr) shows an R Markdown page's charts inline, on every render", {
  testthat::skip_on_cran()
  skip_if_no_render()
  testthat::skip_if_not_installed("rmarkdown")
  testthat::skip_if_not_installed("lattice")
  testthat::skip_if_not(rmarkdown::pandoc_available("2.0"), "pandoc is not available")
  local_knitr_state()
  opened <- 0L
  testthat::local_mocked_bindings(
    display_html = function(html_doc) opened <<- opened + 1L,
    session_is_interactive = function() TRUE,
    .package = "maidr"
  )
  dir <- withr::local_tempdir("maidr-rmd-")

  linked <- rmarkdown::render(
    several_charts_rmd(dir, FALSE),
    quiet = TRUE, envir = new.env()
  )
  html <- expect_several_charts(linked)
  testthat::expect_match(
    html,
    sprintf('<script src="charts_files/maidr-%s/maidr.js" defer></script>', maidr:::MAIDR_VERSION),
    fixed = TRUE
  )
  testthat::expect_true(any(startsWith(list.files(file.path(dir, "charts_files")), "maidr-knitr-")))
  testthat::expect_identical(opened, 0L)

  # The same session renders it again, self-contained: maidr installs itself
  # into the second knit as into the first.
  embedded <- rmarkdown::render(
    several_charts_rmd(dir, TRUE),
    quiet = TRUE, envir = new.env()
  )
  expect_several_charts(embedded)
  testthat::expect_false(dir.exists(file.path(dir, "charts_files")))
  testthat::expect_identical(opened, 0L)
})

test_that("a chunk printing a lattice or ggplot2 chart beside Base R shows each chart", {
  testthat::skip_on_cran()
  skip_if_no_render()
  testthat::skip_if_not_installed("lattice")
  local_knitr_state()
  dir <- withr::local_tempdir("maidr-knit-")

  page <- knit_for(c(
    "```{r lattice}",
    "print(lattice::xyplot(mpg ~ wt, data = mtcars))",
    "barplot(c(a = 1, b = 2))",
    "```",
    "```{r ggplot}",
    "barplot(c(a = 1, b = 2, c = 3, d = 4))",
    "print(ggplot2::ggplot(mtcars, ggplot2::aes(factor(cyl))) + ggplot2::geom_bar())",
    "```",
    "```{r alone}",
    "barplot(c(a = 1, b = 2))",
    "```"
  ), dir)

  # Each figure is the chart drawn on its page, in the order drawn.
  testthat::expect_identical(
    chart_summaries(page),
    c("point:32", "bar:2", "bar:4", "bar:3", "bar:2")
  )
  testthat::expect_identical(lengths(regmatches(page, gregexpr("!\\[\\]\\(", page))), 0L)
})

test_that("a chunk's Base R chart is read from its own device while another is open", {
  testthat::skip_on_cran()
  skip_if_no_render()
  local_knitr_state()
  dir <- withr::local_tempdir("maidr-knit-")
  # A device left open -- a pdf(), an IDE's screen -- is made current again
  # when knitr closes the device it saves a figure on.
  grDevices::pdf(NULL)
  other <- grDevices::dev.cur()
  withr::defer(if (other %in% grDevices::dev.list()) grDevices::dev.off(other))

  page <- knit_for(c(
    "```{r bars}",
    "barplot(c(a = 1, b = 2))",
    "```",
    "```{r hist}",
    "hist(mtcars$mpg)",
    "```"
  ), dir)

  charts <- inline_charts(page)
  testthat::expect_length(charts, 2L)
  types <- vapply(charts, function(svg) {
    data <- jsonlite::parse_json(xml2::xml_attr(svg, "data-maidr-knitr"))
    data$subplots[[1]][[1]]$layers[[1]]$type
  }, character(1))
  testthat::expect_identical(types, c("bar", "hist"))
  testthat::expect_false(maidr:::has_device_calls(other))
  testthat::expect_identical(unname(grDevices::dev.cur()), unname(other))
})

test_that("a bookdown text reference with markup in a chart's caption leaves the chart whole", {
  testthat::skip_on_cran()
  skip_if_no_render()
  testthat::skip_if_not_installed("rmarkdown")
  testthat::skip_if_not_installed("bookdown")
  testthat::skip_if_not(rmarkdown::pandoc_available("2.0"), "pandoc is not available")
  local_knitr_state()
  dir <- withr::local_tempdir("maidr-textref-")
  writeLines(c(
    "---", "title: refs", "output:", "  bookdown::html_document2:",
    "    self_contained: false", "---",
    "```{r, include = FALSE}", "library(maidr)", "maidr_on()", "```",
    "(ref:cap) A caption with *emphasis*, $x^2$ and [a link](https://example.org).",
    "",
    "```{r bars, fig.cap = '(ref:cap)'}", "barplot(c(a = 1, b = 2))", "```"
  ), file.path(dir, "refs.Rmd"))

  page <- rmarkdown::render(file.path(dir, "refs.Rmd"), quiet = TRUE, envir = new.env())
  doc <- xml2::read_html(page)
  svg <- xml2::xml_find_all(doc, "//svg[@data-maidr-knitr]")
  testthat::expect_length(svg, 1L)
  # The chart keeps its data and its name, which is the caption bookdown
  # numbered and wrote as HTML.
  testthat::expect_true(jsonlite::validate(xml2::xml_attr(svg, "data-maidr-knitr")))
  name <- chart_names(page)
  testthat::expect_match(name, "^Figure 1: +A caption with emphasis, .*and a link[.]$")
  caption <- xml2::xml_find_first(doc, "//p[contains(@class, 'maidr-knitr-caption')]")
  testthat::expect_length(xml2::xml_find_all(caption, ".//em | .//a"), 2L)
})

test_that("a document rendered from a chunk shows its charts, as does the chunk", {
  testthat::skip_on_cran()
  skip_if_no_render()
  testthat::skip_if_not_installed("rmarkdown")
  testthat::skip_if_not(rmarkdown::pandoc_available("2.0"), "pandoc is not available")
  local_knitr_state()
  dir <- withr::local_tempdir("maidr-nested-")
  header <- c(
    "---", "title: nested", "output:", "  html_document:", "    self_contained: false", "---"
  )
  # The inner document installs maidr into its own knit from inside the
  # outer chunk's code: its figures are its own, not pages that code replays.
  writeLines(c(
    header,
    "```{r}", "library(maidr); maidr_on()", "barplot(c(in1 = 1, in2 = 2))", "```",
    "```{r second}", "barplot(c(in3 = 1, in4 = 2))", "```"
  ), file.path(dir, "inner.Rmd"))
  writeLines(c(
    header,
    "```{r}", "library(maidr); maidr_on()", "```",
    "```{r o1}",
    "barplot(c(o1 = 5, o2 = 6))",
    "invisible(rmarkdown::render('inner.Rmd', quiet = TRUE, envir = new.env()))",
    "```",
    "```{r o2}", "plot(1:3, c(9, 8, 7))", "```"
  ), file.path(dir, "outer.Rmd"))

  outer <- rmarkdown::render(file.path(dir, "outer.Rmd"), quiet = TRUE, envir = new.env())
  for (page in c(file.path(dir, "inner.html"), outer)) {
    doc <- xml2::read_html(page)
    testthat::expect_length(inline_charts(page), 2L)
    testthat::expect_length(xml2::xml_find_all(doc, "//img"), 0L)
  }
})

test_that("charts first drawn in a child document are charts in every render", {
  testthat::skip_on_cran()
  skip_if_no_render()
  testthat::skip_if_not_installed("rmarkdown")
  testthat::skip_if_not(rmarkdown::pandoc_available("2.0"), "pandoc is not available")
  local_knitr_state()
  dir <- withr::local_tempdir("maidr-children-")
  for (child in c("ca", "cb")) {
    writeLines(
      c(sprintf("```{r %s}", child), sprintf("barplot(c(%s = 1, z = 2))", child), "```"),
      file.path(dir, paste0(child, ".Rmd"))
    )
  }
  # maidr is loaded already, as in a second render of a session: the first
  # child's barplot installs it, inside the code of the chunk knitting it.
  writeLines(c(
    "---", "title: parent", "output:", "  html_document:", "    self_contained: false", "---",
    "```{r setup}", "library(maidr)", "```",
    "```{r kids, results = 'asis'}",
    "for (f in c('ca.Rmd', 'cb.Rmd')) cat(knitr::knit_child(f, quiet = TRUE))",
    "```",
    "```{r after}", "barplot(c(p1 = 5, p2 = 6))", "```"
  ), file.path(dir, "parent.Rmd"))

  for (i in 1:2) {
    page <- rmarkdown::render(file.path(dir, "parent.Rmd"), quiet = TRUE, envir = new.env())
    testthat::expect_identical(chart_summaries(page), rep("bar:2", 3L), info = paste("render", i))
    testthat::expect_length(xml2::xml_find_all(xml2::read_html(page), "//img"), 0L)
  }
})

test_that("charts written with cat() in an asis loop, and cached charts, bring maidr.js", {
  testthat::skip_on_cran()
  skip_if_no_render()
  local_knitr_state()
  dir <- withr::local_tempdir("maidr-knit-")
  bundle_declared <- function() {
    meta <- knitr::knit_meta(clean = TRUE)
    names <- vapply(meta, function(dep) if (is.null(dep$name)) "" else dep$name, character(1))
    all(c("maidr", "maidr-knitr") %in% names)
  }
  knitr::knit_meta(clean = TRUE)

  page <- knit_for(c(
    "```{r loop, results = 'asis'}",
    "for (v in c('cyl', 'gear')) {",
    "  p <- ggplot2::ggplot(mtcars, ggplot2::aes(factor(.data[[v]]))) + ggplot2::geom_bar()",
    "  cat(knitr::knit_print(p))",
    "}",
    "```"
  ), dir)
  # cat() drops the meta a knit_asis object carries.
  testthat::expect_identical(lengths(regmatches(page, gregexpr("data-maidr-knitr=", page))), 2L)
  testthat::expect_true(bundle_declared())

  cached <- c(
    "```{r gg, cache = TRUE}",
    "ggplot2::ggplot(mtcars, ggplot2::aes(factor(cyl))) + ggplot2::geom_bar()",
    "```",
    "```{r base, cache = TRUE}",
    "barplot(c(a = 1, b = 2))",
    "```"
  )
  first <- knit_for(cached, dir)
  testthat::expect_true(bundle_declared())
  # Run again, from the cache: neither chart is made, and only what knitr
  # cached comes back.
  second <- knit_for(cached, dir)
  testthat::expect_identical(lengths(regmatches(second, gregexpr("data-maidr-knitr=", second))), 2L)
  testthat::expect_true(bundle_declared())

  # The value of inline code, for which no chunk hook runs.
  inline <- knit_for(c(
    "```{r made, include = FALSE}",
    "p <- ggplot2::ggplot(mtcars, ggplot2::aes(factor(cyl))) + ggplot2::geom_bar()",
    "```",
    "",
    "A chart: `r p` and text after it."
  ), dir)
  testthat::expect_identical(lengths(regmatches(inline, gregexpr("data-maidr-knitr=", inline))), 1L)
  testthat::expect_true(bundle_declared())
})

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

test_that("charts after maidr_off() are knitr's figures, and inline again after maidr_on()", {
  testthat::skip_on_cran()
  skip_if_no_render()
  local_knitr_state()
  dir <- withr::local_tempdir("maidr-knit-")
  chart <- c(
    "ggplot2::ggplot(mtcars, ggplot2::aes(factor(cyl))) + ggplot2::geom_bar()",
    "barplot(c(a = 1, b = 2))"
  )

  page <- knit_for(c(
    "```{r before}", chart, "```",
    "```{r}", "maidr::maidr_off()", "```",
    "```{r after}", chart, "```",
    "```{r}", "maidr::maidr_on()", "```",
    "```{r again}", chart, "```"
  ), dir)

  testthat::expect_identical(lengths(regmatches(page, gregexpr("data-maidr-knitr=", page))), 4L)
  types <- figure_types(dir)
  testthat::expect_identical(unname(types[names(types) == "after"]), c("png", "png"))
  # The two charts after maidr_off() are its only figures shown as figures.
  testthat::expect_identical(lengths(regmatches(page, gregexpr("!\\[\\]\\(", page))), 2L)
})

test_that("a Base R chart recorded before maidr_off() is no layer of one after maidr_on()", {
  testthat::skip_on_cran()
  skip_if_no_render()
  local_knitr_state()
  dir <- withr::local_tempdir("maidr-knit-")

  # maidr_off() takes the plot hook out before the chunk's figure is written,
  # so nothing reads the barplot's calls; maidr_on() drops them.
  page <- knit_for(c(
    "```{r before}",
    "barplot(c(A = 10, B = 20, C = 30))",
    "maidr::maidr_off()",
    "```",
    "```{r again}",
    "maidr::maidr_on()",
    "hist(c(1, 2, 2, 3, 3, 3, 4, 4, 5))",
    "```"
  ), dir)

  charts <- inline_charts(page)
  testthat::expect_length(charts, 1L)
  data <- jsonlite::parse_json(xml2::xml_attr(charts[[1]], "data-maidr-knitr"))
  layers <- data$subplots[[1]][[1]]$layers
  testthat::expect_identical(vapply(layers, function(layer) layer$type, character(1)), "hist")
})

# ==============================================================================
# A document in a session of its own
# ==============================================================================

#' How a session started for a test loads this maidr
#'
#' The source tree when the tests run from it, the installed package under
#' R CMD check.
maidr_loader <- function() {
  root <- normalizePath(testthat::test_path("..", ".."), mustWork = FALSE)
  from_source <- requireNamespace("pkgload", quietly = TRUE) &&
    file.exists(file.path(root, "DESCRIPTION")) &&
    file.exists(file.path(root, "R", "maidr.R"))
  if (from_source) {
    sprintf("pkgload::load_all(%s, quiet = TRUE)", deparse(root))
  } else {
    "library(maidr)"
  }
}

test_that("library(maidr) in a document sets up the knit quietly, and every later render", {
  testthat::skip_on_cran()
  skip_if_no_render()
  testthat::skip_if_not_installed("rmarkdown")
  testthat::skip_if_not_installed("lattice")
  testthat::skip_if_not(rmarkdown::pandoc_available("2.0"), "pandoc is not available")
  dir <- withr::local_tempdir("maidr-fresh-")

  document <- function(loader) {
    c(
      "---", "title: fresh", "output:", "  html_document:", "    self_contained: false", "---",
      "```{r}", loader, "library(ggplot2)", "```",
      "```{r}", "ggplot(mtcars, aes(factor(cyl))) + geom_bar()", "```",
      "```{r}", "lattice::xyplot(mpg ~ wt, data = mtcars)", "```",
      "```{r}", "barplot(c(a = 1, b = 2))", "```",
      "```{r}", "print(ggplot(mtcars, aes(factor(gear))) + geom_bar())", "```",
      "```{r}", "print(lattice::xyplot(mpg ~ hp, data = mtcars))", "```"
    )
  }
  writeLines(document(maidr_loader()), file.path(dir, "first.Rmd"))
  writeLines(document("library(maidr)"), file.path(dir, "second.Rmd"))
  script <- file.path(dir, "render.R")
  writeLines(c(
    sprintf(".libPaths(%s)", paste(deparse(.libPaths()), collapse = "")),
    sprintf("setwd(%s)", deparse(dir)),
    "Sys.unsetenv('RSTUDIO')",
    "options(browser = function(url) cat('BROWSER-OPENED', url, '\\n'))",
    "report <- function(name, file) {",
    "  html <- paste(readLines(file, warn = FALSE), collapse = '\\n')",
    "  count <- function(pattern) lengths(regmatches(html, gregexpr(pattern, html)))",
    "  cat('RESULT', name, count('<svg[^>]*data-maidr-knitr='), count('<iframe'),",
    "    count('maidr\\\\.js\" defer'), count('Base R plots are recorded'),",
    "    count('<img src=\"[^\"]*figure-html'), '\\n')",
    "}",
    "report('first', rmarkdown::render('first.Rmd', quiet = TRUE))",
    "report('second', rmarkdown::render('second.Rmd', quiet = TRUE))"
  ), script)

  out <- suppressWarnings(system2(
    file.path(R.home("bin"), "Rscript"), script,
    stdout = TRUE, stderr = TRUE, timeout = 300
  ))
  status <- attr(out, "status")
  log <- paste(out, collapse = "\n")
  testthat::expect_identical(if (is.null(status)) 0L else status, 0L, info = log)
  testthat::expect_false(any(grepl("BROWSER-OPENED", out, fixed = TRUE)), info = log)
  # Five charts inline, the two printed ones among them, no frame, maidr.js
  # once, no startup message in the page, and no figure left.
  testthat::expect_true("RESULT first 5 0 1 0 0 " %in% out, info = log)
  testthat::expect_true("RESULT second 5 0 1 0 0 " %in% out, info = log)
})

test_that("a chart left on the session's device before a render is no chunk's chart", {
  testthat::skip_on_cran()
  skip_if_no_render()
  testthat::skip_if_not_installed("rmarkdown")
  testthat::skip_if_not(rmarkdown::pandoc_available("2.0"), "pandoc is not available")
  dir <- withr::local_tempdir("maidr-session-")

  # The session's device is current again when the grid chunk's figure is
  # written, after knitr has closed the chunk's own devices.
  writeLines(c(
    "---", "title: session", "output:", "  html_document:", "    self_contained: false", "---",
    "```{r}", "library(maidr)", "```",
    "```{r bars}", "barplot(c(doc = 2))", "```",
    "```{r circle, fig.alt = 'A circle'}", "grid::grid.newpage()", "grid::grid.circle()", "```"
  ), file.path(dir, "session.Rmd"))
  script <- file.path(dir, "render.R")
  writeLines(c(
    sprintf(".libPaths(%s)", paste(deparse(.libPaths()), collapse = "")),
    sprintf("setwd(%s)", deparse(dir)),
    maidr_loader(),
    "barplot(c(console = 1))",
    "session <- grDevices::dev.cur()",
    "file <- rmarkdown::render('session.Rmd', quiet = TRUE)",
    "html <- paste(readLines(file, warn = FALSE), collapse = '\\n')",
    "count <- function(pattern) lengths(regmatches(html, gregexpr(pattern, html)))",
    "cat('RESULT', count('<svg[^>]*data-maidr-knitr='), count('console'),",
    "  count('<img src=\"[^\"]*circle-1[.]svg\" alt=\"A circle\"'),",
    "  maidr:::has_device_calls(session), '\\n')"
  ), script)

  out <- suppressWarnings(system2(
    file.path(R.home("bin"), "Rscript"), script,
    stdout = TRUE, stderr = TRUE, timeout = 300
  ))
  status <- attr(out, "status")
  log <- paste(out, collapse = "\n")
  testthat::expect_identical(if (is.null(status)) 0L else status, 0L, info = log)
  # The document's one chart, the circle as its own figure, and the console
  # chart left to the session.
  testthat::expect_true("RESULT 1 0 1 TRUE " %in% out, info = log)
})

test_that("a render leaves nothing of its knit to the session's own charts", {
  testthat::skip_on_cran()
  skip_if_no_render()
  testthat::skip_if_not_installed("rmarkdown")
  testthat::skip_if_not(rmarkdown::pandoc_available("2.0"), "pandoc is not available")
  dir <- withr::local_tempdir("maidr-after-")

  document <- function(last) {
    c(
      "---", "title: after", "output:", "  html_document:", "    self_contained: false", "---",
      "```{r}", "library(maidr)", "maidr_on()", "```",
      "```{r last}", last, "```"
    )
  }
  writeLines(document("barplot(c(knitA = 1, knitB = 2))"), file.path(dir, "done.Rmd"))
  writeLines(document(c("barplot(c(knitC = 1))", "stop('halt')")), file.path(dir, "failed.Rmd"))
  script <- file.path(dir, "render.R")
  writeLines(c(
    sprintf(".libPaths(%s)", paste(deparse(.libPaths()), collapse = "")),
    sprintf("setwd(%s)", deparse(dir)),
    maidr_loader(),
    "console <- function(name) {",
    "  barplot(c(consoleX = 5))",
    "  calls <- maidr:::get_device_calls()",
    "  labels <- vapply(calls, function(e) paste(names(e$args[[1]]), collapse = '+'), '')",
    "  cat('RESULT', name, paste(labels, collapse = ','), '\\n')",
    "  grDevices::graphics.off()",
    "}",
    "rmarkdown::render('done.Rmd', quiet = TRUE)",
    "cat('HOOKS', length(getHook('before.plot.new')), length(getHook('before.grid.newpage')),",
    "  is.null(getOption('maidr.knit.replayed')), '\\n')",
    "console('done')",
    "try(rmarkdown::render('failed.Rmd', quiet = TRUE), silent = TRUE)",
    "console('failed')",
    "knitr::knit('done.Rmd', output = 'done.md', quiet = TRUE)",
    "cat('KNIT', is.null(knitr::opts_hooks$get('dev')), length(getHook('before.plot.new')), '\\n')",
    "console('knit')"
  ), script)

  out <- suppressWarnings(system2(
    file.path(R.home("bin"), "Rscript"), script,
    stdout = TRUE, stderr = TRUE, timeout = 300
  ))
  status <- attr(out, "status")
  log <- paste(out, collapse = "\n")
  testthat::expect_identical(if (is.null(status)) 0L else status, 0L, info = log)
  # The console chart is the console's call alone, after a render, a render
  # that stopped with an error, and a plain knit; and the hooks of the knit
  # are gone with it.
  testthat::expect_true("RESULT done consoleX " %in% out, info = log)
  testthat::expect_true("RESULT failed consoleX " %in% out, info = log)
  testthat::expect_true("RESULT knit consoleX " %in% out, info = log)
  testthat::expect_true("HOOKS 0 0 TRUE " %in% out, info = log)
  testthat::expect_true("KNIT TRUE 0 " %in% out, info = log)
})

test_that("Quarto shows the charts inline, captions them and resolves a reference to one", {
  testthat::skip_on_cran()
  skip_if_no_render()
  # Quarto runs R chunks through rmarkdown.
  testthat::skip_if_not_installed("rmarkdown")
  testthat::skip_if_not_installed("lattice")
  testthat::skip_if_not_installed("withr")
  quarto <- Sys.which("quarto")
  testthat::skip_if(!nzchar(quarto), "Quarto is not installed")
  withr::local_envvar(QUARTO_R = R.home("bin"))
  dir <- withr::local_tempdir("maidr-qmd-")
  qmd <- file.path(dir, "charts.qmd")
  writeLines(c(
    "---", "title: charts", "format: html", "---",
    "```{r}",
    "#| message: false",
    sprintf(".libPaths(%s)", paste(deparse(.libPaths()), collapse = "")),
    maidr_loader(),
    "library(ggplot2)",
    "```",
    "",
    "See @fig-bars.",
    "",
    "```{r}",
    "#| label: fig-bars",
    "#| fig-cap: Cars by cylinder",
    "ggplot(mtcars, aes(factor(cyl))) + geom_bar()",
    "```",
    "```{r}",
    "#| fig-alt: A scatter",
    "lattice::xyplot(mpg ~ wt, data = mtcars)",
    "```",
    "```{r}",
    "#| fig-cap: Base bars",
    "#| out-width: 50%",
    "barplot(c(a = 1, b = 2))",
    "```",
    "```{r}",
    "plot(1:10)",
    "grid::grid.newpage()",
    "grid::grid.rect()",
    "```",
    "",
    "See @fig-loop-2 and @fig-base.",
    "",
    "```{r}",
    "#| label: fig-loop",
    "#| fig-cap:",
    "#|   - First printed",
    "#|   - Second printed",
    "for (v in c('gear', 'am')) print(ggplot(mtcars, aes(factor(.data[[v]]))) + geom_bar())",
    "```",
    "```{r}",
    "#| label: fig-base",
    "#| fig-cap: A Base R figure",
    "barplot(c(a = 2, b = 1))",
    "```",
    "",
    "See @fig-mix-1, @fig-mix-2 and @fig-mix-3.",
    "",
    # A chart drawn, a figure that is no chart, and a chart returned: one
    # figure each, numbered in the order they were drawn.
    "```{r}",
    "#| label: fig-mix",
    "#| fig-cap:",
    "#|   - Mixed bars",
    "#|   - Mixed surface",
    "#|   - Mixed returned",
    "barplot(c(a = 3, b = 1))",
    "persp(volcano[1:10, 1:10])",
    "ggplot(mtcars, aes(factor(carb))) + geom_bar()",
    "```"
  ), qmd)

  out <- suppressWarnings(system2(
    quarto, c("render", shQuote(qmd), "--quiet"),
    stdout = TRUE, stderr = TRUE, timeout = 300
  ))
  status <- attr(out, "status")
  log <- paste(out, collapse = "\n")
  testthat::expect_identical(if (is.null(status)) 0L else status, 0L, info = log)
  page <- file.path(dir, "charts.html")
  testthat::skip_if_not(file.exists(page))
  html <- paste(readLines(page, warn = FALSE), collapse = "\n")
  doc <- xml2::read_html(page)

  charts <- xml2::xml_find_all(doc, "//svg[@data-maidr-knitr]")
  testthat::expect_length(charts, 9L)
  testthat::expect_length(xml2::xml_find_all(doc, "//iframe"), 0L)
  testthat::expect_length(xml2::xml_find_all(doc, "//script[contains(@src, 'maidr.js')]"), 1L)
  ids <- xml2::xml_attr(xml2::xml_find_all(doc, "//*[@id]"), "id")
  testthat::expect_false(anyDuplicated(ids) > 0L)
  # Quarto's figure, numbered and referred to, captions the ggplot2 chart
  # once; maidr captions the Base R one, which Quarto does not.
  testthat::expect_match(html, "Figure&nbsp;1", fixed = TRUE)
  testthat::expect_length(
    xml2::xml_find_all(doc, "//figcaption[contains(., 'Cars by cylinder')]"),
    1L
  )
  testthat::expect_false(grepl(">Cars by cylinder</p>", html, fixed = TRUE))
  testthat::expect_match(html, ">Base bars</p>", fixed = TRUE)
  # Quarto's spelling of out.width sizes the chart.
  testthat::expect_match(html, '<div class="figure maidr-knitr" style="width: 50%;">', fixed = TRUE)
  testthat::expect_identical(
    unname(chart_names(page)),
    c(
      "Cars by cylinder", "A scatter", "Base bars", "Scatter plot",
      "First printed", "Second printed", "A Base R figure",
      "Mixed bars", "Mixed returned"
    )
  )
  # Charts in place of the figures of a fig- chunk are Quarto's figures,
  # numbered as its own, captioned by it, and referred to.
  testthat::expect_false(grepl("?@fig-", html, fixed = TRUE))
  testthat::expect_match(html, 'href="#fig-loop-2"[^>]*>Figure&nbsp;3<')
  testthat::expect_match(html, 'href="#fig-base"[^>]*>Figure&nbsp;4<')
  for (i in 1:3) {
    testthat::expect_match(html, sprintf('href="#fig-mix-%d"[^>]*>Figure&nbsp;%d<', i, i + 4L))
  }
  captions <- c(
    "First printed", "Second printed", "A Base R figure", "Mixed bars", "Mixed returned"
  )
  for (caption in captions) {
    testthat::expect_length(
      xml2::xml_find_all(doc, sprintf("//figure[.//svg]/figcaption[contains(., '%s')]", caption)),
      1L
    )
  }
  testthat::expect_length(
    xml2::xml_find_all(doc, "//figure[.//img]/figcaption[contains(., 'Mixed surface')]"),
    1L
  )
  # The figure that is not a chart is an svg image.
  testthat::expect_match(html, '<img src="charts_files/figure-html/[^"]+\\.svg"')
})

test_that("Quarto renders an EPUB with maidr loaded", {
  testthat::skip_on_cran()
  skip_if_no_render()
  testthat::skip_if_not_installed("rmarkdown")
  testthat::skip_if_not_installed("withr")
  quarto <- Sys.which("quarto")
  testthat::skip_if(!nzchar(quarto), "Quarto is not installed")
  withr::local_envvar(QUARTO_R = R.home("bin"))
  dir <- withr::local_tempdir("maidr-qepub-")
  qmd <- file.path(dir, "book.qmd")
  writeLines(c(
    "---", "title: book", "format: epub", "---",
    "```{r}",
    sprintf(".libPaths(%s)", paste(deparse(.libPaths()), collapse = "")),
    maidr_loader(),
    "```",
    "```{r}", "ggplot2::ggplot(mtcars, ggplot2::aes(factor(cyl))) + ggplot2::geom_bar()", "```",
    "```{r}", "barplot(c(a = 1, b = 2))", "```"
  ), qmd)

  out <- suppressWarnings(system2(
    quarto, c("render", shQuote(qmd), "--quiet"),
    stdout = TRUE, stderr = TRUE, timeout = 300
  ))
  status <- attr(out, "status")
  log <- paste(out, collapse = "\n")
  testthat::expect_identical(if (is.null(status)) 0L else status, 0L, info = log)
  testthat::expect_true(file.exists(file.path(dir, "book.epub")))
})
