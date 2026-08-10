# Comprehensive tests for BaseRPieLayerProcessor
#
# `graphics::pie()` draws one polygon per wedge, so the payload is 1-D and
# flat: one {x, y} point per slice, x the slice label and y its magnitude. No
# percentage is emitted (the frontend derives it) and no orientation (a pie
# has none). Slices stay in recorded-call order, because polygon k is slice k.

pie_layer_info <- function(..., index = 1) {
  list(
    index = index,
    function_name = "pie",
    plot_call = list(
      function_name = "pie",
      args = list(...)
    )
  )
}

slice_labels <- function(data) {
  vapply(data, function(pt) as.character(pt$x), character(1))
}

slice_values <- function(data) {
  vapply(data, function(pt) as.numeric(pt$y), numeric(1))
}

# ==============================================================================
# Tier 1: Initialization & Core Methods
# ==============================================================================

test_that("BaseRPieLayerProcessor initializes correctly", {
  processor <- maidr:::BaseRPieLayerProcessor$new(list(index = 1))

  expect_processor_r6(processor, "BaseRPieLayerProcessor")
  testthat::expect_equal(processor$get_layer_index(), 1)
})

test_that("BaseRPieLayerProcessor extract_data() emits one point per slice", {
  info <- pie_layer_info(c(Apples = 30, Bananas = 50, Cherries = 20))
  processor <- maidr:::BaseRPieLayerProcessor$new(info)

  data <- processor$extract_data(info)

  testthat::expect_type(data, "list")
  testthat::expect_length(data, 3L)
  testthat::expect_equal(slice_labels(data), c("Apples", "Bananas", "Cherries"))
  testthat::expect_equal(slice_values(data), c(30, 50, 20))
})

test_that("BaseRPieLayerProcessor process() returns correct structure", {
  info <- pie_layer_info(
    c(Apples = 30, Bananas = 50, Cherries = 20),
    main = "Fruit sales",
    xlab = "Fruit",
    ylab = "Units"
  )
  processor <- maidr:::BaseRPieLayerProcessor$new(info)

  result <- processor$process(NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, info)

  expect_processor_output(result)
  testthat::expect_equal(result$type, "pie")
  testthat::expect_equal(result$title, "Fruit sales")
  testthat::expect_equal(result$axes$x$label, "Fruit")
  testthat::expect_equal(result$axes$y$label, "Units")
  testthat::expect_length(result$data, 3L)
  testthat::expect_false("orientation" %in% names(result))
})

test_that("BaseRPieLayerProcessor keeps slices in recorded-call order", {
  # The SVG is replayed from these same arguments, so polygon k is slice k.
  # Sorting here -- by size or alphabetically -- would desynchronise every
  # announced value from the wedge it highlights.
  info <- pie_layer_info(c(Zebra = 5, Apple = 50, Mango = 20))
  processor <- maidr:::BaseRPieLayerProcessor$new(info)

  testthat::expect_false(processor$needs_reordering())
  testthat::expect_equal(
    slice_labels(processor$extract_data(info)),
    c("Zebra", "Apple", "Mango")
  )
})

# ==============================================================================
# Tier 2: Edge Cases
# ==============================================================================

test_that("BaseRPieLayerProcessor handles NULL layer_info", {
  processor <- maidr:::BaseRPieLayerProcessor$new(list(index = 1))

  testthat::expect_length(processor$extract_data(NULL), 0L)
  testthat::expect_equal(processor$extract_main_title(NULL), "")
  # What a pie's axes hold is a property of the chart type, not of the call.
  testthat::expect_equal(processor$extract_axis_titles(NULL)$x$label, "Category")
  testthat::expect_equal(processor$extract_axis_titles(NULL)$y$label, "Value")
})

test_that("BaseRPieLayerProcessor handles a missing or non-numeric x", {
  no_args <- pie_layer_info()
  character_x <- pie_layer_info(c("a", "b"))

  testthat::expect_length(
    maidr:::BaseRPieLayerProcessor$new(no_args)$extract_data(no_args), 0L
  )
  testthat::expect_length(
    maidr:::BaseRPieLayerProcessor$new(character_x)$extract_data(character_x), 0L
  )
})

