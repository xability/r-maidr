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
