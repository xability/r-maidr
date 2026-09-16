# `fourfoldplot()` fell back to a picture even when its quadrants were the
# table (#268).
#
# A fourfold display draws one quarter-circle per cell of a 2x2 table. What
# the radii mean depends on the caller's `std`, and the two halves are not
# alike:
#
#   std = "ind.max" / "all.max"  the wedge AREA is the count. Measured on
#                                c(tab) = 10, 40, 90, 160 the radii are
#                                0.25, 0.50, 0.75, 1.00 and r^2 * max(count)
#                                recovers every count exactly.
#   std = "margins" (the DEFAULT) the four radii are
#                                sqrt(c(u, 1-u, 1-u, u)) with
#                                u = sqrt(or) / (1 + sqrt(or)) -- one number,
#                                the odds ratio, drawn four times. Measured,
#                                a table and the same table times three draw
#                                bit-identical wedges.
#
# So the reading is conditional on an argument, the shape the `qqplot` branch
# has, and read the other way round: `qqplot` takes silence as accept, and
# here silence is the decline. Everything upstream that the runtime cannot
# check -- the default, the standardisation, the grob inventory -- is asserted
# against a LIVE drawing below rather than assumed.

two_by_two <- function() {
  as.table(matrix(
    c(10, 40, 90, 160),
    nrow = 2,
    dimnames = list(
      Treatment = c("Drug", "Placebo"),
      Outcome = c("Cured", "Not")
    )
  ))
}

layer_info_for <- function(table, extra = list(), index = 1) {
  list(
    plot_call = list(
      args = c(list(table), extra),
      fname = "fourfoldplot"
    ),
    function_name = "fourfoldplot",
    group_index = index,
    index = index
  )
}

plot_call_for <- function(table, extra = list()) {
  list(function_name = "fourfoldplot", args = c(list(table), extra))
}

# The grob tree of a real drawing, through the same call the orchestrator
# makes. `graphics::fourfoldplot` qualified on purpose: a qualified call does
# not go through the search-path patch, so the drawing records nothing and
# cannot disturb a device the test suite is also using.
drawn <- function(expr) {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  ggplotify::as.grob(expr)
}

polygon_grobs <- function(gt) {
  find_graphics_plot_grobs(gt, "polygon", 1)
}

# The outermost radius of a polygon grob, in the user coordinates the frame
# pins to +/-1.
grob_radius <- function(gt, name) {
  g <- grid::getGrob(gt, name)
  max(sqrt(as.numeric(g$x)^2 + as.numeric(g$y)^2))
}

wedge_radii <- function(expr) {
  gt <- drawn(expr)
  vapply(polygon_grobs(gt)[1:4], function(n) grob_radius(gt, n), numeric(1))
}

drawn_labels <- function(expr) {
  gt <- drawn(expr)
  vapply(
    find_graphics_plot_grobs(gt, "text", 1),
    function(n) paste(as.character(grid::getGrob(gt, n)$label), collapse = " | "),
    character(1)
  )
}

relative_spread <- function(radii, counts) {
  keep <- counts > 0
  ratio <- radii[keep] / sqrt(counts[keep])
  max(abs(ratio - mean(ratio))) / mean(ratio)
}

# Both halves of the one-shot advisory: the session env AND rlang's own
# `.frequency = "once"` cache. Resetting only the first leaves the warning
# suppressed for the rest of the session -- the trap
# `test-adapters.R`'s chartSeries test records. Needed regardless of file
# order, because `test-base-r-unrecorded-calls.R` draws a default-`std`
# `fourfoldplot()` and consumes the "std" shot on the way past.
reset_fourfold_advisory <- function() {
  env <- get(".maidr_fourfoldplot_declined", envir = asNamespace("maidr"))
  env$reasons <- character(0)
  for (reason in c("std", "strata", "table")) {
    rlang::reset_warning_verbosity(paste0("maidr_fourfoldplot_declined_", reason))
  }
}


# ------------------------------------------------------------------------------
# What the runtime cannot check: the upstream assumptions, asserted live
# ------------------------------------------------------------------------------

test_that("fourfoldplot's own `std` default is still `margins`", {
  # The branch reads the caller's SILENCE as a decline, which is sound only
  # while this holds. The `qqplot` precedent's answer to the same exposure:
  # assert it here, so a changed upstream default fails loudly rather than
  # silently turning every plain `fourfoldplot()` into a reading of numbers it
  # does not draw.
  choices <- eval(formals(graphics::fourfoldplot)$std)
  expect_equal(choices, c("margins", "ind.max", "all.max"))
  expect_equal(match.arg(NULL, choices), "margins")
  # And the literal the adapter carries instead of eval()ing that call on
  # every dispatch is the same list.
  expect_equal(FOURFOLD_STD_CHOICES, choices)
})

