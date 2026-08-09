# Regression tests for the panel-scoped unsupported-overlay fallback.
#
# One segments()/arrows()/rect()/polygon() call used to turn an entire
# multi-panel figure into a static image, so an annotation in one panel
# cost every other panel its sonification, braille and keyboard
# navigation. The fallback is now scoped to the panel that owns the
# unsupported call; the whole-figure fallback survives only where there
# is no panel to scope to.

# Read every maidr-data payload back out of a rendered HTML file.
read_maidr_payloads <- function(file) {
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

# Draw `plot_fun`, render it, and hand back the payloads plus every
# warning the render emitted.
render_base_r_figure <- function(plot_fun) {
  maidr:::clear_all_device_storage()
  file <- tempfile(fileext = ".html")
  on.exit(
    {
      unlink(file)
      maidr:::clear_all_device_storage()
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

  list(payloads = read_maidr_payloads(file), warnings = warnings_seen)
}

# Point layers serialize as a list of {x, y} objects; pull them back into
# plain vectors so a test can assert the values a panel actually carries.
panel_xy <- function(payload, row, col, layer = 1) {
  points <- payload$subplots[[row]][[col]]$layers[[layer]]$data
  list(
    x = vapply(points, function(p) as.numeric(p$x), numeric(1)),
    y = vapply(points, function(p) as.numeric(p$y), numeric(1))
  )
}

panel_layer_count <- function(payload, row, col) {
  length(payload$subplots[[row]][[col]]$layers)
}

# ==============================================================================
# Scenario 1: a single-panel figure still falls back as a whole
# ==============================================================================

test_that("a single panel with segments() still falls back to a static image", {
  result <- render_base_r_figure(function() {
    plot(1:5, c(2, 4, 6, 8, 10))
    segments(1, 1, 5, 5)
  })

  testthat::expect_length(result$payloads, 0)
  testthat::expect_true(any(grepl(
    "Rendering as static image", result$warnings,
    fixed = TRUE
  )))
})

# ==============================================================================
# Scenario 2: one overlay takes down one panel, not the grid
# ==============================================================================

test_that("arrows() in one mfrow panel leaves the other panels interactive", {
  result <- render_base_r_figure(function() {
    par(mfrow = c(2, 2))
    plot(1:5, c(1, 2, 3, 4, 5))
    plot(1:5, c(10, 20, 30, 40, 50))
    arrows(1, 10, 3, 30)
    plot(1:5, c(5, 4, 3, 2, 1))
    plot(1:5, c(2, 2, 2, 2, 2))
    par(mfrow = c(1, 1))
  })

  testthat::expect_length(result$payloads, 1)
  payload <- result$payloads[[1]]

  testthat::expect_length(payload$subplots, 2)
  testthat::expect_length(payload$subplots[[1]], 2)

  # The three unaffected panels keep their own values.
  panel_1 <- panel_xy(payload, 1, 1)
  testthat::expect_equal(panel_1$x, c(1, 2, 3, 4, 5))
  testthat::expect_equal(panel_1$y, c(1, 2, 3, 4, 5))

  panel_3 <- panel_xy(payload, 2, 1)
  testthat::expect_equal(panel_3$x, c(1, 2, 3, 4, 5))
  testthat::expect_equal(panel_3$y, c(5, 4, 3, 2, 1))

  panel_4 <- panel_xy(payload, 2, 2)
  testthat::expect_equal(panel_4$x, c(1, 2, 3, 4, 5))
  testthat::expect_equal(panel_4$y, c(2, 2, 2, 2, 2))

  # The annotated panel carries no data, and none of the dropped panel's
  # values leak into a neighbour.
  testthat::expect_equal(panel_layer_count(payload, 1, 2), 0)
  testthat::expect_false(any(vapply(
    list(panel_1, panel_3, panel_4),
    function(panel) any(panel$y == 20),
    logical(1)
  )))

  # The empty cell is still a well-formed subplot, not a bare NULL.
  testthat::expect_equal(payload$subplots[[1]][[2]]$id, "maidr-subplot-1-2")
  testthat::expect_type(payload$subplots[[1]][[2]]$layers, "list")

  testthat::expect_true(any(grepl(
    "Panel 2 contains unsupported elements", result$warnings,
    fixed = TRUE
  )))
  testthat::expect_false(any(grepl(
    "Rendering as static image", result$warnings,
    fixed = TRUE
  )))
})

# ==============================================================================
# Scenario 3: when every panel is affected there is nothing left to keep
# ==============================================================================

test_that("overlays in every panel fall back as a whole figure", {
  result <- render_base_r_figure(function() {
    par(mfrow = c(1, 2))
    plot(1:5, c(1, 2, 3, 4, 5))
    segments(1, 1, 5, 5)
    plot(1:5, c(10, 20, 30, 40, 50))
    arrows(1, 10, 3, 30)
    par(mfrow = c(1, 1))
  })

  testthat::expect_length(result$payloads, 0)
  testthat::expect_true(any(grepl(
    "Rendering as static image", result$warnings,
    fixed = TRUE
  )))
})

# ==============================================================================
# Scenario 4: supported decorations are untouched
# ==============================================================================

test_that("abline() and legend() still render without any fallback", {
  result <- render_base_r_figure(function() {
    plot(1:5, c(2, 4, 6, 8, 10))
    abline(h = 2)
    legend("topleft", "a")
  })

  testthat::expect_length(result$payloads, 1)
  payload <- result$payloads[[1]]

  testthat::expect_length(payload$subplots, 1)
  testthat::expect_equal(panel_layer_count(payload, 1, 1), 2)

  points <- panel_xy(payload, 1, 1)
  testthat::expect_equal(points$x, c(1, 2, 3, 4, 5))
  testthat::expect_equal(points$y, c(2, 4, 6, 8, 10))

  testthat::expect_length(result$warnings, 0)
})

# ==============================================================================
# Scenario 5: layout() grids scope the same way mfrow grids do
# ==============================================================================

test_that("rect() in one layout() cell leaves the other cells interactive", {
  result <- render_base_r_figure(function() {
    layout(matrix(c(1, 2, 3, 4), nrow = 2, byrow = TRUE))
    plot(1:5, c(1, 2, 3, 4, 5))
    plot(1:5, c(10, 20, 30, 40, 50))
    rect(1, 10, 2, 20)
    plot(1:5, c(5, 4, 3, 2, 1))
    plot(1:5, c(2, 2, 2, 2, 2))
    layout(matrix(1))
  })

  testthat::expect_length(result$payloads, 1)
  payload <- result$payloads[[1]]

  testthat::expect_equal(panel_xy(payload, 1, 1)$y, c(1, 2, 3, 4, 5))
  testthat::expect_equal(panel_layer_count(payload, 1, 2), 0)
  testthat::expect_equal(panel_xy(payload, 2, 1)$y, c(5, 4, 3, 2, 1))
  testthat::expect_equal(panel_xy(payload, 2, 2)$y, c(2, 2, 2, 2, 2))

  testthat::expect_true(any(grepl(
    "Panel 2 contains unsupported elements", result$warnings,
    fixed = TRUE
  )))
})

# ==============================================================================
# A single-panel figure with no overlay is untouched by any of this
# ==============================================================================

test_that("a plain single-panel figure keeps its one payload", {
  result <- render_base_r_figure(function() {
    plot(1:5, c(2, 4, 6, 8, 10))
  })

  testthat::expect_length(result$payloads, 1)
  testthat::expect_length(result$warnings, 0)

  payload <- result$payloads[[1]]
  testthat::expect_length(payload$subplots, 1)
  testthat::expect_equal(panel_layer_count(payload, 1, 1), 1)
  testthat::expect_equal(panel_xy(payload, 1, 1)$y, c(2, 4, 6, 8, 10))
})

# ==============================================================================
# Orchestrator-level scope resolution
# ==============================================================================

build_orchestrator <- function(plot_fun) {
  maidr:::clear_all_device_storage()
  plot_fun()
  maidr:::BaseRPlotOrchestrator$new(device_id = grDevices::dev.cur())
}

test_that("orchestrator scopes an overlay to its own panel", {
  orchestrator <- build_orchestrator(function() {
    par(mfrow = c(2, 2))
    plot(1:5, 1:5)
    plot(1:5, 1:5)
    arrows(1, 1, 3, 3)
    plot(1:5, 1:5)
    plot(1:5, 1:5)
    par(mfrow = c(1, 1))
  })
  on.exit(maidr:::clear_all_device_storage(), add = TRUE)

  testthat::expect_true(orchestrator$has_unsupported_layers())
  testthat::expect_equal(orchestrator$unsupported_group_indices(), 2L)
  testthat::expect_equal(orchestrator$fallback_panels(), 2L)
  testthat::expect_false(orchestrator$should_fallback())
  testthat::expect_true(orchestrator$is_group_scoped_out(2))
  testthat::expect_false(orchestrator$is_group_scoped_out(1))
})

test_that("orchestrator keeps the whole-figure fallback for a single panel", {
  orchestrator <- build_orchestrator(function() {
    plot(1:5, 1:5)
    segments(1, 1, 5, 5)
  })
  on.exit(maidr:::clear_all_device_storage(), add = TRUE)

  testthat::expect_true(orchestrator$has_unsupported_layers())
  testthat::expect_true(orchestrator$should_fallback())
  testthat::expect_length(orchestrator$fallback_panels(), 0)
  testthat::expect_false(orchestrator$is_group_scoped_out(1))
})

test_that("orchestrator reports no fallback for a clean figure", {
  orchestrator <- build_orchestrator(function() {
    par(mfrow = c(1, 2))
    plot(1:5, 1:5)
    plot(1:5, 1:5)
    par(mfrow = c(1, 1))
  })
  on.exit(maidr:::clear_all_device_storage(), add = TRUE)

  testthat::expect_false(orchestrator$has_unsupported_layers())
  testthat::expect_false(orchestrator$should_fallback())
  testthat::expect_length(orchestrator$fallback_panels(), 0)
})

test_that("an unsupported HIGH-level plot falls back as a whole figure", {
  # An unsupported HIGH-level call is not an annotation over a readable
  # chart: the panel's whole content is unknown, and its grobs are not known
  # to survive the SVG export. The figure keeps the whole-figure fallback so
  # it renders as a correct image rather than failing mid-export.
  #
  # mosaicplot() is classified HIGH and has no layer type, so it reaches this
  # branch. pie() used to stand in here and no longer can: it is supported.
  orchestrator <- build_orchestrator(function() {
    par(mfrow = c(1, 2))
    plot(1:5, 1:5)
    mosaicplot(matrix(c(10, 20, 30, 40), nrow = 2))
    par(mfrow = c(1, 1))
  })
  on.exit(maidr:::clear_all_device_storage(), add = TRUE)

  testthat::expect_true(orchestrator$has_unsupported_layers())
  testthat::expect_true(orchestrator$should_fallback())
  testthat::expect_length(orchestrator$fallback_panels(), 0)
})

test_that("an overlay drawn before the layout call falls back as a whole", {
  # The group has no slot in the exported grid, so there is no panel to
  # scope the fallback to.
  orchestrator <- build_orchestrator(function() {
    plot(1:5, 1:5)
    segments(1, 1, 5, 5)
    par(mfrow = c(1, 2))
    plot(1:5, 1:5)
    plot(1:5, 1:5)
    par(mfrow = c(1, 1))
  })
  on.exit(maidr:::clear_all_device_storage(), add = TRUE)

  testthat::expect_true(orchestrator$should_fallback())
  testthat::expect_length(orchestrator$fallback_panels(), 0)
})

test_that("disabling fallback keeps every panel's data", {
  previous <- maidr::maidr_get_fallback()
  on.exit(
    {
      maidr::maidr_set_fallback(
        enabled = previous$enabled,
        format = previous$format,
        warning = previous$warning
      )
      maidr:::clear_all_device_storage()
    },
    add = TRUE
  )
  maidr::maidr_set_fallback(enabled = FALSE)

  orchestrator <- build_orchestrator(function() {
    par(mfrow = c(1, 2))
    plot(1:5, 1:5)
    plot(1:5, 1:5)
    arrows(1, 1, 3, 3)
    par(mfrow = c(1, 1))
  })

  testthat::expect_false(orchestrator$should_fallback())
  testthat::expect_length(orchestrator$fallback_panels(), 0)
  testthat::expect_false(orchestrator$is_group_scoped_out(2))
})

# ==============================================================================
# Warning wording
# ==============================================================================

test_that("the panel fallback warning names the affected panels", {
  one <- maidr:::format_panel_fallback_warning(2L)
  testthat::expect_match(one, "^Panel 2 contains unsupported elements\\.")
  testthat::expect_match(one, "the other panels remain interactive", fixed = TRUE)

  many <- maidr:::format_panel_fallback_warning(c(4L, 2L, 2L))
  testthat::expect_match(many, "^Panels 2, 4 contain unsupported elements\\.")
})

# ==============================================================================
# Non-Base R orchestrators
# ==============================================================================

test_that("a ggplot2 orchestrator passes through the panel warning untouched", {
  # warn_panel_fallback() runs on every render, not just Base R ones, and only
  # the Base R orchestrator defines fallback_panels(). The guard is written as
  # a member probe because an R6 object is an environment, so reading a member
  # its class does not define yields NULL rather than erroring -- pinned here
  # because the whole ggplot2 path would break if that ever stopped holding.
  testthat::skip_if_not_installed("ggplot2")

  plot <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) + ggplot2::geom_point()
  orchestrator <- maidr:::Ggplot2PlotOrchestrator$new(plot)

  testthat::expect_null(orchestrator$fallback_panels)
  testthat::expect_silent(maidr:::warn_panel_fallback(orchestrator))
})