test_that("BaseRPieLayerProcessor handles a single slice", {
  info <- pie_layer_info(c(Whole = 1))
  data <- maidr:::BaseRPieLayerProcessor$new(info)$extract_data(info)

  testthat::expect_length(data, 1L)
  testthat::expect_equal(data[[1]]$x, "Whole")
  testthat::expect_equal(data[[1]]$y, 1)
})

test_that("BaseRPieLayerProcessor keeps a zero-valued slice", {
  # pie() still draws (a degenerate) polygon for a zero slice, so dropping it
  # would shift every later slice off its wedge.
  info <- pie_layer_info(c(Empty = 0, Full = 10))
  data <- maidr:::BaseRPieLayerProcessor$new(info)$extract_data(info)

  testthat::expect_equal(slice_labels(data), c("Empty", "Full"))
  testthat::expect_equal(slice_values(data), c(0, 10))
})

test_that("BaseRPieLayerProcessor generate_selectors() returns none without a grob tree", {
  info <- pie_layer_info(c(1, 2, 3))
  processor <- maidr:::BaseRPieLayerProcessor$new(info)
  data <- processor$extract_data(info)

  selectors <- processor$generate_selectors(info, NULL, data)

  testthat::expect_type(selectors, "list")
  testthat::expect_length(selectors, 0L)
})

# ==============================================================================
# Tier 3: Label Resolution
# ==============================================================================

test_that("BaseRPieLayerProcessor labels slices by position when x is unnamed", {
  info <- pie_layer_info(c(10, 20, 30))
  data <- maidr:::BaseRPieLayerProcessor$new(info)$extract_data(info)

  testthat::expect_equal(slice_labels(data), c("1", "2", "3"))
})

test_that("BaseRPieLayerProcessor prefers an explicit labels argument", {
  info <- pie_layer_info(
    c(Apples = 30, Bananas = 50),
    labels = c("First", "Second")
  )
  data <- maidr:::BaseRPieLayerProcessor$new(info)$extract_data(info)

  testthat::expect_equal(slice_labels(data), c("First", "Second"))
})

test_that("BaseRPieLayerProcessor announces labels = NA slices by position", {
  # pie(labels = NA) draws neither label nor leader line, but the wedges are
  # still there and still navigable -- "1", "2", "3" beats "NA", "NA", "NA".
  info <- pie_layer_info(c(10, 20, 30), labels = NA)
  data <- maidr:::BaseRPieLayerProcessor$new(info)$extract_data(info)

  testthat::expect_equal(slice_labels(data), c("1", "2", "3"))
})

test_that("BaseRPieLayerProcessor indexes short labels rather than recycling", {
  # pie() itself looks up `labels[i]`, so a short vector leaves the trailing
  # slices unlabelled rather than restarting from the first label.
  info <- pie_layer_info(c(10, 20, 30), labels = "Only")
  data <- maidr:::BaseRPieLayerProcessor$new(info)$extract_data(info)

  testthat::expect_equal(slice_labels(data), c("Only", "2", "3"))
})

test_that("BaseRPieLayerProcessor resolves a named x argument", {
  # pie()'s first formal is literally `x`, so a named `x =` wins over the
  # first unnamed argument the way the call itself matches them.
  info <- pie_layer_info(x = c(P = 5, Q = 15))
  data <- maidr:::BaseRPieLayerProcessor$new(info)$extract_data(info)

  testthat::expect_equal(slice_labels(data), c("P", "Q"))
  testthat::expect_equal(slice_values(data), c(5, 15))
})

test_that("BaseRPieLayerProcessor defaults its axis titles and main title", {
  # pie() writes no axis title, so an author who wrote none leaves both
  # nameless. A pie always holds labelled categories against their
  # magnitudes, so that is what the defaults say -- the words py-maidr's
  # pie chart uses too.
  info <- pie_layer_info(c(1, 2))
  processor <- maidr:::BaseRPieLayerProcessor$new(info)

  axes <- processor$extract_axis_titles(info)

  testthat::expect_named(axes, c("x", "y"))
  testthat::expect_equal(axes$x$label, "Category")
  testthat::expect_equal(axes$y$label, "Value")
  testthat::expect_equal(processor$extract_main_title(info), "")
})

