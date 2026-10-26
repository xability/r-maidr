# `stars()` drew a set of radars that nothing read (#262)
#
# It is recorded -- `save_html()` succeeds rather than reporting "No Base R
# plots detected", which #262 fixed -- but `detect_layer_type()` had no branch
# for it, so it fell through to `unknown` and the chart came out as a static
# image with "Plot contains unsupported elements".
#
# What it draws is a multi-line layer around a circle: one closed outline per
# observation, one spoke per variable. MAIDR's `radar` trace is navigated as
# "each spoke a column and each series a row", so the reading is the recorded
# matrix turned on its side -- `stars()` draws a glyph per *row* while
# `extract_multiline_data()` wants series in *columns*.
#
# The part worth asserting is the values. `stars()` scales every column to
# [0, 1] before drawing, so the radii on the page are shares of each column's
# range rather than the readings themselves. A reading that took them off the
# drawing would tell a reader that an observation scores zero on a variable it
# merely has the smallest value of.

stars_layers <- base_r_layers

#' The values of one series, keyed by the spoke they sit on
series_of <- function(layer, index) {
  points <- layer$data[[index]]
  stats::setNames(
    vapply(points, function(point) point$y, numeric(1)),
    vapply(points, function(point) point$x, character(1))
  )
}

#' What each series is announced as
names_of <- function(layer) {
  vapply(layer$data, function(series) series[[1]]$z, character(1))
}

#' Four observations of three variables, each value naming its own place
READINGS <- matrix(
  c(1, 2, 3, 4, 5, 6, 7, 8, 9, 2, 4, 6),
  nrow = 4, byrow = TRUE,
  dimnames = list(c("r1", "r2", "r3", "r4"), c("a", "b", "c"))
)


test_that("a star plot reads as a radar rather than as nothing", {
  # The reproduction: before this, no layer at all, so the figure fell back
  # to a picture.
  layers <- stars_layers(function() stars(READINGS))

  testthat::expect_length(layers, 1)
  testthat::expect_equal(layers[[1]]$type, "radar")
})


test_that("the call routes to the processor that turns the matrix", {
  # The name the adapter types it as and the name the factory answers to have
  # to be the same string, and the registry has to list it (#200, #214).
  adapter <- BaseRAdapter$new()

  testthat::expect_equal(
    adapter$detect_layer_type(list(function_name = "stars", args = list())),
    "radar"
  )

  factory <- BaseRProcessorFactory$new()
  testthat::expect_true("radar" %in% factory$get_supported_types())
  testthat::expect_s3_class(
    factory$create_processor("radar", list(plot_call = list(args = list()))),
    "BaseRStarsLayerProcessor"
  )
})


test_that("an observation is a series and a variable is a spoke", {
  # The transpose, asserted from both sides: four series of three points, not
  # three series of four. Getting it the other way round produces a chart
  # that is still navigable and describes the wrong thing entirely.
  layer <- stars_layers(function() stars(READINGS))[[1]]

  testthat::expect_length(layer$data, 4)
  testthat::expect_length(layer$data[[1]], 3)
  testthat::expect_equal(series_of(layer, 1), c(a = 1, b = 2, c = 3))
  testthat::expect_equal(series_of(layer, 3), c(a = 7, b = 8, c = 9))
})


test_that("the readings are the caller's, not the scaled radii", {
  # `stars()` maps each column onto [0, 1] to draw it, so column `c` -- 3, 6,
  # 9, 6 -- is drawn at 0, 0.5, 1, 0.5. Announcing those would lose the units
  # and tell a reader r1 scores nothing on `c`.
  layer <- stars_layers(function() stars(READINGS))[[1]]

  testthat::expect_equal(
    vapply(seq_along(layer$data), function(i) series_of(layer, i)[["c"]], numeric(1)),
    c(3, 6, 9, 6)
  )
})


test_that("each outline is announced by the row it was drawn for", {
  # `stars()` labels a glyph with `dimnames(x)[[1L]]`, and a radar's series
  # name is how a reader tells the outlines apart.
  layer <- stars_layers(function() stars(READINGS))[[1]]

  testthat::expect_equal(names_of(layer), c("r1", "r2", "r3", "r4"))
})


test_that("an unnamed matrix is announced by position rather than not at all", {
  # There is nothing else a series could be called, and leaving them unnamed
  # would make the outlines indistinguishable.
  layer <- stars_layers(function() {
    stars(matrix(c(1, 2, 3, 4), nrow = 2))
  })[[1]]

  testthat::expect_equal(names_of(layer), c("1", "2"))
  testthat::expect_equal(
    names(series_of(layer, 1)),
    c("var 1", "var 2")
  )
})


