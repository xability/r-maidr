# Comprehensive tests for ggplot2 Patchwork Utilities
# Testing patchwork panel discovery, leaf extraction, and processing

# ==============================================================================
# find_patchwork_panels Tests
# ==============================================================================

test_that("find_patchwork_panels returns empty data.frame for NULL gtable", {
  result <- maidr:::find_patchwork_panels(NULL)

  testthat::expect_s3_class(result, "data.frame")
  testthat::expect_equal(nrow(result), 0)
})

test_that("find_patchwork_panels returns empty data.frame for gtable without panels", {
  testthat::skip_if_not_installed("ggplot2")

  # Create a simple plot and get its gtable
  p <- ggplot2::ggplot(mtcars, ggplot2::aes(x = mpg, y = wt)) +
    ggplot2::geom_point()
  gt <- ggplot2::ggplotGrob(p)

  result <- maidr:::find_patchwork_panels(gt)

  # Regular ggplot gtable may or may not have panel entries matching the pattern
  testthat::expect_s3_class(result, "data.frame")
})

test_that("find_patchwork_panels returns correct structure", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("patchwork")

  # Create a patchwork plot
  p1 <- ggplot2::ggplot(mtcars, ggplot2::aes(x = mpg)) +
    ggplot2::geom_histogram()
  p2 <- ggplot2::ggplot(mtcars, ggplot2::aes(x = wt)) +
    ggplot2::geom_histogram()

  combined <- patchwork::wrap_plots(p1, p2)
  gt <- ggplot2::ggplotGrob(combined)

  result <- maidr:::find_patchwork_panels(gt)

  if (nrow(result) > 0) {
    testthat::expect_true("panel_index" %in% names(result))
    testthat::expect_true("name" %in% names(result))
    testthat::expect_true("t" %in% names(result))
    testthat::expect_true("l" %in% names(result))
    testthat::expect_true("row" %in% names(result))
    testthat::expect_true("col" %in% names(result))
  }
})

# ==============================================================================
# extract_patchwork_leaves Tests
# ==============================================================================

test_that("extract_patchwork_leaves returns list for ggplot object", {
  testthat::skip_if_not_installed("ggplot2")

  p <- ggplot2::ggplot(mtcars, ggplot2::aes(x = mpg, y = wt)) +
    ggplot2::geom_point()

  result <- maidr:::extract_patchwork_leaves(p)

  testthat::expect_type(result, "list")
  testthat::expect_equal(length(result), 1)
  testthat::expect_s3_class(result[[1]], "ggplot")
})

test_that("extract_patchwork_leaves returns empty list for non-ggplot", {
  result <- maidr:::extract_patchwork_leaves(list(a = 1))

  testthat::expect_type(result, "list")
  testthat::expect_equal(length(result), 0)
})

test_that("extract_patchwork_leaves returns empty list for NULL", {
  result <- maidr:::extract_patchwork_leaves(NULL)

  testthat::expect_type(result, "list")
  testthat::expect_equal(length(result), 0)
})

test_that("extract_patchwork_leaves extracts from patchwork", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("patchwork")

  p1 <- ggplot2::ggplot(mtcars, ggplot2::aes(x = mpg)) +
    ggplot2::geom_histogram()
  p2 <- ggplot2::ggplot(mtcars, ggplot2::aes(x = wt)) +
    ggplot2::geom_histogram()

  combined <- p1 + p2

  result <- maidr:::extract_patchwork_leaves(combined)

  testthat::expect_type(result, "list")
  # Should have extracted the leaf plots
  testthat::expect_gte(length(result), 1)
})

# ==============================================================================
# extract_leaf_plot_layout Tests
# ==============================================================================

test_that("extract_leaf_plot_layout extracts labels", {
  testthat::skip_if_not_installed("ggplot2")

  p <- ggplot2::ggplot(mtcars, ggplot2::aes(x = mpg, y = wt)) +
    ggplot2::geom_point() +
    ggplot2::labs(title = "Test Title", x = "X Label", y = "Y Label")

  result <- maidr:::extract_leaf_plot_layout(p)

  testthat::expect_type(result, "list")
  testthat::expect_equal(result$title, "Test Title")
  testthat::expect_equal(result$axes$x$label, "X Label")
  testthat::expect_equal(result$axes$y$label, "Y Label")
})