test_that("BaseRPieLayerProcessor lets an author's axis titles win", {
  info <- pie_layer_info(c(1, 2), xlab = "Fruit", ylab = "Units")
  axes <- maidr:::BaseRPieLayerProcessor$new(info)$extract_axis_titles(info)

  testthat::expect_equal(axes$x$label, "Fruit")
  testthat::expect_equal(axes$y$label, "Units")
})

test_that("BaseRPieLayerProcessor treats a blank axis title as unwritten", {
  # pie(xlab = "") draws no title at all, so the default is no less true
  # than it is for a call that omitted the argument.
  info <- pie_layer_info(c(1, 2), xlab = "", ylab = "")
  axes <- maidr:::BaseRPieLayerProcessor$new(info)$extract_axis_titles(info)

  testthat::expect_equal(axes$x$label, "Category")
  testthat::expect_equal(axes$y$label, "Value")
})

# ==============================================================================
# Tier 4: Selector Generation
# ==============================================================================

# A stand-in for the exported grob tree: pie() names each wedge
# `graphics-plot-<panel>-polygon-<k>`.
polygon_tree <- function(names) {
  grid::gTree(
    name = "graphics-plot-1",
    children = do.call(
      grid::gList,
      lapply(names, function(name) {
        grid::polygonGrob(x = c(0, 1, 1), y = c(0, 0, 1), name = name)
      })
    )
  )
}

test_that("BaseRPieLayerProcessor emits one selector per wedge", {
  info <- pie_layer_info(c(A = 1, B = 2, C = 3))
  processor <- maidr:::BaseRPieLayerProcessor$new(info)
  data <- processor$extract_data(info)

  gt <- polygon_tree(paste0("graphics-plot-1-polygon-", 1:3))
  selectors <- processor$generate_selectors(info, gt, data)

  testthat::expect_length(selectors, 3L)
  testthat::expect_equal(
    unlist(selectors, use.names = FALSE),
    paste0("#graphics-plot-1-polygon-", 1:3, "\\.1 polygon")
  )
})

test_that("BaseRPieLayerProcessor sorts wedge grobs numerically", {
  # `density =` shading interleaves a segments grob per hatch line, so the
  # polygon grobs are no longer contiguous in tree order -- and a
  # lexicographic sort would place "-polygon-10" before "-polygon-2".
  info <- pie_layer_info(stats::setNames(rep(1, 12), LETTERS[1:12]))
  processor <- maidr:::BaseRPieLayerProcessor$new(info)
  data <- processor$extract_data(info)

  shuffled <- paste0("graphics-plot-1-polygon-", c(10, 2, 12, 1, 3:9, 11))
  selectors <- processor$generate_selectors(info, polygon_tree(shuffled), data)

  testthat::expect_equal(
    unlist(selectors, use.names = FALSE),
    paste0("#graphics-plot-1-polygon-", 1:12, "\\.1 polygon")
  )
})

test_that("BaseRPieLayerProcessor never fabricates a missing wedge selector", {
  # Fewer polygons than slices means these are not this pie's grobs. Filling
  # the gap with a guessed id would silently highlight another panel's wedges
  # while the payload still looked healthy (issue #83).
  info <- pie_layer_info(c(A = 1, B = 2, C = 3))
  processor <- maidr:::BaseRPieLayerProcessor$new(info)
  data <- processor$extract_data(info)

  gt <- polygon_tree(paste0("graphics-plot-1-polygon-", 1:2))
  selectors <- processor$generate_selectors(info, gt, data)

  testthat::expect_type(selectors, "list")
  testthat::expect_length(selectors, 0L)
})