test_that("`std = ind.max` still draws radii proportional to sqrt(count)", {
  # `r / sqrt(count) == 1 / sqrt(max(tab))` is an identity inside `stdize()`
  # today (`y <- tab / max(tab)`), so no input can falsify it and neither can
  # the runtime check. It is asserted against a LIVE drawing so that a release
  # changing the standardisation fails here instead.
  skip_if_not_installed("ggplotify")
  counts <- as.numeric(two_by_two())

  for (std in c("ind.max", "all.max")) {
    radii <- wedge_radii(local({
      s <- std
      function() graphics::fourfoldplot(two_by_two(), std = s)
    }))

    expect_length(radii, 4L)
    expect_equal(unname(radii), c(0.25, 0.5, 0.75, 1))
    expect_lt(relative_spread(radii, counts), 1e-12)
    # The count back out of the drawing, exactly.
    expect_equal(unname(radii^2 * max(counts)), counts)
  }
})

test_that("the default draws the odds ratio, four times, and not the counts", {
  # Measured: r = sqrt(c(u, 1 - u, 1 - u, u)), u = sqrt(or) / (1 + sqrt(or)),
  # so r1 == r4 and r2 == r3 -- four radii carrying one number.
  skip_if_not_installed("ggplotify")
  tab <- two_by_two()
  odds_ratio <- (tab[1, 1] * tab[2, 2]) / (tab[1, 2] * tab[2, 1])
  u <- sqrt(odds_ratio) / (1 + sqrt(odds_ratio))

  radii <- wedge_radii(function() graphics::fourfoldplot(two_by_two()))

  expect_equal(unname(radii), sqrt(c(u, 1 - u, 1 - u, u)))
  # Same odds ratio, triple the counts, bit-identical picture. This is the
  # whole of #268's argument in one assertion.
  tripled <- wedge_radii(function() {
    graphics::fourfoldplot(as.table(two_by_two() * 3))
  })
  expect_identical(unname(radii), unname(tripled))
})

test_that("a constant radius ratio does not by itself mean counts are drawn", {
  # The falsification the issue's own shape does not survive. For a symmetric
  # table the DEFAULT `std` gives u / a == (1 - u) / b, so `r / sqrt(count)`
  # is constant to 0 and a geometry-only gate would read a chart that draws an
  # odds ratio. That is why `std` is the first gate and the geometry only the
  # second, and why the second cannot be advertised as "the chart verifies
  # itself".
  skip_if_not_installed("ggplotify")
  symmetric <- as.table(matrix(
    c(9, 4, 4, 9),
    nrow = 2, dimnames = list(R = c("a", "b"), C = c("p", "q"))
  ))

  radii <- wedge_radii(function() graphics::fourfoldplot(symmetric))

  expect_equal(relative_spread(radii, as.numeric(symmetric)), 0)
  reset_fourfold_advisory()
  on.exit(reset_fourfold_advisory(), add = TRUE)
  expect_equal(
    suppressWarnings(
      BaseRAdapter$new()$detect_layer_type(plot_call_for(symmetric))
    ),
    "unknown"
  )
  # Off symmetry it recovers fast: 9, 4, 4, 9.0001 gives 2.778e-06.
  nudged <- as.table(matrix(
    c(9, 4, 4, 9.0001),
    nrow = 2, dimnames = list(R = c("a", "b"), C = c("p", "q"))
  ))
  spread <- relative_spread(
    wedge_radii(function() graphics::fourfoldplot(nudged)),
    as.numeric(nudged)
  )
  expect_gt(spread, 1e-8)
  expect_lt(spread, 1e-5)
})

test_that("the polygon inventory the wedge search relies on still holds", {
  # `wedge_names()` discriminates by polygon COUNT and VERTEX count, not by
  # fill. These are the numbers it trusts.
  skip_if_not_installed("ggplotify")
  tab <- two_by_two()

  with_arcs <- drawn(function() graphics::fourfoldplot(tab, std = "ind.max"))
  names_with <- polygon_grobs(with_arcs)
  vertices <- vapply(
    names_with, function(n) length(grid::getGrob(with_arcs, n)$x), integer(1)
  )
  # 4 wedges + 8 confidence arcs + 1 frame.
  expect_length(names_with, 13L)
  # Every quarter disc is drawPie(n = 500) plus the centre point.
  expect_true(all(vertices[1:12] == 501L))
  # The frame is the only 4-vertex polygon, and it is last.
  expect_equal(unname(which(vertices == 4L)), 13L)

  # `conf.level = 0` removes the arcs and nothing else; the wedges stay first.
  without <- drawn(function() {
    graphics::fourfoldplot(tab, std = "ind.max", conf.level = 0)
  })
  names_without <- polygon_grobs(without)
  expect_length(names_without, 5L)
  expect_equal(
    vapply(names_without, function(n) grob_radius(without, n), numeric(1))[1:4],
    vapply(names_with, function(n) grob_radius(with_arcs, n), numeric(1))[1:4]
  )
})

test_that("fourfoldplot has no xlab or ylab to read an axis title from", {
  # Why this processor hard-wires the dimension names instead of calling
  # `recorded_axis_label()` the way the assocplot processor does.
  formal_names <- names(formals(graphics::fourfoldplot))
  expect_false(any(c("xlab", "ylab", "...") %in% formal_names))
  expect_equal(
    formal_names,
    c(
      "x", "color", "conf.level", "std", "margin", "space", "main",
      "mfrow", "mfcol"
    )
  )
})