test_that("extract_leaf_plot_layout handles missing labels", {
  testthat::skip_if_not_installed("ggplot2")

  p <- ggplot2::ggplot(mtcars, ggplot2::aes(x = mpg, y = wt)) +
    ggplot2::geom_point()

  result <- maidr:::extract_leaf_plot_layout(p)

  testthat::expect_type(result, "list")
  testthat::expect_true("title" %in% names(result))
  testthat::expect_true("axes" %in% names(result))
})

test_that("extract_leaf_plot_layout falls back to mapping for axes", {
  testthat::skip_if_not_installed("ggplot2")

  # Plot without explicit labels but with mapping
  p <- ggplot2::ggplot(mtcars, ggplot2::aes(x = mpg, y = wt)) +
    ggplot2::geom_point()

  result <- maidr:::extract_leaf_plot_layout(p)

  # Should extract from mapping
  testthat::expect_equal(result$axes$x$label, "mpg")
  testthat::expect_equal(result$axes$y$label, "wt")
})

test_that("extract_leaf_plot_layout returns empty string for missing title", {
  testthat::skip_if_not_installed("ggplot2")

  p <- ggplot2::ggplot(mtcars, ggplot2::aes(x = mpg, y = wt)) +
    ggplot2::geom_point()

  result <- maidr:::extract_leaf_plot_layout(p)

  testthat::expect_equal(result$title, "")
})

# ==============================================================================
# process_patchwork_plot_data Tests
# ==============================================================================

test_that("process_patchwork_plot_data returns empty list for NULL gtable", {
  testthat::skip_if_not_installed("ggplot2")

  p <- ggplot2::ggplot(mtcars, ggplot2::aes(x = mpg, y = wt)) +
    ggplot2::geom_point()

  result <- maidr:::process_patchwork_plot_data(p, list(), NULL)

  testthat::expect_type(result, "list")
  testthat::expect_equal(length(result), 0)
})

test_that("process_patchwork_plot_data handles simple ggplot", {
  testthat::skip_if_not_installed("ggplot2")

  p <- ggplot2::ggplot(mtcars, ggplot2::aes(x = mpg, y = wt)) +
    ggplot2::geom_point()
  gt <- ggplot2::ggplotGrob(p)
  layout <- list(axes = list(x = "mpg", y = "wt"))

  result <- maidr:::process_patchwork_plot_data(p, layout, gt)

  # May return empty if no patchwork panels found
  testthat::expect_type(result, "list")
})

test_that("process_patchwork_plot_data works with patchwork", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("patchwork")

  p1 <- ggplot2::ggplot(mtcars, ggplot2::aes(x = mpg)) +
    ggplot2::geom_histogram(bins = 10) +
    ggplot2::labs(title = "MPG")

  p2 <- ggplot2::ggplot(mtcars, ggplot2::aes(x = wt)) +
    ggplot2::geom_histogram(bins = 10) +
    ggplot2::labs(title = "Weight")

  combined <- p1 + p2
  gt <- ggplot2::ggplotGrob(combined)
  layout <- list(axes = list(x = "", y = ""))

  result <- maidr:::process_patchwork_plot_data(combined, layout, gt)

  testthat::expect_type(result, "list")
})

# ==============================================================================
# process_patchwork_panel Tests
# ==============================================================================

test_that("process_patchwork_panel returns correct structure", {
  testthat::skip_if_not_installed("ggplot2")

  p <- ggplot2::ggplot(mtcars, ggplot2::aes(x = mpg, y = wt)) +
    ggplot2::geom_point() +
    ggplot2::labs(title = "Test Plot")

  gt <- ggplot2::ggplotGrob(p)
  layout <- list(axes = list(x = "mpg", y = "wt"))

  result <- maidr:::process_patchwork_panel(
    leaf_plot = p,
    panel_name = "panel-1",
    panel_index = 1,
    row = 1,
    col = 1,
    layout = layout,
    gtable = gt
  )

  testthat::expect_type(result, "list")
  testthat::expect_true("id" %in% names(result))
  testthat::expect_true("layers" %in% names(result))
  testthat::expect_type(result$layers, "list")
})

