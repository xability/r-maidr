# Base R contour() shipped a layer the core refuses (#214)
#
# `base_r_adapter` mapped the call to the type "contour" and the processor
# factory had no processor for it, so the generic one ran and the layer was
# emitted typed **"unknown"**. Two things then compounded:
#
#   - `unsupported_layer_flags()` looks for "unknown" on `layer$type`, and the
#     type here was "contour", so the static-image fallback never ran; and
#   - the core's trace factory ends its dispatch with
#     `throw new Error("Invalid trace type: " + layer.type)`.
#
# So the figure rendered interactively and then failed to construct: an
# interactive-looking shell that answers no key, and no picture either.
# Measured before the fix, `contour(matrix(1:12, nrow = 3))` gave
# `types=[unknown]` with no fallback warning, while `dotchart()` -- unclaimed
# by anything -- correctly gave a static image.
#
# Typed "unknown" at the adapter it takes that same path. Worse than reading
# the chart and better than a figure that never binds. Reading it properly is
# still open: `contour` *is* a trace type, the ggplot2 adapter emits it for
# `geom_contour()` (#198), and base R hands over the same x, y, z and levels.

skip_unless_jsonlite <- function() {
  testthat::skip_if_not_installed("jsonlite")
}

# Every maidr-data payload in a rendered file.
contour_payloads <- function(file) {
  html <- paste(readLines(file, warn = FALSE), collapse = "\n")
  matches <- regmatches(html, gregexpr('maidr-data="[^"]*"', html))[[1]]
  lapply(matches, function(match) {
    raw <- sub('"$', "", sub('^maidr-data="', "", match))
    raw <- gsub("&quot;", '"', raw, fixed = TRUE)
    raw <- gsub("&lt;", "<", raw, fixed = TRUE)
    raw <- gsub("&gt;", ">", raw, fixed = TRUE)
    raw <- gsub("&amp;", "&", raw, fixed = TRUE)
    jsonlite::fromJSON(raw, simplifyVector = FALSE)
  })
}

# Draw on an off-screen device, render as a user would, report what arrived.
render_base_figure <- function(plot_fun) {
  clear_all_device_storage()
  file <- tempfile(fileext = ".html")
  grDevices::pdf(NULL)
  on.exit(
    {
      grDevices::dev.off()
      unlink(file)
      clear_all_device_storage()
    },
    add = TRUE
  )

  warnings_seen <- character(0)
  withCallingHandlers(
    {
      plot_fun()
      maidr::save_html(plot = NULL, file = file)
    },
    warning = function(w) {
      warnings_seen <<- c(warnings_seen, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )

  html <- paste(readLines(file, warn = FALSE), collapse = "\n")
  types <- unlist(lapply(contour_payloads(file), function(payload) {
    lapply(payload$subplots, function(row) {
      lapply(row, function(cell) {
        vapply(cell$layers, function(layer) as.character(layer$type), character(1))
      })
    })
  }))

  list(
    types = if (is.null(types)) character(0) else as.character(types),
    fell_back = grepl("base64", html, fixed = TRUE),
    warned = any(grepl("unsupported elements", warnings_seen, fixed = TRUE))
  )
}


test_that("a base R contour never emits a layer the core would refuse", {
  skip_unless_jsonlite()

  result <- render_base_figure(function() contour(matrix(1:12, nrow = 3)))

  # The heart of it. "unknown" is not a trace type, and a payload carrying one
  # makes the whole figure fail to construct.
  expect_false("unknown" %in% result$types)
})

test_that("it falls back to a picture, and says so", {
  skip_unless_jsonlite()

  result <- render_base_figure(function() contour(matrix(1:12, nrow = 3)))

  expect_true(result$fell_back)
  expect_true(result$warned)
})

test_that("it takes the same path an unclaimed call takes", {
  skip_unless_jsonlite()

  # `dotchart` has no processor and nothing claims it does, so it has always
  # degraded correctly. Asserted beside the contour so the two cannot drift.
  result <- render_base_figure(function() dotchart(c(3, 7, 5)))

  expect_true(result$fell_back)
  expect_true(result$warned)
})

test_that("the charts beside it still read", {
  skip_unless_jsonlite()

  # The change is one line of the adapter's type map, so this pins that it did
  # not reach the neighbouring entries -- `image` and `plot` sit either side.
  expect_equal(
    render_base_figure(function() image(matrix(1:12, nrow = 3)))$types,
    "heat"
  )
  expect_equal(
    render_base_figure(function() plot(1:10, (1:10)^2))$types,
    "point"
  )
})

test_that("the factory no longer claims contour among its supported types", {
  # The other half of the contradiction: `get_supported_types()` listed
  # "contour" while `create_processor()` handed it the generic processor.
  factory <- BaseRProcessorFactory$new()

  expect_false("contour" %in% factory$get_supported_types())
  expect_true("heat" %in% factory$get_supported_types())
})
