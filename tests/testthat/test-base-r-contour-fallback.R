# A base R call must never ship a type the factory cannot dispatch (#214)
#
# `base_r_adapter` mapped `contour()` to the type "contour" and the processor
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
#
# #214 fixed that by typing the call "unknown" so it degraded to a picture.
# #218 replaced the picture with the reading, and `test-base-r-contour.R`
# covers what a contour now announces.
#
# What is left here is the part that outlived both: the rule they were two
# answers to. A call is either dispatchable or it falls back, and "unknown"
# on `layer$type` is the only thing that reaches the fallback. `dotchart`
# stands for the unclaimed side and is unchanged; the contour cases assert
# the claimed side now reads rather than that it degrades.

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

  # The heart of it, and the assertion that survives both fixes unchanged.
  # "unknown" is not a trace type, and a payload carrying one makes the whole
  # figure fail to construct -- whether the call is read or handed back.
  expect_false("unknown" %in% result$types)
})

test_that("it is read rather than turned into a picture", {
  skip_unless_jsonlite()

  # The inversion of what this test asserted under #214, kept in place rather
  # than deleted so the two behaviours are visibly one story: the call used to
  # degrade to an image, and now it reads. `test-base-r-contour.R` covers what
  # it announces; what matters here is that the fallback no longer fires for a
  # type the factory can dispatch.
  result <- render_base_figure(function() contour(matrix(1:12, nrow = 3)))

  expect_equal(result$types, "contour")
  expect_false(result$fell_back)
  expect_false(result$warned)
})

test_that("it takes the same path an unclaimed call takes", {
  skip_unless_jsonlite()

  # A call with no processor and nothing claiming it has one degrades
  # correctly. Asserted beside the contour so the two cannot drift.
  #
  # Which call plays the part lives in `helper.R`, because it keeps moving:
  # `dotchart` stood here until #242 gave it a processor, then `mosaicplot`
  # until #242's remainder gave it one. The subject is a *recorded call with
  # no processor*, not any particular function.
  result <- render_base_figure(draw_unread_base_r_chart)

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

test_that("the factory claims contour only because it can dispatch it", {
  # The other half of the contradiction #214 found: `get_supported_types()`
  # listed "contour" while `create_processor()` handed it the generic
  # processor. Both are true again now, together -- which is the invariant,
  # not the individual answers.
  factory <- BaseRProcessorFactory$new()

  expect_true("contour" %in% factory$get_supported_types())
  expect_s3_class(
    factory$create_processor("contour", list(index = 1)),
    "BaseRContourLayerProcessor"
  )
  expect_true("heat" %in% factory$get_supported_types())
})