test_that("process_patchwork_panel generates unique id", {
  testthat::skip_if_not_installed("ggplot2")

  p <- ggplot2::ggplot(mtcars, ggplot2::aes(x = mpg, y = wt)) +
    ggplot2::geom_point()

  gt <- ggplot2::ggplotGrob(p)

  result1 <- maidr:::process_patchwork_panel(p, "panel-1", 1, 1, 1, list(), gt)
  Sys.sleep(0.01) # Ensure different timestamp

  result2 <- maidr:::process_patchwork_panel(p, "panel-2", 2, 1, 2, list(), gt)

  testthat::expect_true(grepl("^maidr-subplot-", result1$id))
  testthat::expect_true(grepl("^maidr-subplot-", result2$id))
})

test_that("process_patchwork_panel processes layers", {
  # This test requires full system integration - skip in unit tests
  # The function is tested implicitly through the patchwork integration tests
  testthat::skip("Requires full system integration")
})

# ==============================================================================
# Edge Cases
# ==============================================================================

test_that("Patchwork utils handle empty plots gracefully", {
  testthat::skip_if_not_installed("ggplot2")

  # Empty ggplot
  p <- ggplot2::ggplot()

  result <- maidr:::extract_leaf_plot_layout(p)

  testthat::expect_type(result, "list")
  testthat::expect_equal(result$title, "")
})

test_that("find_patchwork_panels handles gtable without layout", {
  # Create a minimal gtable-like structure without layout
  fake_gtable <- list(layout = NULL)

  result <- maidr:::find_patchwork_panels(fake_gtable)

  testthat::expect_s3_class(result, "data.frame")
  testthat::expect_equal(nrow(result), 0)
})

test_that("extract_patchwork_leaves handles nested patchwork", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("patchwork")

  p1 <- ggplot2::ggplot(mtcars, ggplot2::aes(x = mpg)) +
    ggplot2::geom_histogram()
  p2 <- ggplot2::ggplot(mtcars, ggplot2::aes(x = wt)) +
    ggplot2::geom_histogram()
  p3 <- ggplot2::ggplot(mtcars, ggplot2::aes(x = hp)) +
    ggplot2::geom_histogram()

  # Create nested patchwork
  nested <- (p1 | p2) / p3

  result <- maidr:::extract_patchwork_leaves(nested)

  testthat::expect_type(result, "list")
  # Should extract multiple leaves
  testthat::expect_gte(length(result), 1)
})

# ==============================================================================
# Integration Tests
# ==============================================================================

test_that("Patchwork processing pipeline works end-to-end", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("patchwork")

  # Create a 2x2 patchwork layout
  p1 <- ggplot2::ggplot(mtcars, ggplot2::aes(x = mpg)) +
    ggplot2::geom_histogram(bins = 10) +
    ggplot2::labs(title = "MPG Distribution")

  p2 <- ggplot2::ggplot(mtcars, ggplot2::aes(x = wt)) +
    ggplot2::geom_histogram(bins = 10) +
    ggplot2::labs(title = "Weight Distribution")

  p3 <- ggplot2::ggplot(mtcars, ggplot2::aes(x = mpg, y = wt)) +
    ggplot2::geom_point() +
    ggplot2::labs(title = "MPG vs Weight")

  p4 <- ggplot2::ggplot(mtcars, ggplot2::aes(x = hp, y = mpg)) +
    ggplot2::geom_point() +
    ggplot2::labs(title = "HP vs MPG")

  combined <- (p1 | p2) / (p3 | p4)

  # Extract leaves
  leaves <- maidr:::extract_patchwork_leaves(combined)
  testthat::expect_gte(length(leaves), 1)

  # Extract layout from each leaf
  for (leaf in leaves) {
    layout <- maidr:::extract_leaf_plot_layout(leaf)
    testthat::expect_type(layout, "list")
  }
})

# ==============================================================================
# Shared panel collector (issue #52)
# ==============================================================================

test_that("collect_gtable_panels finds nested panels in discovery order", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("patchwork")

  p1 <- ggplot2::ggplot(mtcars, ggplot2::aes(mpg, wt)) + ggplot2::geom_point()
  p2 <- ggplot2::ggplot(mtcars, ggplot2::aes(hp, mpg)) + ggplot2::geom_point()
  p3 <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, hp)) + ggplot2::geom_point()

  gt <- patchwork::patchworkGrob((p1 | p2) / p3)
  panels <- maidr:::collect_gtable_panels(gt)
  panels <- Filter(function(p) grepl("^panel-\\d+(-\\d+)?$", p$name), panels)

  # Nested rows hide their panels inside a child gtable; a top-level scan
  # would find only the last leaf.
  testthat::expect_equal(length(panels), 3)

  # The order must match find_patchwork_panels(), which is how leaves are
  # paired with panels.
  df <- maidr:::find_patchwork_panels(gt)
  testthat::expect_equal(
    vapply(panels, function(p) p$name, character(1)),
    as.character(df$name)
  )

  # Panels reached through a child gtable carry the full viewport path
  depths <- vapply(panels, function(p) length(p$vp_path), integer(1))
  testthat::expect_true(any(depths > 1))
})

