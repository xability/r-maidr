# Comprehensive tests for Ggplot2PieLayerProcessor
#
# A ggplot2 pie is a geom_col()/geom_bar() layer drawn under coord_polar("y"):
# the stack's segments wrap into wedges. The payload is 1-D and flat -- one
# {x, y} point per wedge, x the slice label and y its magnitude -- and carries
# neither a percentage (the frontend derives it) nor an orientation (a pie has
# none).

skip_if_no_ggplot2 <- function() {
  testthat::skip_if_not_installed("ggplot2")
}

# The stacked column a pie is made of: categories on fill, x collapsed to the
# literal "". Kept coordinate-free so a test can bend it whichever way it needs.
fruit_col <- function(...) {
  df <- data.frame(
    fruit = c("Apples", "Bananas", "Cherries"),
    units = c(30, 50, 20)
  )
  ggplot2::ggplot(df, ggplot2::aes(x = "", y = units, fill = fruit)) +
    ggplot2::geom_col() +
    ggplot2::labs(...)
}

# The canonical pie.
fruit_pie <- function(...) {
  fruit_col(...) + ggplot2::coord_polar("y")
}

# Pull the flat wedge labels / magnitudes back out of a processor result.
wedge_labels <- function(data) {
  vapply(data, function(pt) as.character(pt$x), character(1))
}

wedge_values <- function(data) {
  vapply(data, function(pt) as.numeric(pt$y), numeric(1))
}

# ==============================================================================
# Tier 1: Initialization & Core Methods
# ==============================================================================

test_that("Ggplot2PieLayerProcessor initializes correctly", {
  processor <- maidr:::Ggplot2PieLayerProcessor$new(list(index = 1))

  expect_processor_r6(processor, "Ggplot2PieLayerProcessor")
  testthat::expect_equal(processor$get_layer_index(), 1)
})

test_that("Ggplot2PieLayerProcessor extract_data() emits one point per wedge", {
  skip_if_no_ggplot2()

  processor <- maidr:::Ggplot2PieLayerProcessor$new(list(index = 1))
  data <- processor$extract_data(fruit_pie())

  testthat::expect_type(data, "list")
  testthat::expect_length(data, 3L)
  testthat::expect_equal(wedge_labels(data), c("Apples", "Bananas", "Cherries"))
  testthat::expect_equal(wedge_values(data), c(30, 50, 20))
})

test_that("Ggplot2PieLayerProcessor process() returns correct structure", {
  skip_if_no_ggplot2()

  p <- fruit_pie(title = "Fruit sales", fill = "Fruit", y = "Units")
  processor <- maidr:::Ggplot2PieLayerProcessor$new(list(index = 1))

  layout <- list(
    title = "Fruit sales",
    axes = list(x = "", y = "Units")
  )
  result <- processor$process(p, layout)

  expect_processor_output(result)
  testthat::expect_equal(result$type, "pie")
  testthat::expect_equal(result$title, "Fruit sales")
  testthat::expect_equal(result$axes$x$label, "Fruit")
  testthat::expect_equal(result$axes$y$label, "Units")
  testthat::expect_length(result$data, 3L)
})

test_that("Ggplot2PieLayerProcessor builds the plot when built is NULL", {
  skip_if_no_ggplot2()

  processor <- maidr:::Ggplot2PieLayerProcessor$new(list(index = 1))

  from_null <- processor$extract_data(fruit_pie(), built = NULL)
  from_built <- processor$extract_data(
    fruit_pie(),
    ggplot2::ggplot_build(fruit_pie())
  )

  testthat::expect_equal(from_null, from_built)
})

# ==============================================================================
# Tier 2: Edge Cases
# ==============================================================================

test_that("Ggplot2PieLayerProcessor handles a single wedge", {
  skip_if_no_ggplot2()

  df <- data.frame(fruit = "Apples", units = 42)
  p <- ggplot2::ggplot(df, ggplot2::aes(x = "", y = units, fill = fruit)) +
    ggplot2::geom_col() +
    ggplot2::coord_polar("y")

  processor <- maidr:::Ggplot2PieLayerProcessor$new(list(index = 1))
  data <- processor$extract_data(p)

  testthat::expect_length(data, 1L)
  testthat::expect_equal(data[[1]]$x, "Apples")
  testthat::expect_equal(data[[1]]$y, 42)
})