test_that("a data frame is read the way stars() coerces one", {
  # `stars()` calls `as.matrix()` on it, so a data frame of numbers is the
  # same chart written differently.
  layer <- stars_layers(function() {
    stars(data.frame(a = c(1, 3), b = c(2, 4), row.names = c("p", "q")))
  })[[1]]

  testthat::expect_equal(names_of(layer), c("p", "q"))
  testthat::expect_equal(series_of(layer, 2), c(a = 3, b = 4))
})


test_that("a single observation never reaches the reading at all", {
  # Recorded because it looks like a case worth handling and is not:
  # `stars()` indexes its scaled matrix as `s.y[i, ]`, which drops to a
  # vector on one row, and R stops with "incorrect number of dimensions"
  # before anything is drawn. So a one-row matrix is not a chart the reading
  # can be asked about, and no guard here is needed for it.
  testthat::expect_error(
    stars(matrix(c(1, 2, 3), nrow = 1, dimnames = list("only", c("a", "b", "c")))),
    "incorrect number of dimensions"
  )
})


test_that("two observations are read, which is the smallest star plot there is", {
  layer <- stars_layers(function() {
    stars(matrix(c(1, 2, 3, 4, 5, 6), nrow = 2, byrow = TRUE,
                 dimnames = list(c("p", "q"), c("a", "b", "c"))))
  })[[1]]

  testthat::expect_length(layer$data, 2)
  testthat::expect_equal(series_of(layer, 1), c(a = 1, b = 2, c = 3))
  testthat::expect_equal(series_of(layer, 2), c(a = 4, b = 5, c = 6))
})


test_that("each star is outlined through the polygon it is drawn as", {
  # Measured by colour, a star owns two polygons and a segments grob, and
  # the export writes each polygon with the spoke tips as its vertices. The
  # second of the two, drawn with the star's border, is each series' mark.
  layer <- stars_layers(function() stars(READINGS))[[1]]

  testthat::expect_length(layer$selectors, nrow(READINGS))
  testthat::expect_equal(
    unlist(layer$selectors),
    paste0("#graphics-plot-1-polygon-", 2 * seq_len(nrow(READINGS)), "\\.1 polygon")
  )
})


test_that("each named polygon is drawn through its star's spoke tips", {
  testthat::skip_if_not_installed("xml2")
  skip_if_no_render()
  grDevices::pdf(NULL)
  device_id <- grDevices::dev.cur()
  clear_base_r_device(device_id)
  file <- tempfile(fileext = ".html")
  on.exit(
    {
      clear_base_r_device(device_id)
      if (device_id %in% grDevices::dev.list()) grDevices::dev.off(device_id)
      unlink(file)
    },
    add = TRUE
  )
  stars(READINGS)
  suppressWarnings(suppressMessages(save_html(file = file)))
  layer <- layers_from(paste(readLines(file, warn = FALSE), collapse = "\n"))[[1]]
  doc <- xml2::read_html(file)

  testthat::expect_length(layer$selectors, nrow(READINGS))
  for (selector in layer$selectors) {
    id <- sub(" polygon$", "", sub("^#", "", gsub("\\", "", selector, fixed = TRUE)))
    polygon <- xml2::xml_find_first(doc, sprintf("//*[@id='%s']/*[local-name()='polygon']", id))
    testthat::expect_false(inherits(polygon, "xml_missing"), label = id)
    points <- strsplit(trimws(xml2::xml_attr(polygon, "points")), " +")[[1]]
    testthat::expect_length(points, ncol(READINGS))
  }
})


test_that("a star plot of sectors is read without an outline", {
  # `draw.segments = TRUE` draws a sector per variable rather than the star's
  # polygon, so there is no one mark per series to name.
  #
  # `NULL` rather than an empty list: the orchestrator drops a NULL field,
  # while `list()` would serialise as an empty `selectors` array and claim
  # the chart has marks that resolve to nothing.
  layer <- stars_layers(function() stars(READINGS, draw.segments = TRUE))[[1]]

  testthat::expect_null(layer$selectors)
})


test_that("a non-numeric matrix is declined rather than coerced", {
  # `as.matrix()` on it produces characters, and `as.numeric` would announce
  # a grid of `NA`s that was never drawn.
  result <- BaseRStarsLayerProcessor$new(NULL)$process(
    NULL, NULL,
    layer_info = list(
      plot_call = list(args = list(matrix(c("a", "b", "c", "d"), nrow = 2)))
    )
  )

  testthat::expect_null(result)
})