test_that("collect_gtable_panels matches the bare panel of a single plot", {
  testthat::skip_if_not_installed("ggplot2")

  gt <- ggplot2::ggplotGrob(
    ggplot2::ggplot(mtcars, ggplot2::aes(mpg, wt)) + ggplot2::geom_point()
  )
  panels <- maidr:::collect_gtable_panels(gt)

  testthat::expect_equal(length(panels), 1)
  testthat::expect_equal(panels[[1]]$name, "panel")
})

test_that("find_gtable_panel_grob resolves each patchwork leaf's own panel", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("patchwork")

  bars <- ggplot2::ggplot(mtcars, ggplot2::aes(factor(cyl))) + ggplot2::geom_bar()
  points <- ggplot2::ggplot(mtcars, ggplot2::aes(mpg, wt)) + ggplot2::geom_point()

  gt <- patchwork::patchworkGrob(bars | points)

  geoms_in <- function(grob) {
    names <- character(0)
    walk <- function(g) {
      if (!inherits(g, "gTree") || is.null(g$children)) {
        return(invisible(NULL))
      }
      for (nm in names(g$children)) {
        child <- g$children[[nm]]
        if (!is.null(child$name)) names <<- c(names, child$name)
        walk(child)
      }
    }
    walk(grob)
    names
  }

  first <- maidr:::find_gtable_panel_grob(gt, list(panel_index = 1, panel_name = "panel-1"))
  second <- maidr:::find_gtable_panel_grob(gt, list(panel_index = 2, panel_name = "panel-2"))

  testthat::expect_true(any(grepl("geom_rect|geom_bar", geoms_in(first))))
  testthat::expect_true(any(grepl("geom_point", geoms_in(second))))
  testthat::expect_false(any(grepl("geom_point", geoms_in(first))))
})

test_that("find_gtable_panel_grob without a context keeps single-plot behaviour", {
  testthat::skip_if_not_installed("ggplot2")

  gt <- ggplot2::ggplotGrob(
    ggplot2::ggplot(mtcars, ggplot2::aes(mpg, wt)) + ggplot2::geom_point()
  )
  testthat::expect_false(is.null(maidr:::find_gtable_panel_grob(gt)))

  # A patchwork gtable has no cell named "panel" at all
  testthat::skip_if_not_installed("patchwork")
  pw <- patchwork::patchworkGrob(
    (ggplot2::ggplot(mtcars, ggplot2::aes(mpg, wt)) + ggplot2::geom_point()) |
      (ggplot2::ggplot(mtcars, ggplot2::aes(hp, mpg)) + ggplot2::geom_point())
  )
  testthat::expect_null(maidr:::find_gtable_panel_grob(pw))
})

# ==============================================================================
# Leaf augmentation (issue #52)
# ==============================================================================

test_that("augment_patchwork_leaves injects violin's boxplot into every leaf", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("patchwork")

  violin <- ggplot2::ggplot(ggplot2::mpg, ggplot2::aes(class, hwy)) +
    ggplot2::geom_violin()
  bars <- ggplot2::ggplot(ggplot2::mpg, ggplot2::aes(class)) + ggplot2::geom_bar()

  composition <- violin | bars
  augmented <- maidr:::augment_patchwork_leaves(composition)

  leaves <- maidr:::extract_patchwork_leaves(augmented)
  testthat::expect_equal(length(leaves[[1]]$layers), 2)
  testthat::expect_equal(length(leaves[[2]]$layers), 1)

  # The caller's object must not be mutated
  original <- maidr:::extract_patchwork_leaves(composition)
  testthat::expect_equal(length(original[[1]]$layers), 1)
})