test_that("BaseRPieLayerProcessor scopes wedge grobs to its own panel", {
  info <- pie_layer_info(c(A = 1, B = 2), index = 2)
  info$group_index <- 2
  processor <- maidr:::BaseRPieLayerProcessor$new(info)
  data <- processor$extract_data(info)

  gt <- polygon_tree(c(
    paste0("graphics-plot-1-polygon-", 1:3),
    paste0("graphics-plot-2-polygon-", 1:2)
  ))
  selectors <- processor$generate_selectors(info, gt, data)

  testthat::expect_equal(
    unlist(selectors, use.names = FALSE),
    paste0("#graphics-plot-2-polygon-", 1:2, "\\.1 polygon")
  )
})

# ==============================================================================
# Tier 5: Adapter, factory and end-to-end payload
# ==============================================================================

test_that("the Base R adapter detects a pie() call", {
  adapter <- maidr:::BaseRAdapter$new()

  testthat::expect_equal(
    adapter$detect_layer_type(list(function_name = "pie", args = list())),
    "pie"
  )
})

test_that("the Base R processor factory serves a pie processor", {
  factory <- maidr:::BaseRProcessorFactory$new()

  testthat::expect_true("pie" %in% factory$get_supported_types())
  testthat::expect_s3_class(
    factory$create_processor("pie", list(index = 1)),
    "BaseRPieLayerProcessor"
  )
})

test_that("a rendered Base R pie carries the flat wire format", {
  testthat::skip_if_not_installed("jsonlite")
  testthat::skip_if_not_installed("xml2")
  testthat::skip_if_not_installed("gridSVG")

  maidr:::clear_all_device_storage()
  grDevices::pdf(NULL)
  file <- tempfile(fileext = ".html")
  on.exit(
    {
      unlink(file)
      maidr:::clear_all_device_storage()
    },
    add = TRUE
  )

  pie(
    c(Apples = 30, Bananas = 50, Cherries = 20),
    main = "Fruit sales",
    xlab = "Fruit",
    ylab = "Units"
  )
  suppressWarnings(save_html(file = file))
  grDevices::dev.off()

  html <- paste(readLines(file, warn = FALSE), collapse = "\n")
  raw <- regmatches(html, gregexpr('maidr-data="[^"]*"', html))[[1]]
  testthat::expect_gt(length(raw), 0)

  json <- sub('"$', "", sub('^maidr-data="', "", raw[1]))
  json <- gsub("&quot;", '"', json, fixed = TRUE)
  json <- gsub("&lt;", "<", json, fixed = TRUE)
  json <- gsub("&gt;", ">", json, fixed = TRUE)
  json <- gsub("&amp;", "&", json, fixed = TRUE)
  payload <- jsonlite::fromJSON(json, simplifyVector = FALSE)
  layer <- payload$subplots[[1]][[1]]$layers[[1]]

  testthat::expect_equal(layer$type, "pie")
  testthat::expect_equal(layer$title, "Fruit sales")
  testthat::expect_equal(layer$axes$x$label, "Fruit")
  testthat::expect_equal(layer$axes$y$label, "Units")
  testthat::expect_false("orientation" %in% names(layer))

  # Flat PiePoint[]: each entry is one {x, y} object, never a nested series.
  testthat::expect_length(layer$data, 3L)
  for (point in layer$data) {
    testthat::expect_named(point, c("x", "y"))
    testthat::expect_true(is.numeric(point$y))
    testthat::expect_false("percentage" %in% names(point))
  }
  testthat::expect_equal(slice_labels(layer$data), c("Apples", "Bananas", "Cherries"))
  testthat::expect_equal(slice_values(layer$data), c(30, 50, 20))

  # Every selector must resolve to exactly one wedge in the exported SVG.
  testthat::expect_length(layer$selectors, 3L)
  doc <- xml2::read_html(file)
  for (selector in layer$selectors) {
    id <- gsub("\\\\", "", sub(" polygon$", "", sub("^#", "", selector)))
    nodes <- xml2::xml_find_all(
      doc,
      sprintf("//*[@id='%s']//*[local-name()='polygon']", id)
    )
    testthat::expect_length(nodes, 1L)
  }
})