# ------------------------------------------------------------------------------
# Dispatch: match.arg semantics, positional arguments, the refusals
# ------------------------------------------------------------------------------

test_that("every spelling match.arg accepts for ind.max / all.max is read", {
  adapter <- BaseRAdapter$new()

  for (std in c("ind.max", "ind", "i", "in", "all.max", "all", "a")) {
    expect_equal(
      adapter$detect_layer_type(plot_call_for(two_by_two(), list(std = std))),
      "fourfold",
      info = std
    )
  }
  # `identical(args[["std"]], "ind.max")` would silently decline five of those
  # seven, and each of them is a legal call that draws the counts.
})

test_that("the default and every spelling of it is declined", {
  reset_fourfold_advisory()
  on.exit(reset_fourfold_advisory(), add = TRUE)
  adapter <- BaseRAdapter$new()

  spellings <- list(
    NULL, "margins", "m", "ma", c("margins", "ind.max", "all.max")
  )
  for (std in spellings) {
    args <- if (is.null(std)) list() else list(std = std)
    expect_equal(
      suppressWarnings(
        adapter$detect_layer_type(plot_call_for(two_by_two(), args))
      ),
      "unknown",
      info = paste(deparse(std), collapse = "")
    )
  }
})

test_that("a `std` match.arg would reject declines rather than stopping", {
  # A reader that `stop()`ed would take the whole figure with it. Every one of
  # these makes `fourfoldplot()` itself raise first, so none is reachable from
  # a drawn chart -- the `tryCatch` is insurance, and this pins its shape.
  reset_fourfold_advisory()
  on.exit(reset_fourfold_advisory(), add = TRUE)
  adapter <- BaseRAdapter$new()

  rejected <- list(
    "IND.MAX", "x", NA_character_, character(0),
    c("ind.max", "margins"), 1L, TRUE, quote(zz), factor("ind.max")
  )
  for (std in rejected) {
    expect_equal(
      suppressWarnings(
        adapter$detect_layer_type(
          plot_call_for(two_by_two(), list(std = std))
        )
      ),
      "unknown",
      info = paste(deparse(std), collapse = "")
    )
  }
  # `factor("ind.max")` is on that list for a reason: `as.character()` would
  # have accepted it, and `fourfoldplot(tab, std = factor("ind.max"))` stops
  # with "'arg' must be NULL or a character vector". A non-character `std` is
  # refused rather than coerced so the reading never accepts a call upstream
  # will not draw.
})

test_that("a positional `std` is seen, because match_recorded_args names it", {
  # `graphics::fourfoldplot` has no `UseMethod`, so `match.call()` names slots
  # 2-4 `color`, `conf.level`, `std`. Nothing here depends on the caller
  # having typed the name.
  positional <- list(function_name = "fourfoldplot", args = stats::setNames(
    list(two_by_two(), c("#99CCFF", "#6699CC"), 0.95, "all.max"),
    c("", "color", "conf.level", "std")
  ))

  expect_equal(BaseRAdapter$new()$detect_layer_type(positional), "fourfold")
})

test_that("a 2x2xk array is declined, k separated or not", {
  reset_fourfold_advisory()
  on.exit(reset_fourfold_advisory(), add = TRUE)
  adapter <- BaseRAdapter$new()

  # Explicit, not incidental: measured, all six panels of
  # `fourfoldplot(UCBAdmissions)` are named `graphics-plot-1-*` -- 78 polygon
  # grobs under one index -- so a per-panel reading would need window slicing
  # no helper here does, and under `ind.max` the radii are not comparable
  # between panels anyway.
  for (x in list(UCBAdmissions, array(c(10, 40, 90, 160), dim = c(2, 2, 1)))) {
    expect_equal(
      suppressWarnings(
        adapter$detect_layer_type(plot_call_for(x, list(std = "ind.max")))
      ),
      "unknown"
    )
  }
})

test_that("a degenerate table is declined", {
  reset_fourfold_advisory()
  on.exit(reset_fourfold_advisory(), add = TRUE)
  adapter <- BaseRAdapter$new()
  zeros <- as.table(matrix(
    0, 2, 2, dimnames = list(R = c("a", "b"), C = c("p", "q"))
  ))

  expect_equal(
    suppressWarnings(
      adapter$detect_layer_type(plot_call_for(zeros, list(std = "ind.max")))
    ),
    "unknown"
  )

  # Not a judgement call: `stdize()` returns NaN four times and the drawing
  # has no wedges at all to address.
  skip_if_not_installed("ggplotify")
  gt <- suppressWarnings(
    drawn(function() graphics::fourfoldplot(zeros, std = "ind.max"))
  )
  expect_length(polygon_grobs(gt), 0L)
})

