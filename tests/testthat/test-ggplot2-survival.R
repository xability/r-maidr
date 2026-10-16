# A ggplot2 Kaplan-Meier curve is a `survival` layer when its author says so.
#
# `maidr_survival()` draws the curves -- from a `survfit` object or from data
# -- with a geom of its own, which carries each time's censoring and the
# band's bounds through `ggplot_build()` and draws the band, the curve and the
# censoring marks as one grob tree. A `geom_step()` keeps its step reading,
# and a survminer figure handed to `save_html()` is redrawn as one declared
# layer.

skip_slow_file_on_cran()
testthat::skip_if_not_installed("survival")

lung_fit <- function(formula = survival::Surv(time, status) ~ sex) {
  # The formula is written into the call, which survminer reads back.
  eval(bquote(survival::survfit(.(formula), data = survival::lung)))
}

# Built at top level: inside a closure the bare column names in `aes()` read
# as undefined globals to static analysis.
summary_xy <- ggplot2::aes(x = t, y = S, colour = arm)
summary_marks <- ggplot2::aes(censored = cens, ymin = lo, ymax = hi)

# The fit's own summary as rows, as an author might keep them.
fit_rows <- function(fit = lung_fit()) {
  s <- summary(fit, censored = TRUE)
  data.frame(
    t = s$time, S = s$surv, lo = s$lower, hi = s$upper,
    cens = s$n.censor > 0, arm = s$strata
  )
}

survival_layers <- function(plot) {
  Filter(function(l) identical(l$type, "survival"), layers_from(rendered(plot)))
}

count_of <- function(series, field) {
  sum(vapply(series, function(p) !is.null(p[[field]]), logical(1)))
}

censored_of <- function(series) {
  sum(vapply(series, function(p) isTRUE(p$censored), logical(1)))
}

detected <- function(plot, index = 1) {
  maidr:::Ggplot2Adapter$new()$detect_layer_type(plot$layers[[index]], plot)
}


# ---------------------------------------------------------------------------
# Registration
# ---------------------------------------------------------------------------

test_that("the processor is registered for the survival type", {
  factory <- maidr:::Ggplot2ProcessorFactory$new()
  testthat::expect_true("survival" %in% factory$get_supported_types())
  testthat::expect_s3_class(
    factory$create_processor("survival", list(index = 1, type = "survival")),
    "Ggplot2SurvivalLayerProcessor"
  )
})

test_that("the bundled maidr.js builds the survival trace", {
  bundle <- system.file(
    "htmlwidgets", "lib", paste0("maidr-", maidr:::MAIDR_VERSION), "maidr.js",
    package = "maidr"
  )
  testthat::skip_if_not(nzchar(bundle) && file.exists(bundle))
  source <- paste(readLines(bundle, warn = FALSE), collapse = "\n")
  testthat::expect_true(grepl("SURVIVAL=[\"'`]survival[\"'`]", source))
})

test_that("a declared layer is detected as survival, a geom_step() as step", {
  rows <- fit_rows()
  declared <- ggplot2::ggplot(rows, summary_xy) + maidr_survival()
  plain <- ggplot2::ggplot(rows, summary_xy) + ggplot2::geom_step()

  testthat::expect_identical(detected(declared), "survival")
  testthat::expect_identical(detected(plain), "step")
})


# ---------------------------------------------------------------------------
# From a survfit object
# ---------------------------------------------------------------------------

test_that("a survfit object is one series per stratum, from the origin", {
  fit <- lung_fit()
  layers <- survival_layers(ggplot2::ggplot() + maidr_survival(fit))

  testthat::expect_length(layers, 1L)
  layer <- layers[[1]]
  testthat::expect_identical(layer$stepDirection, "hv")
  testthat::expect_length(layer$data, 2L)

  # survfit0() adds the origin, as plot() of the fit starts there.
  sizes <- as.integer(fit$strata) + 1L
  testthat::expect_identical(
    vapply(layer$data, length, integer(1)), sizes
  )
  first <- layer$data[[1]][[1]]
  testthat::expect_equal(first$x, 0)
  testthat::expect_equal(first$y, 1)
  testthat::expect_identical(
    vapply(layer$data, function(s) s[[1]]$z, ""),
    names(fit$strata)
  )

  axes <- layer$axes
  testthat::expect_identical(axes$x$label, "Time")
  testthat::expect_identical(axes$y$label, "Survival probability")
  testthat::expect_identical(axes$z$label, "Stratum")
})

test_that("each censored time is marked, whether or not the marks are drawn", {
  fit <- lung_fit()
  ends <- cumsum(fit$strata)
  starts <- ends - fit$strata + 1L
  expected <- vapply(seq_along(ends), function(s) {
    sum(fit$n.censor[starts[[s]]:ends[[s]]] > 0)
  }, numeric(1))

  for (marks in c(TRUE, FALSE)) {
    layer <- survival_layers(
      ggplot2::ggplot() + maidr_survival(fit, censor = marks)
    )[[1]]
    testthat::expect_equal(
      vapply(layer$data, censored_of, numeric(1)), expected
    )
  }
})