test_that("Ggplot2PieLayerProcessor handles a zero-row layer", {
  skip_if_no_ggplot2()

  df <- data.frame(fruit = character(0), units = numeric(0))
  p <- ggplot2::ggplot(df, ggplot2::aes(x = "", y = units, fill = fruit)) +
    ggplot2::geom_col() +
    ggplot2::coord_polar("y")

  processor <- maidr:::Ggplot2PieLayerProcessor$new(list(index = 1))
  data <- suppressWarnings(processor$extract_data(p))

  testthat::expect_type(data, "list")
  testthat::expect_length(data, 0L)
})

test_that("Ggplot2PieLayerProcessor falls back to wedge position without a group", {
  skip_if_no_ggplot2()

  # No fill and no discrete x, so every built row shares one group id and no
  # aesthetic names the wedges.
  df <- data.frame(units = c(30, 50, 20))
  p <- ggplot2::ggplot(df, ggplot2::aes(x = "", y = units)) +
    ggplot2::geom_col() +
    ggplot2::coord_polar("y")

  processor <- maidr:::Ggplot2PieLayerProcessor$new(list(index = 1))
  data <- processor$extract_data(p)

  testthat::expect_equal(wedge_labels(data), c("1", "2", "3"))
})

test_that("Ggplot2PieLayerProcessor generate_selectors() returns none without a gtable", {
  skip_if_no_ggplot2()

  processor <- maidr:::Ggplot2PieLayerProcessor$new(list(index = 1))
  selectors <- processor$generate_selectors(fruit_pie(), gt = NULL)

  testthat::expect_type(selectors, "list")
  testthat::expect_length(selectors, 0L)
})

# ==============================================================================
# Tier 3: Coordinate Detection
# ==============================================================================

test_that("a bar layer under coord_polar(theta = 'y') is detected as a pie", {
  skip_if_no_ggplot2()

  adapter <- maidr:::Ggplot2Adapter$new()
  p <- fruit_pie()

  testthat::expect_true(adapter$is_pie_coord(p))
  testthat::expect_equal(adapter$detect_layer_type(p$layers[[1]], p), "pie")
})

test_that("coord_radial(theta = 'y') is detected as a pie too", {
  skip_if_no_ggplot2()
  testthat::skip_if_not(
    "coord_radial" %in% getNamespaceExports("ggplot2"),
    "ggplot2 has no coord_radial()"
  )

  adapter <- maidr:::Ggplot2Adapter$new()
  # coord_radial() produces a CoordRadial, which does NOT inherit CoordPolar.
  p <- fruit_col() + ggplot2::coord_radial(theta = "y")

  testthat::expect_true(adapter$is_pie_coord(p))
  testthat::expect_equal(adapter$detect_layer_type(p$layers[[1]], p), "pie")
})

test_that("coord_polar(theta = 'x') stays a bar chart", {
  skip_if_no_ggplot2()

  # theta = "x" keeps the height on the radius: a coxcomb / rose, which is a
  # bar chart bent around, not a pie.
  adapter <- maidr:::Ggplot2Adapter$new()
  p <- fruit_col() + ggplot2::coord_polar("x")

  testthat::expect_false(adapter$is_pie_coord(p))
  testthat::expect_equal(adapter$detect_layer_type(p$layers[[1]], p), "stacked_bar")
})

test_that("cartesian bar layers keep their existing types", {
  skip_if_no_ggplot2()

  adapter <- maidr:::Ggplot2Adapter$new()
  df <- data.frame(
    x = rep(c("A", "B"), each = 2),
    y = c(10, 15, 20, 25),
    fill = rep(c("G1", "G2"), 2)
  )
  base <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y, fill = fill))

  stacked <- base + ggplot2::geom_col(position = "stack")
  dodged <- base + ggplot2::geom_col(position = "dodge")
  simple <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) + ggplot2::geom_col()

  testthat::expect_equal(
    adapter$detect_layer_type(stacked$layers[[1]], stacked), "stacked_bar"
  )
  testthat::expect_equal(
    adapter$detect_layer_type(dodged$layers[[1]], dodged), "dodged_bar"
  )
  testthat::expect_equal(
    adapter$detect_layer_type(simple$layers[[1]], simple), "bar"
  )
})

test_that("a polar histogram is still a histogram", {
  skip_if_no_ggplot2()

  # StatBin is checked before the coordinate system, so geom_histogram() in
  # polar coordinates keeps its previous behaviour.
  adapter <- maidr:::Ggplot2Adapter$new()
  p <- ggplot2::ggplot(data.frame(x = c(1, 2, 3, 4, 5, 6)), ggplot2::aes(x = x)) +
    ggplot2::geom_histogram(bins = 3) +
    ggplot2::coord_polar("y")

  testthat::expect_equal(adapter$detect_layer_type(p$layers[[1]], p), "hist")
})