test_that("a negative count reaches the gate and is declined there", {
  # The `all(counts >= 0)` clause is load-bearing, and the obvious reading of
  # it -- "fourfoldplot() stops on a negative count, so it never arrives" --
  # is the WRONG ANSWER, pinned here. That is true only under the DEFAULT
  # `std = "margins"`, which never gets past gate 1. Under the two `std`
  # values that DO reach gate 3 the call returns normally (a "NaNs produced"
  # warning, and no wedges on the page), so the count arrives finite and
  # summing to 8 and it is the non-negativity clause that declines it.
  reset_fourfold_advisory()
  on.exit(reset_fourfold_advisory(), add = TRUE)
  # A null device of our own: the probes below call `fourfoldplot()` for its
  # condition rather than its grobs, and an unopened device would leave an
  # Rplots.pdf behind.
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE, after = FALSE)
  negative <- as.table(matrix(
    c(-1, 2, 3, 4), nrow = 2, dimnames = list(R = c("a", "b"), C = c("p", "q"))
  ))

  # A collector and `suppressWarnings()` rather than `expect_warning()`: one
  # call emits several identical "NaNs produced" warnings -- measured, four
  # under `margins` before it errors and three under each of `ind.max` and
  # `all.max` -- and `expect_warning()` consumes only the first, leaving the
  # rest to surface as test warnings against a suite held at a fixed count.
  warnings_of <- function(expr) {
    seen <- character(0)
    withCallingHandlers(expr, warning = function(w) {
      seen <<- c(seen, conditionMessage(w))
      invokeRestart("muffleWarning")
    })
    seen
  }

  expect_error(
    suppressWarnings(graphics::fourfoldplot(negative)), "missing value"
  )
  for (std in c("ind.max", "all.max")) {
    expect_equal(
      unique(warnings_of(graphics::fourfoldplot(negative, std = std))),
      "NaNs produced"
    )
    expect_equal(
      fourfold_decline_reason(plot_call_for(negative, list(std = std))$args),
      "table"
    )
  }

  # `NA`, by contrast, really does stop under every `std` -- including the
  # two above -- so it never reaches the gate at all.
  missing <- as.table(matrix(
    c(NA, 2, 3, 4), nrow = 2, dimnames = list(R = c("a", "b"), C = c("p", "q"))
  ))
  for (std in c("margins", "ind.max", "all.max")) {
    expect_error(
      graphics::fourfoldplot(missing, std = std), "missing value"
    )
  }

  skip_if_not_installed("ggplotify")
  gt <- suppressWarnings(
    drawn(function() graphics::fourfoldplot(negative, std = "ind.max"))
  )
  expect_length(polygon_grobs(gt), 0L)
})