test_that("the band is each point's yMin and yMax only when it is drawn", {
  fit <- lung_fit()
  without <- survival_layers(ggplot2::ggplot() + maidr_survival(fit))[[1]]
  with <- survival_layers(
    ggplot2::ggplot() + maidr_survival(fit, conf.int = TRUE)
  )[[1]]

  testthat::expect_true(all(vapply(without$data, count_of, 0L, "yMin") == 0L))
  testthat::expect_true(all(vapply(with$data, count_of, 0L, "yMin") > 0L))

  point <- with$data[[1]][[3]]
  testthat::expect_lte(point$yMin, point$y)
  testthat::expect_gte(point$yMax, point$y)
  # The bounds are the fit's own.
  testthat::expect_equal(point$yMin, fit$lower[[2]], tolerance = 1e-6)
  testthat::expect_equal(point$yMax, fit$upper[[2]], tolerance = 1e-6)
})

test_that("a fit without strata is one unnamed curve", {
  fit <- lung_fit(survival::Surv(time, status) ~ 1)
  layer <- survival_layers(ggplot2::ggplot() + maidr_survival(fit))[[1]]

  testthat::expect_length(layer$data, 1L)
  testthat::expect_length(layer$data[[1]], length(fit$time) + 1L)
  testthat::expect_null(layer$data[[1]][[1]]$z)
})

test_that("further aesthetics may be mapped onto the fit's columns", {
  plot <- ggplot2::ggplot() +
    maidr_survival(lung_fit(), ggplot2::aes(linetype = Stratum))
  layer <- survival_layers(plot)[[1]]

  testthat::expect_length(layer$data, 2L)
  testthat::expect_identical(layer$data[[2]][[1]]$z, "sex=2")
})

test_that("a fit that is not one survival curve per stratum is an error", {
  testthat::skip_if_not(maidr:::survfit0_available())
  states <- survival::mgus2
  states$etime <- with(states, ifelse(pstat == 0, futime, ptime))
  states$event <- with(states, factor(
    ifelse(pstat == 0, 2L * death, 1L),
    0:2, c("censor", "pcm", "death")
  ))
  multistate <- survival::survfit(
    survival::Surv(etime, event) ~ 1,
    data = states
  )

  testthat::expect_error(
    maidr_survival(multistate),
    "one per stratum"
  )
})

test_that("the survfit reading is the one plot() of the fit gives", {
  # Both readings come from survfit_frame(), so the two bindings of one fit
  # agree point for point.
  fit <- lung_fit()
  layer <- survival_layers(
    ggplot2::ggplot() + maidr_survival(fit, conf.int = TRUE)
  )[[1]]
  base <- maidr:::survfit_curves(fit, list(x = fit, conf.int = TRUE))

  strip <- function(series) {
    lapply(series, function(p) {
      p[c("x", "y", "censored", "yMin", "yMax")]
    })
  }
  testthat::expect_equal(
    lapply(layer$data, strip),
    lapply(base, strip),
    tolerance = 1e-9
  )
})


# ---------------------------------------------------------------------------
# From data
# ---------------------------------------------------------------------------

test_that("a logical censored aesthetic does not split the curves", {
  rows <- fit_rows()
  layer <- survival_layers(
    ggplot2::ggplot(rows, summary_xy) + maidr_survival(summary_marks)
  )[[1]]

  testthat::expect_length(layer$data, 2L)
  testthat::expect_equal(
    vapply(layer$data, censored_of, numeric(1)),
    as.numeric(tapply(rows$cens, rows$arm, sum))
  )
  testthat::expect_identical(
    vapply(layer$data, length, integer(1)),
    as.integer(table(rows$arm))
  )
})

test_that("a censoring count reads as censored where it is above zero", {
  rows <- fit_rows()
  rows$cens <- as.integer(rows$cens) * 2L
  layer <- survival_layers(
    ggplot2::ggplot(rows, summary_xy) + maidr_survival(summary_marks)
  )[[1]]

  testthat::expect_equal(
    sum(vapply(layer$data, censored_of, numeric(1))),
    sum(rows$cens > 0)
  )
})

test_that("rows out of order are read in the order they are drawn", {
  rows <- fit_rows()
  shuffled <- rows[rev(seq_len(nrow(rows))), ]
  ordered <- survival_layers(
    ggplot2::ggplot(rows, summary_xy) +
      maidr_survival(summary_marks, conf.int = TRUE)
  )[[1]]
  reversed <- survival_layers(
    ggplot2::ggplot(shuffled, summary_xy) +
      maidr_survival(summary_marks, conf.int = TRUE)
  )[[1]]

  testthat::expect_equal(reversed$data, ordered$data)
})

test_that("unknown aesthetics are not warned about", {
  rows <- fit_rows()
  plot <- ggplot2::ggplot(rows, summary_xy) +
    maidr_survival(summary_marks, conf.int = TRUE)
  testthat::expect_no_warning(ggplot2::ggplot_build(plot))
})


# ---------------------------------------------------------------------------
# Highlight
# ---------------------------------------------------------------------------