test_that("is_pie_coord() is NULL-safe", {
  skip_if_no_ggplot2()

  adapter <- maidr:::Ggplot2Adapter$new()

  testthat::expect_false(adapter$is_pie_coord(NULL))
  testthat::expect_equal(adapter$detect_layer_type(NULL, NULL), "unknown")
})

test_that("the ggplot2 processor factory serves a pie processor", {
  skip_if_no_ggplot2()

  factory <- maidr:::Ggplot2ProcessorFactory$new()

  testthat::expect_true("pie" %in% factory$get_supported_types())
  testthat::expect_s3_class(
    factory$create_processor("pie", list(index = 1)),
    "Ggplot2PieLayerProcessor"
  )
})

# ==============================================================================
# Tier 4: Pie-Specific Logic
# ==============================================================================

test_that("Ggplot2PieLayerProcessor measures the wedge, not the stacked total", {
  skip_if_no_ggplot2()

  # PositionStack makes the built `y` cumulative, so the last wedge would
  # report the whole pie if the stacked value were used instead of the
  # segment's own ymax - ymin extent.
  processor <- maidr:::Ggplot2PieLayerProcessor$new(list(index = 1))
  data <- processor$extract_data(fruit_pie())

  testthat::expect_equal(sum(wedge_values(data)), 100)
  testthat::expect_true(all(wedge_values(data) < 100))
})

test_that("Ggplot2PieLayerProcessor counts wedges for a stat = 'count' pie", {
  skip_if_no_ggplot2()

  df <- data.frame(g = c("a", "a", "b", "c", "c", "c"))
  p <- ggplot2::ggplot(df, ggplot2::aes(x = "", fill = g)) +
    ggplot2::geom_bar() +
    ggplot2::coord_polar("y")

  processor <- maidr:::Ggplot2PieLayerProcessor$new(list(index = 1))
  data <- processor$extract_data(p)

  testthat::expect_equal(wedge_labels(data), c("a", "b", "c"))
  testthat::expect_equal(wedge_values(data), c(2, 1, 3))
})

test_that("Ggplot2PieLayerProcessor names wedges from an expression mapping", {
  skip_if_no_ggplot2()

  # aes(fill = factor(cyl)) has no column to read back, so the labels have to
  # come off the scale rather than out of the original data frame.
  df <- data.frame(cyl = c(4, 6, 8), mpg = c(30, 20, 15))
  p <- ggplot2::ggplot(df, ggplot2::aes(x = "", y = mpg, fill = factor(cyl))) +
    ggplot2::geom_col() +
    ggplot2::coord_polar("y")

  processor <- maidr:::Ggplot2PieLayerProcessor$new(list(index = 1))
  data <- processor$extract_data(p)

  testthat::expect_equal(wedge_labels(data), c("4", "6", "8"))
})

test_that("Ggplot2PieLayerProcessor respects reordered factor levels", {
  skip_if_no_ggplot2()

  df <- data.frame(
    fruit = factor(
      c("Apples", "Bananas", "Cherries"),
      levels = c("Cherries", "Apples", "Bananas")
    ),
    units = c(30, 50, 20)
  )
  p <- ggplot2::ggplot(df, ggplot2::aes(x = "", y = units, fill = fruit)) +
    ggplot2::geom_col() +
    ggplot2::coord_polar("y")

  processor <- maidr:::Ggplot2PieLayerProcessor$new(list(index = 1))
  data <- processor$extract_data(p)

  # Group ids follow the factor's own level order, and each label must stay
  # with its own magnitude.
  testthat::expect_equal(
    wedge_values(data)[match(c("Apples", "Bananas", "Cherries"), wedge_labels(data))],
    c(30, 50, 20)
  )
})

test_that("Ggplot2PieLayerProcessor keeps labels aligned in a partial facet", {
  skip_if_no_ggplot2()

  # Panel 2 draws only the third category. Indexing the scale labels by
  # POSITION among the ids present would name that wedge "Apples".
  df <- data.frame(
    fruit = c("Apples", "Bananas", "Cherries"),
    units = c(10, 20, 30),
    region = c("N", "N", "S")
  )
  p <- ggplot2::ggplot(df, ggplot2::aes(x = "", y = units, fill = fruit)) +
    ggplot2::geom_col() +
    ggplot2::coord_polar("y") +
    ggplot2::facet_wrap(~region)

  processor <- maidr:::Ggplot2PieLayerProcessor$new(list(index = 1))
  built <- ggplot2::ggplot_build(p)

  testthat::expect_equal(
    wedge_labels(processor$extract_data(p, built, panel_id = 1)),
    c("Apples", "Bananas")
  )
  testthat::expect_equal(
    wedge_labels(processor$extract_data(p, built, panel_id = 2)),
    "Cherries"
  )
})