test_that("an unrepresentable ratio never reaches the geometry gate", {
  # `radii_agree()`'s roxygen leaves `c(1, 1e15, 1, 1)` out of its measured
  # headroom list, and the reason is not that the call errors -- it does not.
  # Under `ind.max` it returns with a "NaNs produced" warning and draws no
  # polygons at all, so `wedge_names()` refuses it on the polygon count
  # before the radii are ever compared.
  skip_if_not_installed("ggplotify")
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE, after = FALSE)
  wild <- as.table(matrix(
    c(1, 1e15, 1, 1), nrow = 2, dimnames = list(R = c("a", "b"), C = c("p", "q"))
  ))
  seen <- character(0)
  withCallingHandlers(
    graphics::fourfoldplot(wild, std = "ind.max"),
    warning = function(w) {
      seen <<- c(seen, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  expect_equal(unique(seen), "NaNs produced")

  gt <- suppressWarnings(
    drawn(function() graphics::fourfoldplot(wild, std = "ind.max"))
  )
  expect_length(polygon_grobs(gt), 0L)

  info <- layer_info_for(wild, list(std = "ind.max"))
  processor <- BaseRFourfoldLayerProcessor$new(info)
  expect_null(processor$wedge_names(gt, 1))
  expect_equal(processor$generate_selectors(info, gt), list())
})

test_that("a logical table is declined rather than announced as 1 and 0", {
  # The chart prints its cells with `as.character(c(tab))`, so a logical
  # matrix is labelled TRUE/FALSE on the page while `as.numeric()` would have
  # announced 1/0 under `z = "Count"`. `is.numeric()` in the gate rather than
  # a coercion.
  reset_fourfold_advisory()
  on.exit(reset_fourfold_advisory(), add = TRUE)
  logical_table <- as.table(matrix(
    c(TRUE, FALSE, TRUE, TRUE),
    nrow = 2, dimnames = list(R = c("a", "b"), C = c("p", "q"))
  ))

  expect_equal(
    suppressWarnings(
      BaseRAdapter$new()$detect_layer_type(
        plot_call_for(logical_table, list(std = "ind.max"))
      )
    ),
    "unknown"
  )

  skip_if_not_installed("ggplotify")
  labels <- drawn_labels(function() {
    graphics::fourfoldplot(logical_table, std = "ind.max")
  })
  expect_equal(
    unname(labels[["graphics-plot-1-text-5"]]),
    "TRUE | FALSE | TRUE | TRUE"
  )
})

test_that("an ftable is read, and the 2x2 gate is the test that was meant", {
  # Why the gate is spelled `length(dims) == 2L && all(dims == 2L)` rather
  # than `identical(dims, c(2L, 2L))`: `dim()` may carry the dimension names
  # and `identical()` compares them, so the exact-comparison spelling can
  # decline a table for a reason that has nothing to do with what the chart
  # draws. That is a property of `identical()` rather than of any one R
  # release, so it is asserted directly here and the gate is written not to
  # care either way.
  expect_false(identical(c(Treatment = 2L, Outcome = 2L), c(2L, 2L)))
  expect_true(all(c(Treatment = 2L, Outcome = 2L) == c(2L, 2L)))

  # Whether *this* constructor produces those names is an R-version detail
  # and is deliberately not asserted: measured, `dim(as.table(ftable(tb)))`
  # is `c(Treatment = 2L, Outcome = 2L)` on R 4.3.3 and unnamed on R 4.6.1,
  # which is what CI runs -- pinning it failed there on both the testthat
  # job and `R CMD check`. What the reading owes an author is the same under
  # both, so that is what is asserted: the gate admits the table, and the
  # call is read.
  dims <- dim(recorded_two_way_table(list(ftable(two_by_two()))))

  expect_true(length(dims) == 2L && all(dims == 2L))
  expect_equal(
    BaseRAdapter$new()$detect_layer_type(
      plot_call_for(ftable(two_by_two()), list(std = "ind.max"))
    ),
    "fourfold"
  )
})

test_that("a declined call says why, once per reason", {
  # The generic "Plot contains unsupported elements" is true and tells an
  # author nothing. This adds the sentence that would have saved them: the
  # same chart with `std = "ind.max"` is read.
  reset_fourfold_advisory()
  on.exit(reset_fourfold_advisory(), add = TRUE)
  adapter <- BaseRAdapter$new()

  expect_warning(
    typed <- adapter$detect_layer_type(plot_call_for(two_by_two())),
    class = "maidr_fourfoldplot_declined"
  )
  expect_equal(typed, "unknown")

  # Once, because `detect_layer_type()` is called up to five times for one
  # accepted layer and once per declined one.
  expect_silent(adapter$detect_layer_type(plot_call_for(two_by_two())))

  # A different refusal is a different explanation, and gets its own shot.
  expect_warning(
    adapter$detect_layer_type(
      plot_call_for(UCBAdmissions, list(std = "ind.max"))
    ),
    class = "maidr_fourfoldplot_declined"
  )

  # And it must not carry the substring the fallback's own warning is
  # recognised by, or `test-base-r-unrecorded-calls.R` would pass on it.
  message <- tryCatch(
    {
      reset_fourfold_advisory()
      warn_fourfoldplot_declined("std")
      ""
    },
    condition = function(w) paste(conditionMessage(w), collapse = " ")
  )
  expect_false(grepl("unsupported elements", message, fixed = TRUE))
  expect_true(grepl("std", message, fixed = TRUE))
})


# ------------------------------------------------------------------------------
# Extraction: the grid, its names, the axes, the title
# ------------------------------------------------------------------------------

test_that("the grid is the table, rows top to bottom and columns left to right", {
  info <- layer_info_for(two_by_two(), list(std = "ind.max"))

  data <- BaseRFourfoldLayerProcessor$new(info)$extract_data(info)

  expect_equal(data$points, list(list(10, 90), list(40, 160)))
  # Dimension 2 runs left to right, dimension 1 top to bottom -- the
  # TRANSPOSE of what `assocplot()` does with the same argument.
  expect_equal(unlist(data$x), c("Cured", "Not"))
  expect_equal(unlist(data$y), c("Drug", "Placebo"))
})

test_that("it is read as a heat layer rather than declined", {
  info <- layer_info_for(two_by_two(), list(std = "ind.max"))

  result <- BaseRFourfoldLayerProcessor$new(info)$process(
    NULL, NULL, layer_info = info
  )

  expect_equal(result$type, "heat")
  expect_equal(result$domMapping, list(order = "row"))
})

test_that("the axes name the dimensions the way the chart places them", {
  info <- layer_info_for(two_by_two(), list(std = "ind.max"))

  axes <- BaseRFourfoldLayerProcessor$new(info)$extract_axis_titles(info)

  expect_equal(axes$x$label, "Outcome")
  expect_equal(axes$y$label, "Treatment")
  # Not a dimension of the table: a reader told "Outcome" for the value would
  # be given a level name where a number is.
  expect_equal(axes$z$label, "Count")
})

test_that("the names are the ones fourfoldplot draws, not as.table()'s", {
  # The most serious thing this file pins. `recorded_two_way_table()` repairs
  # dimnames through `as.table()`; `fourfoldplot()` repairs them from
  # `dimnames(x)` as handed. For an `ftable` those disagree completely, and
  # reading the levels off `as.table()` would announce six strings -- Outcome,
  # Treatment, Cured, Not, Drug, Placebo -- that appear nowhere on a chart
  # labelled Row: A / Col: A / Row: B / Col: B. That is #268's own failure
  # displaced from the numbers onto the labels.
  skip_if_not_installed("ggplotify")
  handed <- ftable(two_by_two())
  info <- layer_info_for(handed, list(std = "ind.max"))
  processor <- BaseRFourfoldLayerProcessor$new(info)

  labels <- drawn_labels(function() {
    graphics::fourfoldplot(handed, std = "ind.max")
  })
  expect_equal(
    unname(labels[1:4]), c("Row: A", "Col: A", "Row: B", "Col: B")
  )

  data <- processor$extract_data(info)
  axes <- processor$extract_axis_titles(info)
  expect_equal(unlist(data$x), c("A", "B"))
  expect_equal(unlist(data$y), c("A", "B"))
  expect_equal(axes$x$label, "Col")
  expect_equal(axes$y$label, "Row")
  # The counts still come from the table, and they are right.
  expect_equal(data$points, list(list(10, 90), list(40, 160)))
})

test_that("an unnamed table falls back to the words fourfoldplot itself draws", {
  skip_if_not_installed("ggplotify")
  bare <- matrix(c(10, 5, 3, 12), nrow = 2)
  info <- layer_info_for(bare, list(std = "ind.max"))

  labels <- drawn_labels(function() {
    graphics::fourfoldplot(bare, std = "ind.max")
  })
  expect_equal(
    unname(labels[1:4]), c("Row: A", "Col: A", "Row: B", "Col: B")
  )

  axes <- BaseRFourfoldLayerProcessor$new(info)$extract_axis_titles(info)
  expect_equal(axes$x$label, "Col")
  expect_equal(axes$y$label, "Row")
})

test_that("a half-named dimnames gets a name the chart leaves blank", {
  # `fourfoldplot()`'s own repair is
  # `if (is.null(names(dnx))) i <- 1L:3L else i <- which(is.null(names(dnx)))`
  # and `which(is.null(...))` is ALWAYS integer(0), so a partially named
  # `dimnames` is never repaired. The wrong answer, pinned so it is read
  # rather than rediscovered: the chart literally draws ": hi" and ": lo".
  skip_if_not_installed("ggplotify")
  half <- as.table(matrix(
    c(1, 2, 3, 4), nrow = 2,
    dimnames = list(c("yes", "no"), c("hi", "lo"))
  ))
  names(dimnames(half)) <- c("Answer", "")
  info <- layer_info_for(half, list(std = "ind.max"))

  labels <- drawn_labels(function() {
    graphics::fourfoldplot(half, std = "ind.max")
  })
  expect_equal(
    unname(labels[1:4]), c("Answer: yes", ": hi", "Answer: no", ": lo")
  )

  # The one place this reading is deliberately NOT identical to the drawing:
  # an empty axis name tells a reader nothing, so `fourfoldplot()`'s own
  # positional default stands in.
  axes <- BaseRFourfoldLayerProcessor$new(info)$extract_axis_titles(info)
  expect_equal(axes$y$label, "Answer")
  expect_equal(axes$x$label, "Col")
})

test_that("the title is the one the call was given", {
  titled <- layer_info_for(two_by_two(), list(std = "ind.max", main = "Trial"))
  bare <- layer_info_for(two_by_two(), list(std = "ind.max"))

  expect_equal(
    BaseRFourfoldLayerProcessor$new(titled)$extract_main_title(titled), "Trial"
  )
  expect_equal(
    BaseRFourfoldLayerProcessor$new(bare)$extract_main_title(bare), ""
  )
})


# ------------------------------------------------------------------------------
# Selectors, and the geometry gate's own falsification
# ------------------------------------------------------------------------------

test_that("the selector grid is emitted bottom visual row first", {
  # Two orderings, running opposite ways. The drawing is column-major, so
  # cell [r, c] is polygon (c - 1) * 2 + r, and table row 1 is the TOP row on
  # the page -- measured centroids, screen y = 360 - y: polygon-1 (221, 158)
  # upper left, polygon-2 (190, 224) lower left, polygon-3 (345, 114) upper
  # right, polygon-4 (376, 268) lower right. But maidr's `heat` trace reverses
  # `points` and `y` in its constructor
  # (`this.heatmapValues=[...t.points].reverse()`) and does NOT reverse an
  # array-of-arrays `selectors`, so highlightValues[0] pairs with the LAST
  # emitted row.
  #
  # THE WRONG ANSWER, pinned below so it is read rather than rediscovered:
  # emitting the grid index-aligned with `points` -- polygon-1/polygon-3
  # first -- highlights the vertically mirrored quadrant on every cell, so
  # row 0, col 0 announces Placebo / 40 and lights the wedge drawn for
  # Drug / 10. `image()` emits bottom-row-first for the same reason.
  skip_if_not_installed("ggplotify")
  tab <- two_by_two()
  info <- layer_info_for(tab, list(std = "ind.max"))
  gt <- drawn(function() graphics::fourfoldplot(tab, std = "ind.max"))

  selectors <- BaseRFourfoldLayerProcessor$new(info)$generate_selectors(info, gt)

  expect_equal(
    unlist(selectors[[1]]),
    c(
      "#graphics-plot-1-polygon-2\\.1 polygon",
      "#graphics-plot-1-polygon-4\\.1 polygon"
    )
  )
  expect_equal(
    unlist(selectors[[2]]),
    c(
      "#graphics-plot-1-polygon-1\\.1 polygon",
      "#graphics-plot-1-polygon-3\\.1 polygon"
    )
  )

  # The counts still come out top row first, and that pairing is the whole
  # point: reversed `points` against an unreversed selector grid means the
  # first emitted row of each must be the OPPOSITE row of the table.
  points <- BaseRFourfoldLayerProcessor$new(info)$extract_data(info)$points
  expect_equal(points[[1]], list(10, 90))
})

test_that("a chart whose geometry disagrees loses its selectors, not its numbers", {
  # Grobs from a `margins` drawing, arguments saying `ind.max`. The counts are
  # still the ones the call was handed, so they are still announced; what is
  # refused is a highlight that would address the wrong quadrant. The reading
  # cannot be lost here -- by the time a processor holds a grob the
  # picture-versus-chart decision is already frozen -- and the processor's
  # roxygen says so rather than pretending otherwise.
  skip_if_not_installed("ggplotify")
  tab <- two_by_two()
  info <- layer_info_for(tab, list(std = "ind.max"))
  wrong <- drawn(function() graphics::fourfoldplot(tab))

  result <- BaseRFourfoldLayerProcessor$new(info)$process(
    NULL, NULL, gt = wrong, layer_info = info
  )

  expect_equal(result$selectors, list())
  expect_equal(result$type, "heat")
  expect_equal(result$data$points, list(list(10, 90), list(40, 160)))
})

test_that("another chart's grob tree yields no selectors", {
  skip_if_not_installed("ggplotify")
  info <- layer_info_for(two_by_two(), list(std = "ind.max"))
  six <- drawn(function() {
    graphics::fourfoldplot(UCBAdmissions, std = "ind.max")
  })

  # 78 polygons: 13 per panel and six panels, all named graphics-plot-1-*.
  expect_length(polygon_grobs(six), 78L)
  expect_equal(
    BaseRFourfoldLayerProcessor$new(info)$generate_selectors(info, six), list()
  )
})

test_that("a quadrant drawn with no fill keeps its selector", {
  # `fourfoldplot()` does not validate `color`'s length, and indexes it as
  # `color[1 + (d > 1)]` / `color[2 - (d > 1)]` -- so a scalar `color` leaves
  # two quadrants with fill NA. A fill-keyed wedge search would find two and
  # the layer would ship with NO selectors at all, for a chart that is
  # perfectly readable. Discriminating on polygon count and vertex count
  # instead is why these pass.
  skip_if_not_installed("ggplotify")
  tab <- two_by_two()
  info <- layer_info_for(tab, list(std = "ind.max"))

  for (colour in list("steelblue", c(NA, "red"))) {
    gt <- drawn(local({
      k <- colour
      function() graphics::fourfoldplot(tab, std = "ind.max", color = k)
    }))
    fills <- vapply(
      polygon_grobs(gt)[1:4],
      function(n) as.character(grid::getGrob(gt, n)$gp$fill)[[1]],
      character(1)
    )
    expect_equal(sum(is.na(fills)), 2L, info = paste(colour, collapse = ","))

    selectors <- BaseRFourfoldLayerProcessor$new(info)$generate_selectors(info, gt)
    expect_equal(length(unlist(selectors)), 4L, info = paste(colour, collapse = ","))
  }
})

test_that("a zero cell keeps its place and its selector", {
  skip_if_not_installed("ggplotify")
  zeroed <- as.table(matrix(
    c(0, 5, 3, 12), nrow = 2,
    dimnames = list(R = c("a", "b"), C = c("p", "q"))
  ))
  info <- layer_info_for(zeroed, list(std = "ind.max"))
  gt <- drawn(function() graphics::fourfoldplot(zeroed, std = "ind.max"))
  processor <- BaseRFourfoldLayerProcessor$new(info)

  # `r / sqrt(0)` is NaN, so the zero cell is held to `r == 0` instead of
  # entering the ratio -- measured, the wedge is still a full 501-vertex
  # polygon at the origin, so the grob is there and addressable.
  expect_equal(grob_radius(gt, polygon_grobs(gt)[[1]]), 0)
  expect_equal(processor$extract_data(info)$points, list(list(0, 3), list(5, 12)))
  expect_length(unlist(processor$generate_selectors(info, gt)), 4L)
})

test_that("fewer than two non-zero cells is not evidence, so nothing highlights", {
  # The check is vacuous there: one non-zero cell makes the relative deviation
  # identically 0 whatever the radius is, so the same drawing would "agree"
  # with any table carrying the same three zeros. The counts are announced and
  # the selectors are dropped, which is the conservative half of a choice that
  # has no good half.
  skip_if_not_installed("ggplotify")
  lone <- as.table(matrix(
    c(0, 0, 0, 160), nrow = 2,
    dimnames = list(R = c("a", "b"), C = c("p", "q"))
  ))
  info <- layer_info_for(lone, list(std = "ind.max"))
  gt <- drawn(function() graphics::fourfoldplot(lone, std = "ind.max"))
  processor <- BaseRFourfoldLayerProcessor$new(info)

  expect_equal(
    unname(vapply(polygon_grobs(gt)[1:4], function(n) grob_radius(gt, n), 0)),
    c(0, 0, 0, 1)
  )
  expect_equal(processor$extract_data(info)$points, list(list(0, 0), list(0, 160)))
  expect_equal(processor$generate_selectors(info, gt), list())
})

test_that("the geometry gate is blind to a change of scale, and says so", {
  # Exactly scale-invariant: `r / sqrt(count) == 1 / sqrt(max(tab))`, so ANY
  # positive multiple of the recorded table passes. Pinned because the
  # processor's roxygen claims it, and a reader who believed the check was
  # verifying the numbers would be wrong.
  skip_if_not_installed("ggplotify")
  tab <- two_by_two()
  info <- layer_info_for(tab, list(std = "ind.max"))

  for (multiple in c(3, 1e6)) {
    scaled <- as.table(tab * multiple)
    gt <- drawn(local({
      s <- scaled
      function() graphics::fourfoldplot(s, std = "ind.max")
    }))
    expect_equal(
      relative_spread(
        vapply(polygon_grobs(gt)[1:4], function(n) grob_radius(gt, n), 0),
        as.numeric(tab)
      ),
      0,
      tolerance = 1e-12
    )
    expect_length(
      unlist(BaseRFourfoldLayerProcessor$new(info)$generate_selectors(info, gt)),
      4L
    )
  }
})


# ------------------------------------------------------------------------------
# The whole way through
# ------------------------------------------------------------------------------

test_that("a fourfold plot with ind.max renders interactively, not as a picture", {
  skip_on_cran()
  skip_if_not_installed("jsonlite")
  clear_all_device_storage()
  file <- tempfile(fileext = ".html")
  grDevices::pdf(NULL)
  on.exit({
    while (grDevices::dev.cur() != 1L) grDevices::dev.off()
    unlink(file)
    clear_all_device_storage()
  }, add = TRUE)

  warnings <- character()
  withCallingHandlers(
    {
      fourfoldplot(two_by_two(), std = "ind.max")
      maidr::save_html(plot = NULL, file = file)
    },
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  raw <- paste(readLines(file, warn = FALSE), collapse = "\n")
  html <- gsub("&quot;", '"', raw, fixed = TRUE)

  # Silent: the export only works because `repair_na_text_justification()`
  # fixes the count label's `vjust = NA`, the same gridSVG defect `pie()`
  # hits -- without it `grid.export()` aborts on `graphics-plot-1-text-5`.
  expect_equal(warnings, character())
  expect_false(grepl("base64", html, fixed = TRUE))
  expect_true(grepl('"type":"heat"', html, fixed = TRUE))
  expect_true(grepl('"points":[[10,90],[40,160]]', html, fixed = TRUE))
  expect_true(grepl('"z":{"label":"Count"}', html, fixed = TRUE))

  # Every emitted selector resolves in the exported SVG.
  for (i in 1:4) {
    expect_true(
      grepl(paste0('id="graphics-plot-1-polygon-', i, '.1"'), raw, fixed = TRUE),
      info = as.character(i)
    )
  }
})

test_that("the default keeps falling back to a picture, and says why", {
  skip_on_cran()
  skip_if_not_installed("jsonlite")
  reset_fourfold_advisory()
  clear_all_device_storage()
  file <- tempfile(fileext = ".html")
  grDevices::pdf(NULL)
  on.exit({
    while (grDevices::dev.cur() != 1L) grDevices::dev.off()
    unlink(file)
    clear_all_device_storage()
    reset_fourfold_advisory()
  }, add = TRUE)

  warnings <- character()
  withCallingHandlers(
    {
      fourfoldplot(two_by_two())
      maidr::save_html(plot = NULL, file = file)
    },
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  html <- paste(readLines(file, warn = FALSE), collapse = "\n")

  expect_true(grepl("base64", html, fixed = TRUE))
  expect_true(any(grepl("unsupported elements", warnings, fixed = TRUE)))
  # And the explanation the generic warning does not give.
  expect_true(any(grepl("std = \"ind.max\"", warnings, fixed = TRUE)))
})

test_that("the factory answers to the name the adapter types it as", {
  # A type the factory builds but does not claim is refused by
  # `supports_plot_type()` before the processor is ever reached (#200, #214).
  factory <- BaseRProcessorFactory$new()
  info <- layer_info_for(two_by_two(), list(std = "ind.max"))

  expect_true(factory$supports_plot_type("fourfold"))
  expect_s3_class(
    factory$create_processor("fourfold", info), "BaseRFourfoldLayerProcessor"
  )
})

test_that("a qualified call is still not recorded at all", {
  # Pre-existing and out of scope for #268, pinned so the refusal list above
  # is not read as complete. `graphics::fourfoldplot()` does not go through
  # the search-path patch, so nothing is recorded and the save reports an
  # empty device -- the defect the classification list already records for
  # `stats::acf()`. Under EVERY `std`, including the one that is read.
  skip_on_cran()
  skip_if_not_installed("jsonlite")
  clear_all_device_storage()
  file <- tempfile(fileext = ".html")
  grDevices::pdf(NULL)
  on.exit({
    while (grDevices::dev.cur() != 1L) grDevices::dev.off()
    unlink(file)
    clear_all_device_storage()
  }, add = TRUE)

  error <- tryCatch(
    {
      graphics::fourfoldplot(two_by_two(), std = "ind.max")
      maidr::save_html(plot = NULL, file = file)
      NULL
    },
    error = function(e) conditionMessage(e)
  )

  expect_match(error, "No Base R plots detected")
})