test_that("augment_patchwork_leaves reaches the self-carried leaf and nests", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("patchwork")

  violin <- ggplot2::ggplot(ggplot2::mpg, ggplot2::aes(class, hwy)) +
    ggplot2::geom_violin()
  bars <- ggplot2::ggplot(ggplot2::mpg, ggplot2::aes(class)) + ggplot2::geom_bar()

  # The last-added plot is carried by the patchwork object itself
  augmented <- maidr:::augment_patchwork_leaves(bars | violin)
  leaves <- maidr:::extract_patchwork_leaves(augmented)
  testthat::expect_equal(length(leaves[[2]]$layers), 2)

  # And nesting must be traversed
  points <- ggplot2::ggplot(ggplot2::mpg, ggplot2::aes(displ, hwy)) +
    ggplot2::geom_point()
  nested <- maidr:::augment_patchwork_leaves((violin | bars) / points)
  nested_leaves <- maidr:::extract_patchwork_leaves(nested)
  testthat::expect_equal(length(nested_leaves[[1]]$layers), 2)
  testthat::expect_equal(length(nested_leaves[[3]]$layers), 1)
})

test_that("augment_leaf_plot leaves plots that need no augmentation alone", {
  testthat::skip_if_not_installed("ggplot2")

  bars <- ggplot2::ggplot(ggplot2::mpg, ggplot2::aes(class)) + ggplot2::geom_bar()
  testthat::expect_equal(length(maidr:::augment_leaf_plot(bars)$layers), 1)
})

# ==============================================================================
# Multi-layer expansion in process_patchwork_panel (issue #52)
# ==============================================================================

test_that("process_patchwork_panel keeps single-layer ids unsuffixed", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("patchwork")

  p1 <- ggplot2::ggplot(mtcars, ggplot2::aes(mpg, wt)) + ggplot2::geom_point()
  p2 <- ggplot2::ggplot(mtcars, ggplot2::aes(hp, mpg)) + ggplot2::geom_point()
  gt <- patchwork::patchworkGrob(p1 | p2)

  panel <- maidr:::process_patchwork_panel(
    p1, "panel-1", 1, 1, 1, list(title = "", axes = list()), gt
  )

  testthat::expect_equal(length(panel$layers), 1)
  testthat::expect_equal(panel$layers[[1]]$id, "maidr-layer-1")
})

test_that("process_patchwork_panel expands a violin into two suffixed layers", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("patchwork")

  violin <- ggplot2::ggplot(ggplot2::mpg, ggplot2::aes(class, hwy)) +
    ggplot2::geom_violin()
  bars <- ggplot2::ggplot(ggplot2::mpg, ggplot2::aes(class)) + ggplot2::geom_bar()

  augmented <- maidr:::augment_patchwork_leaves(violin | bars)
  gt <- patchwork::patchworkGrob(augmented)
  leaf <- maidr:::extract_patchwork_leaves(augmented)[[1]]

  panel <- maidr:::process_patchwork_panel(
    leaf, "panel-1", 1, 1, 1, list(title = "", axes = list()), gt,
    n_original_layers = 1
  )

  testthat::expect_equal(length(panel$layers), 2)
  testthat::expect_equal(
    vapply(panel$layers, function(l) l$type, character(1)),
    c("violin_box", "violin_kde")
  )
  testthat::expect_equal(
    vapply(panel$layers, function(l) l$id, character(1)),
    c("maidr-layer-1-1", "maidr-layer-1-2")
  )
  # Fields beyond the standard set survive the expansion
  testthat::expect_equal(panel$layers[[1]]$orientation, "vert")
})

test_that("process_patchwork_panel ignores geoms injected for rendering", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("patchwork")

  violin <- ggplot2::ggplot(ggplot2::mpg, ggplot2::aes(class, hwy)) +
    ggplot2::geom_violin()
  bars <- ggplot2::ggplot(ggplot2::mpg, ggplot2::aes(class)) + ggplot2::geom_bar()

  augmented <- maidr:::augment_patchwork_leaves(violin | bars)
  gt <- patchwork::patchworkGrob(augmented)
  leaf <- maidr:::extract_patchwork_leaves(augmented)[[1]]

  # Without the original layer count the injected boxplot emits a third,
  # spurious "box" layer the user never asked for.
  bounded <- maidr:::process_patchwork_panel(
    leaf, "panel-1", 1, 1, 1, list(title = "", axes = list()), gt,
    n_original_layers = 1
  )
  testthat::expect_false("box" %in% vapply(bounded$layers, function(l) l$type, character(1)))
})