test_that("Ggplot2PieLayerProcessor axes name the slice aesthetic and its measure", {
  skip_if_no_ggplot2()

  p <- fruit_pie(fill = "Fruit", y = "Units")
  processor <- maidr:::Ggplot2PieLayerProcessor$new(list(index = 1))

  axes <- processor$extract_pie_axes(
    p,
    list(axes = list(x = "", y = "Units")),
    ggplot2::ggplot_build(p)
  )

  testthat::expect_named(axes, c("x", "y"))
  testthat::expect_equal(axes$x$label, "Fruit")
  testthat::expect_equal(axes$y$label, "Units")
})

test_that("Ggplot2PieLayerProcessor takes a stat-derived y label from the layout", {
  skip_if_no_ggplot2()

  df <- data.frame(g = c("a", "a", "b"))
  p <- ggplot2::ggplot(df, ggplot2::aes(x = "", fill = g)) +
    ggplot2::geom_bar() +
    ggplot2::coord_polar("y")

  processor <- maidr:::Ggplot2PieLayerProcessor$new(list(index = 1))
  axes <- processor$extract_pie_axes(
    p,
    list(axes = list(x = "", y = "count")),
    ggplot2::ggplot_build(p)
  )

  testthat::expect_equal(axes$x$label, "g")
  testthat::expect_equal(axes$y$label, "count")
})

test_that("Ggplot2PieLayerProcessor selects the polygon grob, not the rect grob", {
  skip_if_no_ggplot2()

  # In polar coordinates the whole layer is one polygonGrob whose sub-polygons
  # are grouped by id; the geom_rect.rect.<N> the cartesian bar layers look
  # for is never drawn.
  p <- fruit_pie()
  gt <- ggplot2::ggplot_gtable(ggplot2::ggplot_build(p))

  processor <- maidr:::Ggplot2PieLayerProcessor$new(list(index = 1))
  selectors <- processor$generate_selectors(p, gt)

  testthat::expect_length(selectors, 1L)
  testthat::expect_match(selectors[[1]], "^#geom_rect\\\\\\.polygon\\\\\\.[0-9]+\\\\\\.1 polygon$")
})

test_that("Ggplot2PieLayerProcessor scopes its selector to a facet panel", {
  skip_if_no_ggplot2()

  df <- data.frame(
    fruit = rep(c("Apples", "Bananas"), 2),
    units = c(30, 50, 10, 15),
    region = rep(c("N", "S"), each = 2)
  )
  p <- ggplot2::ggplot(df, ggplot2::aes(x = "", y = units, fill = fruit)) +
    ggplot2::geom_col() +
    ggplot2::coord_polar("y") +
    ggplot2::facet_wrap(~region)
  gt <- ggplot2::ggplot_gtable(ggplot2::ggplot_build(p))

  processor <- maidr:::Ggplot2PieLayerProcessor$new(list(index = 1))
  panels <- grep("^panel-", gt$layout$name, value = TRUE)
  testthat::expect_length(panels, 2L)

  selectors <- vapply(
    panels,
    function(name) {
      found <- processor$generate_selectors(
        p, gt,
        panel_ctx = list(panel_name = name, layer_index = 1)
      )
      testthat::expect_length(found, 1L)
      found[[1]]
    },
    character(1)
  )

  # Each panel owns its own polygon grob.
  testthat::expect_length(unique(selectors), 2L)
})

# ==============================================================================
# Tier 5: End-to-end payload
# ==============================================================================

test_that("a rendered ggplot2 pie carries the flat wire format", {
  skip_if_no_ggplot2()
  testthat::skip_if_not_installed("jsonlite")
  testthat::skip_if_not_installed("xml2")

  p <- fruit_pie(title = "Fruit sales", fill = "Fruit", y = "Units")

  file <- tempfile(fileext = ".html")
  on.exit(unlink(file), add = TRUE)
  suppressWarnings(save_html(p, file))

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
  testthat::expect_equal(wedge_labels(layer$data), c("Apples", "Bananas", "Cherries"))
  testthat::expect_equal(wedge_values(layer$data), c(30, 50, 20))

  # The single selector must resolve to exactly one element per slice.
  testthat::expect_length(layer$selectors, 1L)
  id <- gsub("\\\\", "", sub(" polygon$", "", sub("^#", "", layer$selectors[[1]])))
  doc <- xml2::read_html(file)
  nodes <- xml2::xml_find_all(
    doc,
    sprintf("//*[@id='%s']//*[local-name()='polygon']", id)
  )
  testthat::expect_length(nodes, 3L)
})
