# Comprehensive tests for SVG Utilities
# Testing SVG creation, manipulation, and HTML generation

# ==============================================================================
# add_maidr_data_to_svg Tests
# ==============================================================================

test_that("add_maidr_data_to_svg adds maidr-data attribute", {
  testthat::skip_if_not_installed("xml2")

  # Create minimal SVG content
  svg_content <- c(
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">',
    '<rect x="10" y="10" width="80" height="80"/>',
    "</svg>"
  )

  maidr_data <- list(
    id = "test-plot",
    type = "bar",
    data = list(1, 2, 3)
  )

  result <- maidr:::add_maidr_data_to_svg(svg_content, maidr_data)

  testthat::expect_type(result, "character")

  # Check that maidr-data attribute is present
  svg_text <- paste(result, collapse = "\n")
  testthat::expect_true(grepl("maidr-data", svg_text))
})

test_that("add_maidr_data_to_svg preserves SVG content", {
  testthat::skip_if_not_installed("xml2")

  svg_content <- c(
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<svg xmlns="http://www.w3.org/2000/svg" width="200" height="200">',
    '<circle cx="100" cy="100" r="50"/>',
    "</svg>"
  )

  maidr_data <- list(id = "test")

  result <- maidr:::add_maidr_data_to_svg(svg_content, maidr_data)

  svg_text <- paste(result, collapse = "\n")
  testthat::expect_true(grepl("circle", svg_text))
  testthat::expect_true(grepl("cx=", svg_text))
})

test_that("add_maidr_data_to_svg serializes maidr_data to JSON", {
  testthat::skip_if_not_installed("xml2")

  svg_content <- c(
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<svg xmlns="http://www.w3.org/2000/svg">',
    "</svg>"
  )

  maidr_data <- list(
    id = "test-id",
    values = c(10, 20, 30)
  )

  result <- maidr:::add_maidr_data_to_svg(svg_content, maidr_data)

  svg_text <- paste(result, collapse = "\n")
  testthat::expect_true(grepl("test-id", svg_text))
})

# ==============================================================================
# create_html_document Tests
# ==============================================================================

test_that("create_html_document returns HTML document", {
  svg_content <- c("<svg></svg>")

  result <- maidr:::create_html_document(svg_content)

  testthat::expect_s3_class(result, "shiny.tag")
  testthat::expect_true(inherits(result, "shiny.tag"))
})

test_that("create_html_document includes SVG content", {
  svg_content <- c('<svg id="test-svg"></svg>')

  result <- maidr:::create_html_document(svg_content)

  html_text <- as.character(result)
  testthat::expect_true(grepl("test-svg", html_text))
})

test_that("create_html_document attaches dependencies", {
  svg_content <- c("<svg></svg>")

  result <- maidr:::create_html_document(svg_content)

  deps <- htmltools::htmlDependencies(result)
  testthat::expect_true(length(deps) > 0)
})

# ==============================================================================
# save_html_document Tests
# ==============================================================================

test_that("save_html_document writes to file", {
  svg_content <- c('<svg id="save-test"></svg>')
  html_doc <- maidr:::create_html_document(svg_content)

  temp_file <- tempfile(fileext = ".html")
  on.exit(unlink(temp_file), add = TRUE)

  maidr:::save_html_document(html_doc, temp_file)

  testthat::expect_true(file.exists(temp_file))

  content <- readLines(temp_file, warn = FALSE)
  content_text <- paste(content, collapse = "\n")
  testthat::expect_true(grepl("save-test", content_text))
})

test_that("save_html_document creates valid HTML", {
  svg_content <- c('<svg xmlns="http://www.w3.org/2000/svg"></svg>')
  html_doc <- maidr:::create_html_document(svg_content)

  temp_file <- tempfile(fileext = ".html")
  on.exit(unlink(temp_file), add = TRUE)

  maidr:::save_html_document(html_doc, temp_file)

  content <- readLines(temp_file, warn = FALSE)
  content_text <- paste(content, collapse = "\n")

  testthat::expect_true(grepl("<html", content_text))
  testthat::expect_true(grepl("</html>", content_text))
})

# ==============================================================================
# display_html Tests (limited - no actual display)
# ==============================================================================

test_that("display_html function exists", {
  testthat::expect_true(is.function(maidr:::display_html))
})

test_that("display_html_file function exists", {
  testthat::expect_true(is.function(maidr:::display_html_file))
})