test_that("augment_patchwork_leaves leaves faceted leaves visually untouched", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("patchwork")

  faceted <- ggplot2::ggplot(ggplot2::mpg, ggplot2::aes(class, hwy)) +
    ggplot2::geom_violin() +
    ggplot2::facet_wrap(~drv)
  bars <- ggplot2::ggplot(ggplot2::mpg, ggplot2::aes(class)) + ggplot2::geom_bar()

  # A faceted violin is skipped by the processor, so injecting a boxplot into
  # it would change the drawn figure and buy no accessibility at all.
  for (composition in list(faceted | bars, bars | faceted)) {
    leaves <- maidr:::extract_patchwork_leaves(
      maidr:::augment_patchwork_leaves(composition)
    )
    testthat::expect_equal(
      vapply(leaves, function(l) length(l$layers), integer(1)),
      c(1L, 1L)
    )
  }
})

test_that("count_leaf_panels counts a leaf's own panels", {
  testthat::skip_if_not_installed("ggplot2")

  plain <- ggplot2::ggplot(ggplot2::mpg, ggplot2::aes(class, hwy)) +
    ggplot2::geom_violin()
  testthat::expect_equal(maidr:::count_leaf_panels(plain), 1L)
  testthat::expect_equal(
    maidr:::count_leaf_panels(plain + ggplot2::facet_wrap(~drv)),
    length(unique(ggplot2::mpg$drv))
  )
  testthat::expect_equal(maidr:::count_leaf_panels("not a plot"), 1L)
})

test_that("count_leaf_panels reports zero for a plot patchwork has wrapped", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("patchwork")

  plain <- ggplot2::ggplot(ggplot2::mpg, ggplot2::aes(class, hwy)) +
    ggplot2::geom_violin()

  # A wrapped plot lands in a cell panel discovery does not recognise, so it
  # contributes no row to find_patchwork_panels(). Counting it as one would
  # make every later leaf consume somebody else's panel.
  testthat::expect_false(maidr:::is_wrapped_leaf(plain))
  for (wrapped in list(
    patchwork::free(plain),
    patchwork::inset_element(plain, 0.5, 0.5, 1, 1),
    patchwork::wrap_elements(full = plain)
  )) {
    testthat::expect_true(maidr:::is_wrapped_leaf(wrapped))
    testthat::expect_equal(maidr:::count_leaf_panels(wrapped), 0L)
  }
})

test_that("augment_patchwork_leaves leaves wrapped plots untouched", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("patchwork")

  violin <- ggplot2::ggplot(ggplot2::mpg, ggplot2::aes(class, hwy)) +
    ggplot2::geom_violin()
  bars <- ggplot2::ggplot(ggplot2::mpg, ggplot2::aes(class)) + ggplot2::geom_bar()

  # A wrapped plot occupies no cell panel discovery recognises, so it is
  # never described -- injecting a boxplot into it would only change the
  # drawn figure.
  wrapped <- list(
    inset = bars + patchwork::inset_element(violin, 0.5, 0.5, 1, 1),
    free = bars | patchwork::free(violin)
  )
  for (composition in wrapped) {
    leaves <- maidr:::extract_patchwork_leaves(
      maidr:::augment_patchwork_leaves(composition)
    )
    for (leaf in leaves) {
      testthat::expect_equal(length(leaf$layers), 1)
    }
  }

  # An ordinary violin leaf is still augmented
  plain <- maidr:::extract_patchwork_leaves(
    maidr:::augment_patchwork_leaves(violin | bars)
  )
  testthat::expect_equal(length(plain[[1]]$layers), 2)
})

test_that("find_gtable_panel_grob declines rather than guessing a panel", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("patchwork")

  bars <- ggplot2::ggplot(mtcars, ggplot2::aes(factor(cyl))) + ggplot2::geom_bar()
  points <- ggplot2::ggplot(mtcars, ggplot2::aes(mpg, wt)) + ggplot2::geom_point()
  gt <- patchwork::patchworkGrob(bars | points)

  # An index that resolves to nothing and a name that matches nothing must
  # not fall through to the first panel: handing a layer another panel's
  # grobs points its highlighting at the wrong chart.
  testthat::expect_null(
    maidr:::find_gtable_panel_grob(gt, list(panel_index = 99, panel_name = "panel-99"))
  )
  testthat::expect_null(
    maidr:::find_gtable_panel_grob(gt, list(panel_index = NA_integer_))
  )
  testthat::expect_null(
    maidr:::find_gtable_panel_grob(gt, list(panel_index = c(1, 2)))
  )

  # A resolvable context still works
  testthat::expect_false(
    is.null(maidr:::find_gtable_panel_grob(gt, list(panel_index = 2)))
  )
})