test_that("each stratum's curve is outlined, one staircase vertex pair per time", {
  fit <- lung_fit()
  html <- rendered(ggplot2::ggplot() + maidr_survival(fit, conf.int = TRUE))
  layer <- Filter(
    function(l) identical(l$type, "survival"), layers_from(html)
  )[[1]]

  testthat::expect_length(layer$selectors, 2L)
  svg <- regmatches(html, regexpr("<svg.*</svg>", html))
  doc <- xml2::read_xml(svg)
  for (i in seq_along(layer$selectors)) {
    id <- gsub("\\\\", "", sub("^#", "", layer$selectors[[i]]))
    node <- xml2::xml_find_all(doc, sprintf("//*[@id='%s']", id))
    testthat::expect_length(node, 1L)
    points <- strsplit(trimws(xml2::xml_attr(node, "points")), " +")[[1]]
    # The "hv" staircase: every time after the first adds two vertices.
    testthat::expect_length(points, 2L * length(layer$data[[i]]) - 1L)
  }
})

test_that("a line beside the curve keeps its own polyline", {
  rows <- fit_rows()
  plot <- ggplot2::ggplot(rows, summary_xy) +
    ggplot2::geom_line(linetype = "dashed") +
    maidr_survival(ggplot2::aes(censored = cens))
  layers <- layers_from(rendered(plot))
  types <- vapply(layers, `[[`, "", "type")
  testthat::expect_setequal(types, c("line", "survival"))

  line <- unlist(layers[[which(types == "line")]]$selectors)
  curve <- unlist(layers[[which(types == "survival")]]$selectors)
  testthat::expect_length(line, 2L)
  testthat::expect_length(curve, 2L)
  testthat::expect_length(intersect(line, curve), 0L)
})

test_that("the curve's polyline is found only in its own grob tree", {
  rows <- fit_rows()
  plot <- ggplot2::ggplot(rows, summary_xy) +
    maidr_survival(summary_marks, conf.int = TRUE)
  gt <- ggplot2::ggplotGrob(plot)
  panel <- gt$grobs[[which(gt$layout$name == "panel")]]
  processor <- maidr:::Ggplot2SurvivalLayerProcessor$new(
    list(index = 1, type = "survival")
  )

  grob <- processor$find_layer_polyline_grob(plot, panel)
  testthat::expect_match(grob$name, "^GRID\\.polyline\\.")
  testthat::expect_equal(processor$polyline_curve_count(grob), 2L)
})


# ---------------------------------------------------------------------------
# survminer
# ---------------------------------------------------------------------------

test_that("a ggsurvplot figure is read as one survival layer", {
  testthat::skip_if_not_installed("survminer")
  fit <- lung_fit()
  figure <- suppressWarnings(
    survminer::ggsurvplot(fit, data = survival::lung, conf.int = TRUE)
  )
  layers <- layers_from(rendered(figure))

  testthat::expect_identical(vapply(layers, `[[`, "", "type"), "survival")
  testthat::expect_length(layers[[1]]$data, 2L)
  testthat::expect_length(layers[[1]]$selectors, 2L)
  testthat::expect_true(all(vapply(layers[[1]]$data, count_of, 0L, "yMin") > 0L))
  testthat::expect_equal(
    sum(vapply(layers[[1]]$data, censored_of, numeric(1))),
    sum(fit$n.censor > 0)
  )
})

test_that("a ggsurvplot without the band reads no bounds", {
  testthat::skip_if_not_installed("survminer")
  figure <- suppressWarnings(
    survminer::ggsurvplot(lung_fit(), data = survival::lung)
  )
  layer <- layers_from(rendered(figure))[[1]]
  testthat::expect_identical(layer$type, "survival")
  testthat::expect_true(all(vapply(layer$data, count_of, 0L, "yMin") == 0L))
})

test_that("a ggsurvplot risk table is left out, and says so", {
  testthat::skip_if_not_installed("survminer")
  figure <- suppressWarnings(survminer::ggsurvplot(
    lung_fit(),
    data = survival::lung, risk.table = TRUE
  ))
  testthat::expect_message(
    plot <- maidr:::ggsurvplot_as_ggplot(figure),
    "risk table"
  )
  testthat::expect_s3_class(plot, "ggplot")
})

test_that("a ggsurvplot of another function keeps the step reading", {
  testthat::skip_if_not_installed("survminer")
  figure <- suppressWarnings(survminer::ggsurvplot(
    lung_fit(),
    data = survival::lung, fun = "event"
  ))
  plot <- maidr:::ggsurvplot_as_ggplot(figure)
  geoms <- vapply(plot$layers, function(l) class(l$geom)[1], "")
  testthat::expect_false("GeomSurvival" %in% geoms)
  testthat::expect_true("GeomStep" %in% geoms)
})

test_that("anything else passes through untouched", {
  plot <- ggplot2::ggplot(fit_rows(), summary_xy) + ggplot2::geom_step()
  testthat::expect_identical(maidr:::ggsurvplot_as_ggplot(plot), plot)
  testthat::expect_null(maidr:::ggsurvplot_as_ggplot(NULL))
})