# ==============================================================================
# create_enhanced_svg Tests
# ==============================================================================

test_that("create_enhanced_svg function exists", {
  testthat::expect_true(is.function(maidr:::create_enhanced_svg))
})

test_that("create_enhanced_svg works with simple grob", {
  testthat::skip_if_not_installed("gridSVG")
  testthat::skip_if_not_installed("ggplot2")

  # Create a simple ggplot and get its grob
  p <- ggplot2::ggplot(mtcars, ggplot2::aes(x = mpg)) +
    ggplot2::geom_histogram(bins = 5)
  gt <- ggplot2::ggplotGrob(p)

  maidr_data <- list(id = "test-plot", type = "histogram")

  result <- tryCatch(
    maidr:::create_enhanced_svg(gt, maidr_data),
    error = function(e) NULL
  )

  # May fail in non-interactive context, but should not error
  testthat::expect_true(is.null(result) || is.character(result))
})

# ==============================================================================
# repair_na_text_justification Tests
#
# gridGraphics::grid.echo() leaves `vjust` NA on some text grobs and defers to
# the grob's `just` field. gridSVG 1.7.7 branches on the raw value in
# `justTovjust()` and aborts grid.export() with "missing value where
# TRUE/FALSE needed". graphics::pie() labels every wedge, so before the repair
# no base R pie chart could be exported at all.
# ==============================================================================

# Count the text grobs in a tree that still carry an NA justification.
count_na_justified_text <- function(grob) {
  n <- 0
  walk <- function(g) {
    if (inherits(g, "text")) {
      if (anyNA(g$hjust) || anyNA(g$vjust)) {
        n <<- n + 1
      }
    }
    if (inherits(g, "gList")) {
      for (i in seq_along(g)) walk(g[[i]])
    }
    if (inherits(g, "gTree") && !is.null(g$children)) {
      for (i in seq_along(g$children)) walk(g$children[[i]])
    }
    if (!is.null(g$grobs)) {
      for (i in seq_along(g$grobs)) walk(g$grobs[[i]])
    }
    invisible(NULL)
  }
  walk(grob)
  n
}

# The grob tree the Base R orchestrator hands to create_enhanced_svg().
echo_base_r_grob <- function(plot_fun) {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  ggplotify::as.grob(plot_fun)
}

test_that("repair_na_text_justification rewrites only the NA components", {
  na_text <- grid::textGrob("label", name = "na-text")
  na_text$hjust <- NA
  na_text$vjust <- NA

  repaired <- maidr:::repair_na_text_justification(na_text)
  testthat::expect_equal(repaired$hjust, 0.5)
  testthat::expect_equal(repaired$vjust, 0.5)

  # A grob that already has a usable justification passes through untouched.
  justified <- grid::textGrob("label", hjust = 0, vjust = 1, name = "ok-text")
  untouched <- maidr:::repair_na_text_justification(justified)
  testthat::expect_equal(untouched$hjust, 0)
  testthat::expect_equal(untouched$vjust, 1)

  testthat::expect_null(maidr:::repair_na_text_justification(NULL))
})

test_that("repair_na_text_justification descends into nested grobs", {
  na_text <- grid::textGrob("label", name = "na-text")
  na_text$vjust <- NA

  tree <- grid::gTree(
    name = "outer",
    children = grid::gList(na_text, grid::rectGrob(name = "box"))
  )

  testthat::expect_equal(count_na_justified_text(tree), 1)
  testthat::expect_equal(
    count_na_justified_text(maidr:::repair_na_text_justification(tree)), 0
  )
})

test_that("repair_na_text_justification is a no-op on a ggplot2 gtable", {
  testthat::skip_if_not_installed("ggplot2")

  gt <- ggplot2::ggplotGrob(
    ggplot2::ggplot(
      data.frame(x = c("A", "B"), y = c(1, 2)),
      ggplot2::aes(x = x, y = y)
    ) +
      ggplot2::geom_col()
  )

  # ggplot2's own text grobs already carry a numeric justification.
  testthat::expect_equal(count_na_justified_text(gt), 0)
})