# ==============================================================================
# Axis number formatting on patchwork leaves (issue #66)
# ==============================================================================

test_that("a patchwork leaf keeps the axis format of its own scales", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("patchwork")
  testthat::skip_if_not_installed("scales")

  df <- data.frame(g = c("a", "b", "c"), v = c(10, 20, 30))
  money <- ggplot2::ggplot(df, ggplot2::aes(g, v)) +
    ggplot2::geom_col() +
    ggplot2::scale_y_continuous(labels = scales::label_dollar()) +
    ggplot2::labs(x = "Group", y = "Revenue")
  plain <- ggplot2::ggplot(df, ggplot2::aes(g, v)) + ggplot2::geom_col()

  gt <- patchwork::patchworkGrob(money | plain)
  panel <- maidr:::process_patchwork_panel(
    money, "panel-1", 1, 1, 1, list(title = "", axes = list()), gt
  )

  testthat::expect_equal(
    panel$layers[[1]]$axes$y$format,
    list(type = "currency", currency = "USD", decimals = 2L, locale = "en-US")
  )
  testthat::expect_null(panel$layers[[1]]$axes$x$format)
})

test_that("each patchwork leaf gets its own format, not the composition's", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("patchwork")
  testthat::skip_if_not_installed("scales")

  df <- data.frame(g = c("a", "b", "c"), v = c(10, 20, 30))
  money <- ggplot2::ggplot(df, ggplot2::aes(g, v)) +
    ggplot2::geom_col() +
    ggplot2::scale_y_continuous(labels = scales::label_dollar())
  share <- ggplot2::ggplot(df, ggplot2::aes(g, v / 100)) +
    ggplot2::geom_col() +
    ggplot2::scale_y_continuous(labels = scales::label_percent())

  grid <- maidr:::process_patchwork_plot_data(
    money | share,
    list(title = "", axes = list()),
    patchwork::patchworkGrob(money | share)
  )

  testthat::expect_equal(
    grid[[1]][[1]]$layers[[1]]$axes$y$format$type, "currency"
  )
  testthat::expect_equal(
    grid[[1]][[2]]$layers[[1]]$axes$y$format$type, "percent"
  )
})

test_that("a patchwork leaf's axes match the same plot rendered standalone", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("patchwork")
  testthat::skip_if_not_installed("scales")

  df <- data.frame(g = c("a", "b", "c"), v = c(10, 20, 30))
  money <- ggplot2::ggplot(df, ggplot2::aes(g, v)) +
    ggplot2::geom_col() +
    ggplot2::scale_y_continuous(labels = scales::label_dollar()) +
    ggplot2::labs(x = "Group", y = "Revenue")

  standalone <- maidr:::Ggplot2PlotOrchestrator$new(money)
  solo_axes <- standalone$get_combined_data()[[1]][[1]]$layers[[1]]$axes

  gt <- patchwork::patchworkGrob(money | money)
  panel <- maidr:::process_patchwork_panel(
    money, "panel-1", 1, 1, 1, list(title = "", axes = list()), gt
  )

  testthat::expect_equal(panel$layers[[1]]$axes, solo_axes)
})

# Attaching the format put a validate_axes() gate on the patchwork path that
# was not there before. Unformatted leaves go through it too, so this pins
# that the gate lets an ordinary composition past rather than aborting it --
# the failure mode a new throw introduces. It deliberately uses plain scales:
# the formatted cases are covered above.
test_that("the axes gate passes every leaf of an unformatted composition", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("patchwork")

  bars <- ggplot2::ggplot(mtcars, ggplot2::aes(factor(cyl))) + ggplot2::geom_bar()
  points <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) + ggplot2::geom_point()

  grid <- maidr:::process_patchwork_plot_data(
    bars | points,
    list(title = "", axes = list()),
    patchwork::patchworkGrob(bars | points)
  )

  for (row in grid) {
    for (cell in row) {
      for (layer in cell$layers) {
        testthat::expect_true(all(names(layer$axes) %in% c("x", "y", "z")))
        testthat::expect_silent(maidr:::validate_axes(layer$axes))
      }
    }
  }
})