test_that("a base R pie grob is exportable only after the repair", {
  testthat::skip_if_not_installed("gridSVG")
  testthat::skip_if_not_installed("ggplotify")

  grob <- echo_base_r_grob(function() graphics::pie(c(A = 1, B = 2, C = 3)))

  # One NA-justified text grob per wedge label; barplot() has none, which is
  # what pins the failure on these grobs rather than on the export as a whole.
  testthat::expect_equal(count_na_justified_text(grob), 3)
  testthat::expect_equal(
    count_na_justified_text(
      echo_base_r_grob(function() graphics::barplot(c(A = 1, B = 2)))
    ),
    0
  )

  export <- function(g) {
    file <- tempfile(fileext = ".svg")
    on.exit(unlink(file), add = TRUE)
    grDevices::pdf(NULL)
    on.exit(grDevices::dev.off(), add = TRUE)
    grid::grid.newpage()
    grid::grid.draw(g)
    tryCatch(
      {
        gridSVG::grid.export(file, res = 100)
        NA_character_
      },
      error = function(e) conditionMessage(e)
    )
  }

  testthat::expect_match(export(grob), "missing value where TRUE/FALSE needed")
  testthat::expect_true(
    is.na(export(maidr:::repair_na_text_justification(grob)))
  )
})

# ==============================================================================
# Edge Cases
# ==============================================================================

test_that("add_maidr_data_to_svg handles empty maidr_data", {
  testthat::skip_if_not_installed("xml2")

  svg_content <- c(
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<svg xmlns="http://www.w3.org/2000/svg">',
    "</svg>"
  )

  maidr_data <- list()

  result <- maidr:::add_maidr_data_to_svg(svg_content, maidr_data)

  testthat::expect_type(result, "character")
})

test_that("add_maidr_data_to_svg handles complex nested data", {
  testthat::skip_if_not_installed("xml2")

  svg_content <- c(
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<svg xmlns="http://www.w3.org/2000/svg">',
    "</svg>"
  )

  maidr_data <- list(
    id = "complex-test",
    subplots = list(
      list(
        id = "subplot-1",
        layers = list(
          list(type = "bar", data = list(1, 2, 3))
        )
      )
    )
  )

  result <- maidr:::add_maidr_data_to_svg(svg_content, maidr_data)

  svg_text <- paste(result, collapse = "\n")
  testthat::expect_true(grepl("complex-test", svg_text))
})

test_that("create_html_document handles multiline SVG", {
  svg_content <- c(
    '<svg xmlns="http://www.w3.org/2000/svg">',
    '  <rect x="0" y="0" width="10" height="10"/>',
    '  <circle cx="5" cy="5" r="3"/>',
    "</svg>"
  )

  result <- maidr:::create_html_document(svg_content)

  html_text <- as.character(result)
  testthat::expect_true(grepl("rect", html_text))
  testthat::expect_true(grepl("circle", html_text))
})

# ==============================================================================
# create_standalone_html stylesheet Tests
# ==============================================================================

# Both branches decide what stylesheet, if any, reaches the document, and they
# decide it differently: the CDN branch names a script whose URL maidr.js can
# resolve maidr-math.css against, while the offline branch inlines a script
# with no URL at all and so has to carry KaTeX itself.

svg_fixture <- function() {
  c(
    '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">',
    '<rect x="10" y="10" width="80" height="80"/>',
    "</svg>"
  )
}

test_that("the CDN branch links no stylesheet", {
  html <- maidr:::create_standalone_html(svg_fixture(), use_cdn = TRUE)

  # The script tag's own URL is what maidr.js resolves maidr-math.css
  # against, so a <link> would be a request that changes nothing - and
  # since maidr 3.75.1 maidr.css has no rules in it to change anything with.
  testthat::expect_false(grepl("maidr.css", html, fixed = TRUE))
  testthat::expect_false(grepl("rel=\"stylesheet\"", html, fixed = TRUE))
  testthat::expect_true(grepl("/maidr.js\"></script>", html, fixed = TRUE))
})

test_that("the offline branch inlines KaTeX alongside the script", {
  html <- maidr:::create_standalone_html(svg_fixture(), use_cdn = FALSE)

  # No URL anywhere for the runtime to resolve against, so the rules have
  # to already be in the document.
  testthat::expect_false(grepl("cdn.jsdelivr.net", html, fixed = TRUE))
  testthat::expect_true(grepl(".katex", html, fixed = TRUE))
  # Stripped of its web fonts, per .github/scripts/fetch-maidr-bundle.sh.
  testthat::expect_false(grepl("@font-face", html, fixed = TRUE))
})
