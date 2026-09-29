# The lattice system's plumbing (#333)
#
# Everything a trellis object passes through before any layer is read: which
# system claims it, whether it can be read at all, how its packets are laid
# out on the page, what its labels and strips say, how the grobs lattice
# draws are named and addressed in the exported SVG, and how one panel's
# grobs are grouped into layers.
#
# lattice ships without its sources, and the lattice system re-implements a
# few of its internals rather than reaching them with `:::` from package
# code -- `compute.layout()`, `getLabelList()`, `panel.superpose()`'s group
# numbering. So each claim here is checked against what lattice itself does:
# its own drawing (the grobs it draws, read back from grid on a throwaway
# device), its own computation (`lattice:::compute.layout()` is fair game in
# a test), or the SVG the chart is exported as -- never against the code
# under test.

skip_slow_file_on_cran()

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------

#' lattice's own drawer, which neither consults `print.function` nor comes
#' back through MAIDR's print hook
plot_trellis_natively <- function(plot, ...) {
  utils::getS3method("plot", "trellis")(plot, ...)
}

#' Draw a trellis object with lattice's own drawer on a throwaway device, and
#' return what `read()` finds while the drawing is still there
with_native_drawing <- function(plot, read, prefix = "chk") {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  plot_trellis_natively(plot, prefix = prefix)
  read()
}

#' Every grob a drawing holds, with the viewport it was drawn in
drawn_listing <- function() {
  listing <- grid::grid.ls(grobs = TRUE, viewports = TRUE, print = FALSE)
  data.frame(
    name = as.character(listing$name),
    vpPath = as.character(listing$vpPath),
    type = as.character(listing$type),
    stringsAsFactors = FALSE
  )[listing$type == "grobListing", , drop = FALSE]
}

#' The grobs lattice drew inside one panel's data viewport, in drawing order
panel_grob_names <- function(plot, column = 1, row = 1, prefix = "chk") {
  with_native_drawing(plot, function() {
    listing <- drawn_listing()
    vp <- sprintf("::%s\\.panel\\.%d\\.%d\\.vp$", prefix, column, row)
    listing$name[grepl(vp, listing$vpPath)]
  }, prefix = prefix)
}

#' The label lattice drew in one of its label viewports (`main`, `xlab`, ...)
#'
#' Read from whatever grob lands in `<prefix>.<which>.vp`: lattice names the
#' text grob it builds `<prefix>.<which>`, and a grob given as the label
#' keeps its own name. `NULL` when nothing was drawn there.
drawn_label <- function(plot, which, prefix = "chk") {
  with_native_drawing(plot, function() {
    listing <- drawn_listing()
    here <- grepl(sprintf("::%s\\.%s\\.vp$", prefix, which), listing$vpPath)
    labels <- lapply(listing$name[here], function(name) grid::grid.get(name)$label)
    if (length(labels) == 0L) NULL else labels[[1]]
  }, prefix = prefix)
}

#' A drawn label as a reader would hear it: an expression as its source
drawn_text <- function(label) {
  if (is.null(label)) {
    return(NULL)
  }
  text <- if (is.expression(label)) {
    vapply(as.list(label), function(e) paste(deparse(e), collapse = " "), character(1))
  } else {
    as.character(label)
  }
  text <- text[!is.na(text) & nzchar(text)]
  if (length(text) == 0L) NULL else paste(text, collapse = " ")
}

#' The packet matrix of every page lattice draws, from a `page =` hook
#'
#' `plot.trellis()` calls the object's `page` function after drawing each
#' page, while that page's layout is still lattice's current one.
drawn_pages <- function(plot, prefix = "pg") {
  seen <- new.env(parent = emptyenv())
  seen$pages <- list()
  plot$page <- function(n) {
    seen$pages[[n]] <- lattice::trellis.currentLayout("packet", prefix = prefix)
  }
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  # An over-specified layout draws an empty last page, and lattice warns.
  suppressWarnings(plot_trellis_natively(plot, prefix = prefix))
  seen$pages
}

#' The coordinates a points grob lattice drew holds, in its native units
drawn_points <- function(name) {
  grob <- grid::grid.get(name)
  data.frame(x = as.numeric(grob$x), y = as.numeric(grob$y))
}

#' One panel's grob entries as the orchestrator hands them to the adapter
panel_entries <- function(plot, classify_as = plot) {
  adapter <- maidr:::get_global_registry()$get_adapter("lattice")
  scene <- maidr:::lattice_draw_scene(plot)
  entries <- maidr:::lattice_panel_grobs(scene$listing, classify_as, adapter)
  list(scene = scene, entries = entries)
}

#' The layers the adapter reads one panel as
panel_layers <- function(plot, packet = 1, column = 1, row = 1) {
  adapter <- maidr:::get_global_registry()$get_adapter("lattice")
  entries <- panel_entries(plot)$entries
  here <- entries[
    entries$column == column & entries$row == row &
      !entries$role %in% c("decoration", "observations"), ,
    drop = FALSE
  ]
  here <- lapply(seq_len(nrow(here)), function(i) as.list(here[i, ]))
  adapter$detect_panel_layers(here, plot, lattice::trellis.panelArgs(plot, packet))
}

#' The group numbers of a layer's grobs
layer_groups <- function(layer) {
  vapply(layer$grobs, function(entry) as.integer(entry$group), integer(1))
}

#' The type of each layer in a list of layers
layer_types <- function(layers) {
  vapply(layers, function(layer) layer$type, character(1))
}

#' Every selector string of a layer, in order, with NA for a null cell
#'
#' Flattened the way `lattice_selector_counts()` flattens them, so the two
#' line up element for element.
selector_strings <- function(selectors) {
  if (is.null(selectors)) {
    return(NA_character_)
  }
  if (is.character(selectors)) {
    return(selectors)
  }
  unlist(lapply(selectors, selector_strings), use.names = FALSE)
}

#' How many elements a selector should match: the shapes the grob it names drew
#'
#' `g#<id> > <element>` names every shape of one grob, which the exporter
#' writes one element each -- a `use` per point, a `rect` per rectangle, a
#' `polyline` per segment and one per unbroken line. `#<id>\.<k>` names one.
#' A grob of any other kind has no count here yet, and says so rather than
#' being given one.
expected_matches <- function(selector, gtable) {
  whole <- regmatches(
    selector,
    regexec("^g#((?:[^ \\\\]|\\\\.)+) > ([a-z]+)$", selector, perl = TRUE)
  )[[1]]
  if (length(whole) == 0L) {
    return(1L)
  }
  id <- gsub("\\\\(.)", "\\1", whole[2])
  grob <- grid::getGrob(gtable, sub("\\.1$", "", id))
  if (inherits(grob, "segments")) {
    length(grob$x0)
  } else if (inherits(grob, "lines")) {
    1L
  } else if (inherits(grob, c("points", "rect"))) {
    length(grob$x)
  } else {
    stop("no shape count for a ", class(grob)[1], " grob: ", selector, call. = FALSE)
  }
}

# ------------------------------------------------------------------------------
# Which system claims a trellis object
# ------------------------------------------------------------------------------

test_that("the lattice adapter claims every trellis object and nothing else", {
  skip_if_no_lattice()
  adapter <- maidr:::LatticeAdapter$new()

  # Every high-level function makes a "trellis", and the adapter claims all
  # of them -- cloud() too, which it cannot read: that one is then shown as
  # an image of itself rather than handed to a system that would read
  # something else.
  charts <- list(
    lattice::xyplot(mpg ~ wt, mtcars),
    lattice::barchart(VADeaths),
    lattice::bwplot(mpg ~ factor(cyl), mtcars),
    lattice::histogram(~mpg, mtcars),
    lattice::levelplot(volcano),
    lattice::cloud(mpg ~ wt * hp, mtcars)
  )
  for (chart in charts) {
    testthat::expect_s3_class(chart, "trellis")
    testthat::expect_true(adapter$can_handle(chart))
  }

  testthat::expect_false(adapter$can_handle(NULL))
  testthat::expect_false(adapter$can_handle(list(a = 1)))
  testthat::expect_false(adapter$can_handle(42))
  testthat::expect_false(adapter$can_handle("plot"))
  # The fields of a trellis object without its class are just a list.
  testthat::expect_false(adapter$can_handle(unclass(charts[[1]])))
})

test_that("the lattice adapter does not claim a ggplot", {
  skip_if_no_lattice()
  testthat::skip_if_not_installed("ggplot2")

  p <- create_test_ggplot_bar()

  testthat::expect_false(maidr:::LatticeAdapter$new()$can_handle(p))
})

test_that("a bare latticeExtra layer is classed trellis but is not a chart", {
  skip_if_no_lattice()
  testthat::skip_if_not_installed("latticeExtra")
  overlay <- latticeExtra::layer(lattice::panel.abline(h = 20))

  testthat::expect_s3_class(overlay, "trellis")
  testthat::expect_s3_class(overlay, "layer")
  # It is an overlay waiting for a chart: lattice itself cannot draw it.
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  testthat::expect_error(plot_trellis_natively(overlay))

  adapter <- maidr:::LatticeAdapter$new()
  testthat::expect_false(adapter$can_handle(overlay))
  testthat::expect_error(adapter$create_orchestrator(overlay), "not a lattice")
})

test_that("the adapter builds a lattice orchestrator, and only for a trellis object", {
  skip_if_no_lattice()
  adapter <- maidr:::LatticeAdapter$new()

  orchestrator <- adapter$create_orchestrator(lattice::xyplot(mpg ~ wt, mtcars))

  testthat::expect_s3_class(orchestrator, "LatticePlotOrchestrator")
  testthat::expect_error(
    adapter$create_orchestrator(42),
    "Plot object is not a lattice \\(trellis\\) object"
  )
  testthat::expect_error(adapter$create_orchestrator(NULL), "not a lattice")
})

test_that("the adapter names its system lattice", {
  adapter <- maidr:::LatticeAdapter$new()

  testthat::expect_s3_class(adapter, "SystemAdapter")
  testthat::expect_identical(adapter$get_system_name(), "lattice")
  testthat::expect_identical(adapter$system_name, "lattice")
})

test_that("a trellis object is lattice's with a Base R chart recorded, in either order", {
  # The Base R adapter claims by device state, because a Base R chart is
  # not an object. It used to claim *any* object while the device held a
  # recorded call, so whichever of lattice and Base R was registered first
  # won -- and a trellis object passed to `save_html()` was exported as the
  # recorded Base R chart. It now declines the objects another system
  # draws, so registration order no longer decides.
  skip_if_no_lattice()
  p <- lattice::xyplot(mpg ~ wt, mtcars)

  grDevices::pdf(NULL)
  device_id <- grDevices::dev.cur()
  on.exit(
    {
      clear_base_r_device(device_id)
      grDevices::dev.off()
    },
    add = TRUE
  )
  clear_base_r_device(device_id)
  # Unqualified, so maidr's recording wrapper sees it.
  barplot(c(1, 2, 3))
  testthat::expect_true(maidr:::has_device_calls(device_id))

  base_r <- maidr:::BaseRAdapter$new()
  testthat::expect_true(base_r$can_handle(NULL))
  testthat::expect_false(base_r$can_handle(p))

  systems <- list(
    base_r = function() list(maidr:::BaseRAdapter$new(), maidr:::BaseRProcessorFactory$new()),
    lattice = function() list(maidr:::LatticeAdapter$new(), maidr:::LatticeProcessorFactory$new())
  )
  for (order in list(c("base_r", "lattice"), c("lattice", "base_r"))) {
    registry <- maidr:::PlotSystemRegistry$new()
    for (name in order) {
      parts <- systems[[name]]()
      registry$register_system(name, parts[[1]], parts[[2]])
    }
    testthat::expect_identical(registry$list_systems(), order)

    testthat::expect_identical(registry$detect_system(p), "lattice")
    # The recorded chart is still Base R's to export, asked for as Base R
    # charts are: with no object.
    testthat::expect_identical(registry$detect_system(NULL), "base_r")
  }

  testthat::expect_identical(maidr:::get_global_registry()$detect_system(p), "lattice")
})

test_that("without a Base R chart recorded, NULL belongs to no system", {
  skip_if_no_lattice()
  grDevices::pdf(NULL)
  device_id <- grDevices::dev.cur()
  on.exit(grDevices::dev.off(), add = TRUE)
  clear_base_r_device(device_id)

  registry <- maidr:::PlotSystemRegistry$new()
  registry$register_system(
    "lattice", maidr:::LatticeAdapter$new(), maidr:::LatticeProcessorFactory$new()
  )
  registry$register_system(
    "base_r", maidr:::BaseRAdapter$new(), maidr:::BaseRProcessorFactory$new()
  )

  testthat::expect_null(registry$detect_system(NULL))
  testthat::expect_identical(
    registry$detect_system(lattice::xyplot(mpg ~ wt, mtcars)),
    "lattice"
  )
})

# ------------------------------------------------------------------------------
# System initialisation
# ------------------------------------------------------------------------------

test_that("initialize_lattice_system() registers once, silently, returning invisible NULL", {
  registry <- maidr:::get_global_registry()
  testthat::expect_true(registry$is_system_registered("lattice"))
  before <- registry$get_adapter("lattice")

  testthat::expect_silent(result <- withVisible(maidr:::initialize_lattice_system()))

  testthat::expect_null(result$value)
  testthat::expect_false(result$visible)
  testthat::expect_identical(sum(registry$list_systems() == "lattice"), 1L)
  # A second call leaves the registered system as it was rather than
  # replacing it, so nothing holding the old adapter is left behind.
  testthat::expect_identical(registry$get_adapter("lattice"), before)
})

test_that("initialize_lattice_system() builds the system into a fresh registry", {
  # The path `.onLoad()` takes. The registry is swapped for an empty one and
  # the original put back afterwards -- the same object, so the order the
  # systems were registered in survives for the files that run after this.
  original <- maidr:::get_global_registry()
  on.exit(assign("instance", original, envir = maidr:::.maidr_registry), add = TRUE)
  maidr:::reset_global_registry()

  maidr:::initialize_lattice_system()
  registry <- maidr:::get_global_registry()

  testthat::expect_false(identical(registry, original))
  testthat::expect_identical(registry$list_systems(), "lattice")
  testthat::expect_s3_class(registry$get_adapter("lattice"), "LatticeAdapter")
  testthat::expect_s3_class(
    registry$get_processor_factory("lattice"),
    "LatticeProcessorFactory"
  )
  testthat::expect_identical(registry$get_adapter("lattice")$system_name, "lattice")
})

# ------------------------------------------------------------------------------
# The processor factory
# ------------------------------------------------------------------------------

test_that("every type the factory claims is dispatched to a processor of its own (#214)", {
  # A type claimed and handed the generic processor is worse than one not
  # claimed at all: the layer ships typed as something nothing reads.
  factory <- maidr:::LatticeProcessorFactory$new()
  claimed <- setdiff(factory$get_supported_types(), "unknown")
  testthat::expect_gt(length(claimed), 0)
  base_process <- maidr:::LatticeLayerProcessor$public_methods$process

  for (type in claimed) {
    processor <- factory$create_processor(type, list(index = 1, type = type))
    testthat::expect_s3_class(processor, "LatticeLayerProcessor")
    testthat::expect_false(
      inherits(processor, "LatticeUnknownLayerProcessor"),
      label = paste0("the processor for '", type, "' is not the unknown one")
    )
    # Its class reads the layer itself rather than inheriting the base
    # class' process(), which only stops.
    generator <- get(class(processor)[1], envir = asNamespace("maidr"))
    process <- generator$public_methods$process
    testthat::expect_true(
      is.function(process) && !identical(process, base_process),
      label = paste0(class(processor)[1], " defines a process() of its own")
    )
  }
})

test_that("every type the factory claims is a trace type the bundled maidr.js reads", {
  # The other half of #214: a type the frontend does not know throws
  # "Invalid trace type" in the reader's browser. Read off the TraceType
  # enum of the maidr.js this package ships, as it was minified.
  path <- system.file(
    sprintf("htmlwidgets/lib/maidr-%s/maidr.js", maidr:::MAIDR_VERSION),
    package = "maidr"
  )
  testthat::skip_if(!nzchar(path), "the bundled maidr.js is not installed")
  bundle <- paste(readLines(path, warn = FALSE), collapse = "\n")
  enum <- regmatches(bundle, regexpr("e\\.AREA=`area`.*?,e\\}", bundle, perl = TRUE))
  trace_types <- gsub("^=`|`$", "", regmatches(enum, gregexpr("=`[a-z_]+`", enum))[[1]])
  testthat::expect_true(all(c("bar", "point", "line") %in% trace_types))

  claimed <- maidr:::LatticeProcessorFactory$new()$get_supported_types()

  # "unknown" is the one exception, and it is never emitted: an unknown
  # layer makes the chart fall back to an image.
  testthat::expect_identical(setdiff(claimed, trace_types), "unknown")
})

test_that("every type the adapter can emit is one the factory claims", {
  # Swept over every role the adapter knows, with the panel arguments that
  # pick each variant: steps, a dot per level, grouped and stacked bars.
  adapter <- maidr:::LatticeAdapter$new()
  factory <- maidr:::LatticeProcessorFactory$new()
  roles <- setdiff(
    unique(unlist(lapply(maidr:::LATTICE_PANEL_ROLES, names))),
    c("decoration", "observations")
  )
  variants <- list(
    list(),
    list(type = "s"),
    list(x = c(1, 2), y = factor(c("a", "b"))),
    list(groups = factor(c("a", "b")), stack = FALSE),
    list(groups = factor(c("a", "b")), stack = TRUE)
  )

  emitted <- character(0)
  for (role in roles) {
    for (args in variants) {
      entry <- list(name = "n", what = "w", group = NA_integer_, role = role)
      layers <- adapter$detect_panel_layers(list(entry), NULL, args)
      testthat::expect_length(layers, 1L)
      emitted <- c(emitted, layer_types(layers))
    }
  }

  # Every emitted type is claimed, and every claimed type is emitted.
  testthat::expect_setequal(
    unique(emitted),
    setdiff(factory$get_supported_types(), "unknown")
  )
})

test_that("every type the factory claims is what a stock chart is read as", {
  skip_if_no_lattice()
  one_year <- lattice::barley[
    lattice::barley$site == "Morris" & lattice::barley$year == "1931",
  ]
  morris <- lattice::barley[lattice::barley$site == "Morris", ]
  by_weight <- mtcars[order(mtcars$wt), ]
  surface <- volcano[seq(1, 87, 10), seq(1, 61, 10)]
  charts <- list(
    point = lattice::xyplot(mpg ~ wt, mtcars),
    dot = lattice::dotplot(variety ~ yield, one_year),
    lollipop = lattice::xyplot(mpg ~ wt, mtcars, type = "h"),
    line = lattice::xyplot(mpg ~ wt, by_weight, type = "l"),
    step = lattice::xyplot(mpg ~ wt, by_weight, type = "s"),
    smooth = lattice::densityplot(~mpg, mtcars, plot.points = FALSE),
    bar = lattice::barchart(variety ~ yield, one_year),
    dodged_bar = lattice::barchart(yield ~ variety, morris, groups = year),
    stacked_bar = lattice::barchart(yield ~ variety, morris, groups = year, stack = TRUE),
    hist = lattice::histogram(~mpg, mtcars),
    box = lattice::bwplot(factor(cyl) ~ mpg, mtcars),
    heat = lattice::levelplot(surface),
    contour = lattice::contourplot(surface)
  )
  factory <- maidr:::LatticeProcessorFactory$new()
  testthat::expect_setequal(names(charts), setdiff(factory$get_supported_types(), "unknown"))

  for (type in names(charts)) {
    rendered <- render_lattice(charts[[type]])
    testthat::expect_false(rendered$fallback, label = paste(type, "falls back"))
    layers <- lattice_rendered_layers(rendered)
    testthat::expect_identical(unique(layer_types(layers)), type)

    # Each selector matches exactly the shapes of the grob it names, as
    # grid holds them in the drawn chart.
    gtable <- rendered$orchestrator$get_gtable()
    for (layer in layers) {
      strings <- selector_strings(layer$selectors)
      expected <- vapply(strings, function(s) {
        if (is.na(s)) NA_integer_ else as.integer(expected_matches(s, gtable))
      }, integer(1), USE.NAMES = FALSE)
      testthat::expect_identical(
        lattice_selector_counts(rendered$doc, strings),
        expected,
        label = paste(type, "selector matches")
      )
    }
  }
})

test_that("the factory hands any other type the unknown processor, which reads nothing", {
  factory <- maidr:::LatticeProcessorFactory$new()

  for (type in c("unknown", "violin", "")) {
    processor <- factory$create_processor(type, list(index = 1, type = type))
    testthat::expect_s3_class(processor, "LatticeUnknownLayerProcessor")
    testthat::expect_null(processor$process(NULL, NULL, layer_info = list(type = type)))
  }
})

test_that("the factory needs layer info to build a processor", {
  factory <- maidr:::LatticeProcessorFactory$new()

  testthat::expect_error(
    factory$create_processor("point", NULL),
    "Layer info must be provided"
  )
})

test_that("the factory's available processors cannot drift from its dispatch (#200)", {
  factory <- maidr:::LatticeProcessorFactory$new()
  dispatched <- maidr:::dispatched_processor_classes(
    maidr:::LatticeProcessorFactory, "Lattice"
  )

  testthat::expect_true("LatticeUnknownLayerProcessor" %in% dispatched)
  testthat::expect_setequal(factory$get_available_processors(), dispatched)
  testthat::expect_true(all(vapply(dispatched, maidr:::processor_class_exists, logical(1))))
  # And the dispatch reaches every one of them from some claimed type.
  reached <- vapply(factory$get_supported_types(), function(type) {
    class(factory$create_processor(type, list(index = 1)))[1]
  }, character(1))
  testthat::expect_setequal(unique(reached), dispatched)
})

# ------------------------------------------------------------------------------
# What is refused before drawing
# ------------------------------------------------------------------------------

test_that("the stock chart of every function the system reads passes the static check", {
  skip_if_no_lattice()
  charts <- list(
    lattice::xyplot(mpg ~ wt, mtcars),
    lattice::barchart(VADeaths),
    lattice::bwplot(mpg ~ factor(cyl), mtcars),
    lattice::histogram(~mpg, mtcars),
    lattice::densityplot(~mpg, mtcars),
    lattice::dotplot(VADeaths),
    lattice::stripplot(factor(cyl) ~ mpg, mtcars),
    lattice::levelplot(volcano),
    lattice::contourplot(volcano),
    lattice::qqmath(~mpg, mtcars),
    lattice::qq(factor(am) ~ mpg, mtcars)
  )

  for (chart in charts) {
    testthat::expect_identical(maidr:::lattice_static_check(chart), character(0))
  }
})

test_that("a high-level function the system does not read is refused by name", {
  skip_if_no_lattice()
  testthat::expect_identical(
    maidr:::lattice_static_check(lattice::cloud(mpg ~ wt * hp, mtcars)),
    "'cloud()' is not read"
  )
  testthat::expect_identical(
    maidr:::lattice_static_check(lattice::wireframe(volcano)),
    "'wireframe()' is not read"
  )
  testthat::expect_identical(
    maidr:::lattice_static_check(lattice::parallelplot(~ mtcars[1:3])),
    "'parallelplot()' is not read"
  )
  # splom() draws through a superpanel as well, which a stock call of a
  # function the system reads never sets.
  testthat::expect_identical(
    maidr:::lattice_static_check(lattice::splom(mtcars[1:3])),
    c("'splom()' is not read", "a superpanel is set")
  )
})

test_that("a custom panel function is refused, because its grobs can look stock", {
  # This closure draws exactly the grobs a stock `type = c("g", "p", "r")`
  # draws, under the same names and in the same order, so the audit of the
  # drawn grobs cannot tell them apart. Only the panel function can.
  skip_if_no_lattice()
  custom <- lattice::xyplot(mpg ~ wt, mtcars, panel = function(x, y, ...) {
    lattice::panel.grid(h = -1, v = -1)
    lattice::panel.xyplot(x, y, ...)
    lattice::panel.lmline(x, y)
  })
  stock <- lattice::xyplot(mpg ~ wt, mtcars, type = c("g", "p", "r"))

  testthat::expect_identical(panel_grob_names(custom), panel_grob_names(stock))
  testthat::expect_identical(
    maidr:::lattice_static_check(custom),
    "the panel function is not the stock one"
  )
  testthat::expect_identical(maidr:::lattice_static_check(stock), character(0))
})

test_that("lattice's own panel function passes however it is named", {
  skip_if_no_lattice()
  # lattice resolves a panel given by name inside its own namespace, so the
  # name and the function object are the same panel function.
  by_object <- lattice::xyplot(mpg ~ wt, mtcars, panel = lattice::panel.xyplot)
  by_name <- lattice::xyplot(mpg ~ wt, mtcars, panel = "panel.xyplot")

  testthat::expect_identical(maidr:::lattice_static_check(by_object), character(0))
  testthat::expect_identical(maidr:::lattice_static_check(by_name), character(0))
  testthat::expect_identical(
    panel_grob_names(by_object),
    panel_grob_names(lattice::xyplot(mpg ~ wt, mtcars))
  )

  testthat::expect_identical(maidr:::lattice_panel_name(lattice::panel.xyplot), "panel.xyplot")
  testthat::expect_identical(maidr:::lattice_panel_name("panel.xyplot"), "panel.xyplot")
  # A name lattice has no function for is no panel function at all.
  testthat::expect_true(is.na(maidr:::lattice_panel_name("panel.nonesuch")))
  testthat::expect_true(is.na(maidr:::lattice_panel_name(NA_character_)))
})

test_that("another of lattice's panel functions is not the stock one", {
  skip_if_no_lattice()
  p <- lattice::xyplot(mpg ~ wt, mtcars)
  # `useRaster = TRUE` asks the current device whether it can draw a raster,
  # which opens one when none is; it is asked a null device, closed after.
  grDevices::pdf(NULL)
  raster <- tryCatch(
    lattice::levelplot(volcano, useRaster = TRUE),
    finally = grDevices::dev.off()
  )
  checks <- list(
    # A regression line instead of the points: a stock name, the wrong one.
    update(p, panel = lattice::panel.lmline),
    # Violins draw polygons the box reading has no place for.
    lattice::bwplot(mpg ~ factor(cyl), mtcars, panel = lattice::panel.violin),
    # useRaster draws one image rather than a rect per cell.
    raster,
    # A stock panel of another function.
    lattice::bwplot(mpg ~ factor(cyl), mtcars, panel = "panel.xyplot")
  )

  for (chart in checks) {
    testthat::expect_identical(
      maidr:::lattice_static_check(chart),
      "the panel function is not the stock one"
    )
  }
})

test_that("a custom panel.groups is refused", {
  skip_if_no_lattice()
  p <- lattice::xyplot(
    mpg ~ wt, mtcars,
    groups = cyl,
    panel.groups = function(x, y, ...) lattice::panel.xyplot(x, y, ...)
  )

  testthat::expect_identical(
    maidr:::lattice_static_check(p),
    "a custom `panel.groups` is set"
  )
})

test_that("a chart with no packets is refused, as lattice cannot draw it", {
  skip_if_no_lattice()
  empty <- lattice::xyplot(mpg ~ wt | factor(cyl), mtcars)[integer(0)]

  testthat::expect_equal(prod(dim(empty)), 0)
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  testthat::expect_error(plot_trellis_natively(empty))
  testthat::expect_identical(maidr:::lattice_static_check(empty), "it has no packets")
})

test_that("latticeExtra compositions are refused", {
  skip_if_no_lattice()
  testthat::skip_if_not_installed("latticeExtra")
  p <- lattice::xyplot(mpg ~ wt, mtcars)
  q <- lattice::xyplot(hp ~ wt, mtcars)

  # `+ layer()` and `+ as.layer()` rewrite the call to `update` and leave
  # their marker on the panel they wrap.
  layered <- p + latticeExtra::layer(lattice::panel.abline(h = 20))
  overlaid <- p + latticeExtra::as.layer(q)
  for (chart in list(layered, overlaid)) {
    testthat::expect_identical(
      maidr:::lattice_static_check(chart),
      c("'update()' is not read", "latticeExtra layers were added")
    )
  }

  testthat::expect_identical(
    maidr:::lattice_static_check(c(p, q)),
    "'update()' is not read"
  )

  # doubleYScale() keeps its call as written, so called through `::` its
  # name is a call to `::` rather than a symbol. It is refused by name
  # either way, rather than as "'NA()'".
  double_y <- latticeExtra::doubleYScale(p, q)
  testthat::expect_true(is.call(double_y$call[[1]]))
  testthat::expect_identical(
    maidr:::lattice_static_check(double_y),
    c("'doubleYScale()' is not read", "latticeExtra layers were added")
  )
  double_y <- do.call("doubleYScale", list(p, q), envir = asNamespace("latticeExtra"))
  testthat::expect_true(is.symbol(double_y$call[[1]]))
  testthat::expect_identical(
    maidr:::lattice_static_check(double_y),
    c("'doubleYScale()' is not read", "latticeExtra layers were added")
  )
})

test_that("a trellis object whose call names no function is refused as unknown", {
  skip_if_no_lattice()
  p <- lattice::xyplot(mpg ~ wt, mtcars)

  anonymous <- p
  anonymous$call <- quote((function(...) NULL)())
  testthat::expect_identical(
    maidr:::lattice_static_check(anonymous),
    "the function that made it is not known"
  )
  callless <- p
  callless$call <- NULL
  testthat::expect_identical(
    maidr:::lattice_static_check(callless),
    "the function that made it is not known"
  )
  # A supported function called through `::` is read by its name: lattice
  # rewrites its own calls to the bare name, and the name survives `::`.
  qualified <- p
  qualified$call[[1]] <- quote(lattice::xyplot)
  testthat::expect_identical(maidr:::lattice_static_check(qualified), character(0))
})

# ------------------------------------------------------------------------------
# Labels
# ------------------------------------------------------------------------------

test_that("a figure title reads as the text lattice draws for it", {
  skip_if_no_lattice()
  cases <- list(
    list(main = NULL, text = NULL),
    list(main = "Fuel economy", text = "Fuel economy"),
    # Several strings are drawn side by side.
    list(main = c("Fuel", "economy"), text = "Fuel economy"),
    list(main = expression(alpha^2), text = "alpha^2"),
    # lattice draws a call as the expression it is.
    list(main = quote(sqrt(mpg)), text = "sqrt(mpg)"),
    list(main = list("Fuel economy", cex = 2), text = "Fuel economy"),
    list(main = list(label = "Fuel economy"), text = "Fuel economy"),
    list(main = list("Fuel", label = "economy"), text = "economy"),
    # A number taken out of a list is drawn as grid prints it...
    list(main = list(2024, cex = 2), text = "2024"),
    # ... while these fall back to the default, and `main` has none.
    list(main = 2024, text = NULL),
    list(main = list(cex = 2), text = NULL),
    list(main = TRUE, text = NULL)
  )

  for (case in cases) {
    p <- lattice::xyplot(mpg ~ wt, mtcars, main = case$main)
    label <- paste(deparse(case$main), collapse = " ")
    testthat::expect_identical(
      drawn_text(drawn_label(p, "main")), case$text,
      label = paste("lattice's drawing of", label)
    )
    testthat::expect_identical(
      maidr:::lattice_label_text(p$main), case$text,
      label = paste("the reading of", label)
    )
  }
})

test_that("a title given as a grob reads as its text", {
  skip_if_no_lattice()
  # lattice draws the grob itself, under the grob's own name.
  p <- lattice::xyplot(mpg ~ wt, mtcars, main = grid::textGrob("Fuel economy"))
  testthat::expect_identical(drawn_text(drawn_label(p, "main")), "Fuel economy")
  testthat::expect_identical(maidr:::lattice_label_text(p$main), "Fuel economy")

  # A grob that is not text draws something no text can stand for.
  p <- lattice::xyplot(mpg ~ wt, mtcars, main = grid::rectGrob())
  testthat::expect_null(drawn_text(drawn_label(p, "main")))
  testthat::expect_null(maidr:::lattice_label_text(p$main))
})

test_that("an axis title that asks for the default reads as the default lattice draws", {
  skip_if_no_lattice()
  for (xlab in list(TRUE, list(cex = 2), 2024)) {
    p <- lattice::xyplot(mpg ~ wt, mtcars, xlab = xlab)
    testthat::expect_identical(drawn_text(drawn_label(p, "xlab")), "wt")
    testthat::expect_identical(maidr:::lattice_label_text(p$xlab, p$xlab.default), "wt")
  }

  # histogram() stores its y title as TRUE and names the default after the
  # kind of histogram drawn.
  for (type in c("percent", "count", "density")) {
    p <- lattice::histogram(~mpg, mtcars, type = type)
    testthat::expect_true(isTRUE(p$ylab))
    drawn <- drawn_text(drawn_label(p, "ylab"))
    testthat::expect_true(drawn %in% c("Percent of Total", "Count", "Density"))
    testthat::expect_identical(maidr:::lattice_label_text(p$ylab, p$ylab.default), drawn)
  }
})

test_that("a category axis lattice leaves untitled reads as its variable", {
  # A horizontal barchart(), bwplot() or dotplot() draws no title on its
  # category axis. What the categories are is still worth saying, and the
  # variable is what lattice would have drawn there.
  skip_if_no_lattice()
  one_year <- lattice::barley[
    lattice::barley$site == "Morris" & lattice::barley$year == "1931",
  ]
  p <- lattice::barchart(variety ~ yield, one_year)

  testthat::expect_null(p$ylab)
  testthat::expect_null(drawn_label(p, "ylab"))
  testthat::expect_identical(maidr:::lattice_axis_label(p$ylab, p$ylab.default), "variety")
  # The value axis is titled, and reads as titled.
  testthat::expect_identical(drawn_text(drawn_label(p, "xlab")), "yield")
  testthat::expect_identical(maidr:::lattice_axis_label(p$xlab, p$xlab.default), "yield")

  for (chart in list(
    lattice::bwplot(factor(cyl) ~ mpg, mtcars),
    lattice::dotplot(factor(cyl) ~ mpg, mtcars)
  )) {
    testthat::expect_null(drawn_label(chart, "ylab"))
    testthat::expect_identical(
      maidr:::lattice_axis_label(chart$ylab, chart$ylab.default),
      "factor(cyl)"
    )
  }

  # A title the chart does draw wins.
  p <- lattice::barchart(variety ~ yield, one_year, ylab = "Barley variety")
  testthat::expect_identical(drawn_text(drawn_label(p, "ylab")), "Barley variety")
  testthat::expect_identical(
    maidr:::lattice_axis_label(p$ylab, p$ylab.default),
    "Barley variety"
  )
})

# ------------------------------------------------------------------------------
# Layout and pages
# ------------------------------------------------------------------------------

#' Trellis objects laid out every way lattice allows, on one page or several
layout_cases <- function() {
  m <- mtcars
  m$cyl <- factor(m$cyl)
  m$gear <- factor(m$gear)
  m$am <- factor(m$am)
  m$carb <- factor(m$carb)
  one <- lattice::xyplot(mpg ~ wt | cyl, m)
  two <- lattice::xyplot(mpg ~ wt | cyl + gear, m)
  three <- lattice::xyplot(mpg ~ wt | cyl + am + gear, m)
  six <- lattice::xyplot(mpg ~ wt | carb, m)
  list(
    one_default = one,
    two_default = two,
    # A third conditioning variable is laid out a page per level.
    three_default = three,
    six_default = six,
    six_2x2 = update(six, layout = c(2, 2)),
    one_1x1 = update(one, layout = c(1, 1)),
    six_NAx2 = update(six, layout = c(NA, 2)),
    six_3xNA = update(six, layout = c(3, NA)),
    # 0 columns leaves the arrangement to the device's aspect ratio.
    six_0x4 = update(six, layout = c(0, 4)),
    two_0x2 = update(two, layout = c(0, 2)),
    # More pages than panels need: the last is drawn empty.
    one_3x1x2 = update(one, layout = c(3, 1, 2)),
    six_2x1x1 = update(six, layout = c(2, 1, 1)),
    six_2x1 = update(six, layout = c(2, 1)),
    two_6x1 = update(two, layout = c(6, 1)),
    two_1x6 = update(two, layout = c(1, 6)),
    six_skip = update(six, layout = c(2, 2), skip = c(FALSE, TRUE)),
    one_skip = update(one, skip = c(TRUE, FALSE)),
    two_skip = update(two, skip = c(FALSE, FALSE, TRUE)),
    two_perm = update(two, perm.cond = 2:1),
    two_index = update(two, index.cond = list(c(3, 1, 2), 2:1)),
    two_subset = two[2:3, ],
    six_subset = six[c(1, 3, 5)],
    two_transposed = t(two),
    six_as_table = update(six, layout = c(4, 1), as.table = TRUE)
  )
}

test_that("the layout is lattice's own for every way one is asked for", {
  skip_if_no_lattice()
  testthat::skip_if_not(
    exists("compute.layout", envir = asNamespace("lattice"), inherits = FALSE),
    "lattice no longer has compute.layout()"
  )
  compute_layout <- get("compute.layout", envir = asNamespace("lattice"))

  for (name in names(layout_cases())) {
    p <- layout_cases()[[name]]
    # What plot.trellis() hands compute.layout(): the number of levels of
    # each variable it shows, in the order it shows the variables.
    shown <- lengths(p$index.cond)[p$perm.cond]
    theirs <- suppressWarnings(compute_layout(p$layout, shown, p$skip))

    ours <- maidr:::lattice_layout(p)
    testthat::expect_equal(ours, theirs, label = paste(name, "layout"))
    # And the page count is the number of pages lattice actually draws.
    testthat::expect_equal(ours[3], length(drawn_pages(p)), label = paste(name, "pages"))
  }
})

test_that("the first page of a chart is the page lattice draws first", {
  skip_if_no_lattice()
  cases <- layout_cases()
  multi_page <- 0L

  for (name in names(cases)) {
    p <- cases[[name]]
    pages <- drawn_pages(p)
    first <- maidr:::lattice_first_page(p)

    testthat::expect_equal(attr(first, "maidr_pages"), length(pages), label = name)
    # Exactly one page, holding the packets in the cells lattice's own
    # first page put them in.
    testthat::expect_identical(drawn_pages(first), pages[1], label = name)
    if (length(pages) > 1L) {
      multi_page <- multi_page + 1L
      testthat::expect_equal(first$layout[3], 1, label = name)
    } else {
      # A chart already on one page is left as it was.
      testthat::expect_identical(first$layout, p$layout, label = name)
    }
  }
  testthat::expect_gte(multi_page, 5L)
})

# ------------------------------------------------------------------------------
# Packets, strips and groups
# ------------------------------------------------------------------------------

#' The packet in every cell of a drawing, with the text of every strip
drawn_cells <- function(plot, prefix = "st") {
  with_native_drawing(plot, function() {
    listing <- drawn_listing()
    strips <- listing$name[grepl(paste0("^", prefix, "\\.text[lr]\\."), listing$name)]
    list(
      packets = lattice::trellis.currentLayout("packet", prefix = prefix),
      strips = vapply(strips, function(name) {
        paste(as.character(grid::grid.get(name)$label), collapse = " ")
      }, character(1))
    )
  }, prefix = prefix)
}

test_that("a packet is titled by its levels, as lattice's strips name them", {
  skip_if_no_lattice()
  m <- mtcars
  m$am <- factor(m$am, labels = c("automatic", "manual"))

  one <- lattice::xyplot(mpg ~ wt | factor(cyl), m)
  cells <- drawn_cells(one)
  titled <- 0L
  for (row in seq_len(nrow(cells$packets))) {
    for (column in seq_len(ncol(cells$packets))) {
      packet <- cells$packets[row, column]
      # The square throwaway device lays three panels out two by two.
      if (packet == 0) {
        next
      }
      strip <- cells$strips[[sprintf("st.textr.strip.%d.%d", column, row)]]
      testthat::expect_identical(maidr:::lattice_packet_label(one, packet), strip)
      titled <- titled + 1L
    }
  }
  testthat::expect_identical(titled, 3L)

  # Two variables are joined in formula order, however they are laid out:
  # lattice numbers each strip by the variable it shows (`given.<i>`), and
  # `perm.cond` draws them the other way up.
  for (p in list(
    lattice::xyplot(mpg ~ wt | factor(cyl) + am, m),
    lattice::xyplot(mpg ~ wt | factor(cyl) + am, m, perm.cond = 2:1)
  )) {
    cells <- drawn_cells(p)
    titled <- 0L
    for (row in seq_len(nrow(cells$packets))) {
      for (column in seq_len(ncol(cells$packets))) {
        packet <- cells$packets[row, column]
        strip <- function(i) {
          cells$strips[[sprintf("st.textr.given.%d.strip.%d.%d", i, column, row)]]
        }
        levels <- as.vector(arrayInd(packet, lengths(p$condlevels)))
        testthat::expect_identical(
          maidr:::lattice_packet_label(p, levels),
          paste(strip(1), strip(2), sep = " & ")
        )
        titled <- titled + 1L
      }
    }
    testthat::expect_identical(titled, 6L)
  }

  # An unconditioned chart draws no strip, and its one packet has no title.
  plain <- lattice::xyplot(mpg ~ wt, m)
  testthat::expect_length(drawn_cells(plain)$strips, 0L)
  testthat::expect_identical(maidr:::lattice_packet_label(plain, 1L), "")
})

test_that("a strip.custom() strip's labels title its packets, as lattice draws them", {
  # `factor.levels` replaces the levels on every conditioning variable's
  # strip, and a reader should hear the strip a sighted reader sees.
  skip_if_no_lattice()
  for (p in list(
    lattice::xyplot(mpg ~ wt | factor(am), mtcars,
      strip = lattice::strip.custom(factor.levels = c("automatic", "manual"))
    ),
    lattice::xyplot(mpg ~ wt | factor(am) + factor(vs), mtcars,
      perm.cond = 2:1, strip = lattice::strip.custom(factor.levels = c("no", "yes"))
    )
  )) {
    cells <- drawn_cells(p)
    n <- length(p$condlevels)
    titled <- 0L
    for (row in seq_len(nrow(cells$packets))) {
      for (column in seq_len(ncol(cells$packets))) {
        packet <- cells$packets[row, column]
        if (packet == 0) {
          next
        }
        strips <- vapply(seq_len(n), function(i) {
          name <- if (n == 1L) {
            sprintf("st.textr.strip.%d.%d", column, row)
          } else {
            sprintf("st.textr.given.%d.strip.%d.%d", i, column, row)
          }
          cells$strips[[name]]
        }, character(1))
        levels <- as.vector(arrayInd(packet, lengths(p$condlevels)))
        testthat::expect_identical(
          maidr:::lattice_packet_label(p, levels),
          paste(strips, collapse = " & ")
        )
        titled <- titled + 1L
      }
    }
    testthat::expect_identical(titled, as.integer(prod(lengths(p$condlevels))))
  }
})

test_that("a strip that names its variable titles its packets with the name", {
  # `strip.names = TRUE` draws a factor's name before its level, across the
  # strip's `sep`, on the top strip or the left one alike; a sighted reader
  # sees "Cylinders : 4", and a reader should hear it.
  skip_if_no_lattice()
  m <- mtcars
  m$am <- factor(m$am, labels = c("automatic", "manual"))
  cases <- list(
    list(type = "strip", p = lattice::xyplot(mpg ~ wt | factor(cyl), m,
      strip = lattice::strip.custom(var.name = "Cylinders", strip.names = TRUE)
    )),
    list(type = "strip", p = lattice::xyplot(mpg ~ wt | factor(cyl) + am, m,
      perm.cond = 2:1, strip = lattice::strip.custom(strip.names = TRUE, sep = " = ")
    )),
    list(type = "strip.left", p = lattice::xyplot(mpg ~ wt | am, m,
      strip = FALSE, strip.left = lattice::strip.custom(strip.names = TRUE, style = 3)
    ))
  )
  for (case in cases) {
    p <- case$p
    n <- length(p$condlevels)
    drawn <- with_native_drawing(p, function() {
      listing <- drawn_listing()$name
      text <- function(name) {
        if (name %in% listing) paste(grid::grid.get(name)$label, collapse = " ") else ""
      }
      packets <- lattice::trellis.currentLayout("packet", prefix = "st")
      out <- character()
      for (row in seq_len(nrow(packets))) {
        for (column in seq_len(ncol(packets))) {
          if (packets[row, column] == 0) {
            next
          }
          out[packets[row, column]] <- paste(vapply(seq_len(n), function(i) {
            where <- sprintf("%s.%d.%d", case$type, column, row)
            if (n > 1L) where <- sprintf("given.%d.%s", i, where)
            paste0(
              text(paste0("st.textl.", where)), text(paste0("st.sep.", where)),
              text(paste0("st.textr.", where))
            )
          }, character(1)), collapse = " & ")
        }
      }
      out
    }, prefix = "st")
    testthat::expect_length(drawn, prod(lengths(p$condlevels)))
    for (packet in seq_along(drawn)) {
      levels <- as.vector(arrayInd(packet, lengths(p$condlevels)))
      testthat::expect_identical(maidr:::lattice_packet_label(p, levels), drawn[packet])
    }
  }
  testthat::expect_identical(
    maidr:::lattice_packet_label(cases[[1]]$p, 1L),
    "Cylinders : 4"
  )

  # Styles 2, 4 and 5 write the levels out by themselves, name or no name.
  p <- lattice::xyplot(mpg ~ wt | factor(cyl), m,
    strip = lattice::strip.custom(strip.names = TRUE, style = 2)
  )
  testthat::expect_identical(maidr:::lattice_packet_label(p, 1L), "4")
})

test_that("an auto.key's text names the groups it labels", {
  skip_if_no_lattice()
  key_text <- function(p) {
    with_native_drawing(p, function() {
      names <- grep("^chk\\.key\\.text\\.", drawn_listing()$name, value = TRUE)
      vapply(names, function(name) grid::grid.get(name)$label, character(1), USE.NAMES = FALSE)
    })
  }
  p <- lattice::xyplot(mpg ~ wt, mtcars,
    groups = cyl, auto.key = list(text = c("four", "six", "eight"))
  )
  testthat::expect_identical(key_text(p), c("four", "six", "eight"))
  testthat::expect_identical(maidr:::lattice_group_names(p), c("four", "six", "eight"))
  # The levels still number the groups the grobs are drawn for.
  testthat::expect_identical(maidr:::lattice_group_levels(p), c("4", "6", "8"))
  names <- vapply(lattice_rendered_layers(render_lattice(p)), function(l) l$name, character(1))
  testthat::expect_identical(names, c("four", "six", "eight"))

  # A key the user drew is not tied to the groups, and names none.
  keyed <- lattice::xyplot(mpg ~ wt, mtcars,
    groups = cyl, key = list(text = list(c("x", "y", "z")), points = list(pch = 1))
  )
  testthat::expect_identical(maidr:::lattice_group_names(keyed), c("4", "6", "8"))
})

test_that("a shingle's packet is titled by its variable and its interval", {
  # lattice draws a shingle's strip as the variable's name over a shaded
  # interval, so the interval has to be said in words.
  skip_if_no_lattice()
  p <- lattice::xyplot(mpg ~ wt | lattice::equal.count(wt, 3), mtcars)
  intervals <- levels(lattice::equal.count(mtcars$wt, 3))
  cells <- drawn_cells(p)

  for (row in seq_len(nrow(cells$packets))) {
    for (column in seq_len(ncol(cells$packets))) {
      packet <- cells$packets[row, column]
      if (packet == 0) {
        next
      }
      label <- maidr:::lattice_packet_label(p, packet)
      name <- cells$strips[[sprintf("st.textl.strip.%d.%d", column, row)]]
      testthat::expect_identical(name, "lattice::equal.count(wt, 3)")
      testthat::expect_true(startsWith(label, paste0(name, " ")))

      bounds <- as.numeric(regmatches(
        substring(label, nchar(name) + 2L),
        gregexpr("-?[0-9]+(\\.[0-9]+)?", substring(label, nchar(name) + 2L))
      )[[1]])
      testthat::expect_equal(bounds, intervals[[packet]], tolerance = 1e-4)
      # The interval named is the one the packet's points were drawn from.
      x <- p$panel.args[[packet]]$x
      testthat::expect_true(all(x >= bounds[1] - 1e-4 & x <= bounds[2] + 1e-4))
    }
  }
})

test_that("a group's number indexes the level lattice drew it for", {
  skip_if_no_lattice()
  d <- data.frame(
    x = 1:8,
    y = c(2, 4, 3, 5, 6, 1, 7, 8),
    g = factor(c("a", "a", "c", "c", "d", "d", "c", "a"), levels = c("a", "b", "c", "d"))
  )
  p <- lattice::xyplot(y ~ x, d, groups = g)
  levels <- maidr:::lattice_group_levels(p)
  testthat::expect_identical(levels, c("a", "b", "c", "d"))

  # The unused level "b" keeps its number: lattice draws groups 1, 3 and 4,
  # and each grob holds exactly the points of the level it indexes.
  drawn <- with_native_drawing(p, function() {
    names <- grep("^chk\\.xyplot\\.points\\.group\\.", drawn_listing()$name, value = TRUE)
    stats::setNames(lapply(names, drawn_points), names)
  })
  numbers <- as.integer(sub(".*\\.group\\.([0-9]+)\\..*", "\\1", names(drawn)))
  testthat::expect_identical(numbers, c(1L, 3L, 4L))
  for (i in seq_along(drawn)) {
    testthat::expect_equal(drawn[[i]]$x, d$x[d$g == levels[numbers[i]]])
  }

  # A numeric grouping is numbered over its sorted values, across panels: a
  # panel missing a value skips its number.
  p <- lattice::xyplot(mpg ~ wt | factor(am), mtcars, groups = gear)
  levels <- maidr:::lattice_group_levels(p)
  testthat::expect_identical(levels, c("3", "4", "5"))
  drawn <- with_native_drawing(p, function() {
    names <- grep("^chk\\.xyplot\\.points\\.group\\.", drawn_listing()$name, value = TRUE)
    stats::setNames(lapply(names, drawn_points), names)
  })
  testthat::expect_setequal(
    names(drawn),
    c(
      "chk.xyplot.points.group.1.panel.1.1", "chk.xyplot.points.group.2.panel.1.1",
      "chk.xyplot.points.group.2.panel.2.1", "chk.xyplot.points.group.3.panel.2.1"
    )
  )
  for (name in names(drawn)) {
    number <- as.integer(sub(".*\\.group\\.([0-9]+)\\..*", "\\1", name))
    am <- as.integer(sub(".*\\.panel\\.([0-9]+)\\..*", "\\1", name)) - 1L
    rows <- mtcars$am == am & mtcars$gear == as.numeric(levels[number])
    testthat::expect_equal(drawn[[name]]$x, mtcars$wt[rows])
  }

  testthat::expect_null(maidr:::lattice_group_levels(lattice::xyplot(mpg ~ wt, mtcars)))
})

test_that("a grouping is titled by its key's title, or by what it was grouped by", {
  skip_if_no_lattice()
  key_title <- function(p) {
    with_native_drawing(p, function() {
      if ("chk.key.title" %in% drawn_listing()$name) grid::grid.get("chk.key.title")$label else NULL
    })
  }

  auto <- lattice::xyplot(mpg ~ wt, mtcars, groups = cyl, auto.key = list(title = "Cylinders"))
  testthat::expect_identical(key_title(auto), "Cylinders")
  testthat::expect_identical(maidr:::lattice_group_title(auto), "Cylinders")

  keyed <- lattice::xyplot(
    mpg ~ wt, mtcars,
    groups = cyl,
    key = list(title = "Engine", text = list(c("4", "6", "8")), points = list(pch = 1))
  )
  testthat::expect_identical(key_title(keyed), "Engine")
  testthat::expect_identical(maidr:::lattice_group_title(keyed), "Engine")

  # A key without a title leaves the grouping named as it was written.
  untitled <- lattice::xyplot(mpg ~ wt, mtcars, groups = factor(gear), auto.key = TRUE)
  testthat::expect_null(key_title(untitled))
  testthat::expect_identical(maidr:::lattice_group_title(untitled), "factor(gear)")
  testthat::expect_identical(
    maidr:::lattice_group_title(lattice::xyplot(mpg ~ wt, mtcars, groups = cyl)),
    "cyl"
  )

  # A grouping handed over as values has no name to give.
  valued <- do.call(lattice::xyplot, list(mpg ~ wt, data = mtcars, groups = mtcars$cyl))
  testthat::expect_null(maidr:::lattice_group_title(valued))
  testthat::expect_null(maidr:::lattice_group_title(lattice::xyplot(mpg ~ wt, mtcars)))
})

test_that("a log axis is read back on the data's own scale", {
  skip_if_no_lattice()
  d <- data.frame(x = c(1, 3, 10, 30, 100), y = c(2, 5, 7, 11, 13))
  logs <- list(
    list(log = TRUE, apply = log10),
    list(log = 10, apply = log10),
    list(log = "e", apply = log),
    list(log = 2, apply = log2),
    list(log = FALSE, apply = identity)
  )

  for (case in logs) {
    p <- lattice::xyplot(y ~ x, d, scales = list(x = list(log = case$log)))
    # lattice draws the points in log units, as the reading receives them.
    drawn <- with_native_drawing(p, function() drawn_points("chk.xyplot.points.panel.1.1"))
    testthat::expect_equal(drawn$x, case$apply(d$x))
    testthat::expect_equal(maidr:::lattice_untransform(drawn$x, p$x.scales$log), d$x)
    # The other axis is linear, and passes through.
    testthat::expect_equal(maidr:::lattice_untransform(drawn$y, p$y.scales$log), d$y)
  }

  testthat::expect_equal(maidr:::lattice_untransform(c(1, 2), NULL), c(1, 2))
})

# ------------------------------------------------------------------------------
# Grob names and selectors
# ------------------------------------------------------------------------------

test_that("a grob name lattice builds is parsed back into its parts", {
  skip_if_no_lattice()
  # lattice::trellis.grobname() is how lattice names what it draws.
  cases <- list(
    list(what = "xyplot.points", group = 0, column = 1, row = 1),
    list(what = "xyplot.points", group = 3, column = 2, row = 1),
    list(what = "barchart.pos.10.rect", group = 0, column = 3, row = 2),
    list(what = "density rug.x", group = 0, column = 1, row = 12),
    list(what = "levelplot.line.4.lines", group = 0, column = 10, row = 1),
    list(what = "loess.lines", group = 12, column = 1, row = 1)
  )
  for (case in cases) {
    name <- lattice::trellis.grobname(
      case$what,
      type = "panel", group = case$group,
      column = case$column, row = case$row, prefix = "maidr"
    )
    parsed <- maidr:::lattice_parse_grob_name(name)
    testthat::expect_identical(parsed$name, name)
    testthat::expect_identical(parsed$what, case$what)
    testthat::expect_identical(
      parsed$group,
      if (case$group == 0) NA_integer_ else as.integer(case$group)
    )
    testthat::expect_identical(parsed$column, as.integer(case$column))
    testthat::expect_identical(parsed$row, as.integer(case$row))
  }

  # One row per name, in order, with NA for what is not a panel grob of this
  # prefix. The prefix's dots are literal.
  parsed <- maidr:::lattice_parse_grob_name(
    c(
      "maidr.xyplot.points.panel.1.1", "GRID.text.12",
      "plot_01.xyplot.points.panel.1.1", "maidrXxyplot.points.panel.1.1"
    )
  )
  testthat::expect_identical(parsed$what, c("xyplot.points", NA, NA, NA))
  testthat::expect_identical(parsed$column, c(1L, NA, NA, NA))
  parsed <- maidr:::lattice_parse_grob_name("a.b.xyplot.points.panel.2.3", prefix = "a.b")
  testthat::expect_identical(parsed$what, "xyplot.points")
  testthat::expect_identical(
    maidr:::lattice_parse_grob_name("aXb.xyplot.points.panel.2.3", prefix = "a.b")$what,
    NA_character_
  )
})

test_that("every grob lattice draws in a panel is parsed as drawn in that panel", {
  skip_if_no_lattice()
  charts <- list(
    lattice::xyplot(mpg ~ wt | factor(cyl), mtcars, groups = am, type = c("p", "r")),
    lattice::barchart(yield ~ variety | site, lattice::barley, groups = year, layout = c(3, 2)),
    lattice::densityplot(~ mpg | factor(am), mtcars, plot.points = "rug")
  )

  for (chart in charts) {
    listing <- maidr:::lattice_draw_scene(chart)$listing
    listing <- listing[listing$type == "grobListing", , drop = FALSE]
    cell <- regmatches(
      listing$vpPath,
      regexec("::maidr\\.panel\\.([0-9]+)\\.([0-9]+)\\.vp$", listing$vpPath)
    )
    in_panel <- lengths(cell) > 0L
    testthat::expect_gt(sum(in_panel), 0L)

    parsed <- maidr:::lattice_parse_grob_name(listing$name[in_panel])
    testthat::expect_false(anyNA(parsed$what))
    testthat::expect_identical(parsed$column, as.integer(vapply(cell[in_panel], `[`, "", 2L)))
    testthat::expect_identical(parsed$row, as.integer(vapply(cell[in_panel], `[`, "", 3L)))
  }
})

test_that("a grob's id is escaped so a selector reaches it, spaces and all", {
  skip_if_no_lattice()
  # The exporter writes a grob named N as `<g id="N.1">`, raw; lattice names
  # a density's rug `density rug.x`, with a space a selector would read as a
  # descendant combinator.
  name <- "maidr.density rug.x.panel.1.1"
  testthat::expect_identical(
    maidr:::lattice_css_id(name),
    "maidr\\.density\\ rug\\.x\\.panel\\.1\\.1\\.1"
  )
  # Every character outside [A-Za-z0-9_-] is escaped, and CSS reads an
  # escaped character as itself.
  odd <- "a b.c:d/e#f[g]h>i,j'k\"l"
  escaped <- maidr:::lattice_css_id(odd)
  testthat::expect_false(grepl("(^|[^\\\\])[^A-Za-z0-9_\\\\-]", escaped))
  testthat::expect_identical(gsub("\\\\(.)", "\\1", escaped), paste0(odd, ".1"))

  x <- c(1.2, 2.5, 2.9, 3.3, 4.8, 5.1, 6.0)
  rendered <- render_lattice(lattice::densityplot(~x, plot.points = "rug"))
  testthat::expect_false(rendered$fallback)
  group <- xml2::xml_find_all(rendered$doc, sprintf("//*[@id='%s.1']", name))
  testthat::expect_length(group, 1L)

  # The rug is a segment per observation, in the order of the data.
  marks <- lattice_selector_nodes(rendered$doc, maidr:::lattice_grob_selector(name, "polyline"))
  testthat::expect_length(marks, length(x))
  mark_x <- vapply(xml2::xml_attr(marks, "points"), function(points) {
    as.numeric(strsplit(strsplit(points, " ")[[1]][1], ",")[[1]][1])
  }, numeric(1), USE.NAMES = FALSE)
  testthat::expect_identical(order(mark_x), order(x))
  fit <- stats::lm(mark_x ~ x)
  testthat::expect_lt(max(abs(stats::residuals(fit))), 0.05)

  # One shape by its position among them.
  third <- lattice_selector_nodes(rendered$doc, maidr:::lattice_shape_selector(name, 3))
  testthat::expect_length(third, 1L)
  testthat::expect_identical(xml2::xml_attr(third, "id"), xml2::xml_attr(marks[[3]], "id"))

  # The rug is drawn under the curve and is not read; the curve's own
  # selector reaches the one line it is drawn as.
  layers <- lattice_rendered_layers(rendered)
  testthat::expect_identical(layer_types(layers), "smooth")
  testthat::expect_identical(lattice_selector_counts(rendered$doc, layers[[1]]$selectors), 1L)
})

# ------------------------------------------------------------------------------
# Drawing
# ------------------------------------------------------------------------------

test_that("a split stored on the chart does not squeeze the chart the system draws", {
  # `plot.trellis()` takes any layout argument it is not given from the
  # object's `plot.args`, which `update()` can set. Drawn natively, this
  # chart takes the left half of the page; drawn by the lattice system it
  # takes the whole of it, as the same chart without the split does.
  skip_if_no_lattice()
  p <- lattice::xyplot(mpg ~ wt, mtcars)
  split <- update(p, plot.args = list(split = c(1, 1, 2, 1)))
  testthat::expect_identical(split$plot.args$split, c(1, 1, 2, 1))

  panel_right_edge <- function(draw) {
    grDevices::pdf(NULL, width = 7, height = 5)
    on.exit(grDevices::dev.off(), add = TRUE)
    draw()
    grid::seekViewport("chk.panel.1.1.vp")
    as.numeric(grid::deviceLoc(grid::unit(1, "npc"), grid::unit(1, "npc"))$x)
  }
  natively <- panel_right_edge(function() plot_trellis_natively(split, prefix = "chk"))
  read <- panel_right_edge(function() maidr:::lattice_draw(split, prefix = "chk"))
  unsplit <- panel_right_edge(function() maidr:::lattice_draw(p, prefix = "chk"))

  testthat::expect_lt(natively, 3.5)
  testthat::expect_equal(read, unsplit)
  testthat::expect_gt(read, 3.5)
})

test_that("a packet.panel given to print() or stored on the chart chooses the packets read", {
  # `?packet.panel.default`'s own example: print(p, packet.panel =
  # packet.panel.page(2)) prints the second page of a chart laid out six
  # panels to a page, and `plot.trellis()` honours one stored in
  # `plot.args` the same way. The packets read are the ones lattice draws.
  skip_if_no_lattice()
  page <- function(n) function(layout, page, ...) {
    stopifnot(layout[3] == 1)
    lattice::packet.panel.default(layout = layout, page = n, ...)
  }
  horsepower <- lattice::equal.count(mtcars$hp, 6)
  p <- lattice::xyplot(mpg ~ disp | horsepower * factor(cyl), mtcars, layout = c(0, 6, 1))
  native <- function(chart, ...) {
    grDevices::pdf(NULL)
    on.exit(grDevices::dev.off(), add = TRUE)
    plot_trellis_natively(chart, prefix = "chk", ...)
    packets <- lattice::trellis.currentLayout("packet", prefix = "chk")
    sort(packets[packets > 0])
  }
  read <- function(orchestrator) {
    titles <- unlist(lapply(orchestrator$get_combined_data(), function(row) {
      lapply(row, function(cell) vapply(cell$layers, `[[`, "", "title"))
    }))
    unique(sub(".* & ", "", titles))
  }
  cyl_of <- function(packets) {
    unique(p$condlevels[[2]][arrayInd(packets, lengths(p$condlevels))[, 2]])
  }

  stored <- update(p, plot.args = list(packet.panel = page(2)))
  testthat::expect_identical(cyl_of(native(stored)), "6")
  testthat::expect_identical(read(maidr:::LatticePlotOrchestrator$new(stored)), "6")

  testthat::expect_identical(cyl_of(native(p, packet.panel = page(3))), "8")
  shown <- NULL
  testthat::with_mocked_bindings(
    {
      maidr:::maidr_print_trellis(p, packet.panel = page(3))
    },
    lattice_print_opens_viewer = function(...) TRUE,
    display_html = function(html) shown <<- paste(as.character(html), collapse = "\n"),
    .package = "maidr"
  )
  svg <- xml2::xml_find_first(xml2::read_html(shown), "//svg[@maidr-data]")
  schema <- jsonlite::fromJSON(xml2::xml_attr(svg, "maidr-data"), simplifyVector = FALSE)
  titles <- unlist(lapply(schema$subplots, function(row) {
    lapply(row, function(cell) vapply(cell$layers, `[[`, "", "title"))
  }))
  testthat::expect_identical(unique(sub(".* & ", "", titles)), "8")
})

# ------------------------------------------------------------------------------
# The audit after drawing
# ------------------------------------------------------------------------------

test_that("stock charts draw nothing in their panels the audit refuses", {
  # The audit is only worth having if it leaves a chart the system reads
  # alone. Swept over the arguments that change what the stock panel
  # functions draw.
  skip_if_no_lattice()
  adapter <- maidr:::get_global_registry()$get_adapter("lattice")
  sorted <- mtcars[order(mtcars$wt), ]
  charts <- list(
    lattice::xyplot(mpg ~ wt, sorted, type = c("p", "l", "g", "r")),
    lattice::xyplot(mpg ~ wt, sorted, type = "b", groups = cyl),
    lattice::xyplot(mpg ~ wt, sorted, type = c("s", "smooth")),
    lattice::xyplot(mpg ~ wt, sorted, type = c("S", "spline", "a")),
    lattice::xyplot(mpg ~ wt, sorted, type = "h", abline = list(h = 20), grid = TRUE),
    # A themed panel background is filled in the panel's own viewport.
    lattice::xyplot(
      mpg ~ wt, mtcars,
      par.settings = list(panel.background = list(col = "grey90"))
    ),
    lattice::barchart(VADeaths, origin = 0),
    lattice::barchart(VADeaths, stack = FALSE, horizontal = FALSE),
    lattice::histogram(~mpg, mtcars, type = "density"),
    lattice::densityplot(~mpg, mtcars, ref = TRUE),
    lattice::densityplot(~mpg, mtcars, groups = am, plot.points = "rug"),
    lattice::densityplot(~mpg, mtcars, plot.points = "jitter"),
    lattice::dotplot(VADeaths, type = c("p", "l")),
    lattice::dotplot(factor(cyl) ~ mpg, mtcars),
    lattice::stripplot(factor(cyl) ~ mpg, mtcars, jitter.data = TRUE),
    lattice::stripplot(factor(cyl) ~ mpg, mtcars, groups = am),
    lattice::bwplot(factor(cyl) ~ mpg, mtcars),
    lattice::bwplot(mpg ~ factor(cyl), mtcars, pch = "|"),
    lattice::levelplot(volcano, contour = TRUE),
    lattice::contourplot(volcano),
    lattice::qqmath(~mpg, mtcars, type = c("p", "l", "g")),
    lattice::qqmath(~mpg, mtcars, groups = am),
    lattice::qq(factor(am) ~ mpg, mtcars),
    # stripplot(), dotplot(), qqmath() and qq() hand `type`, `abline` and
    # `grid` on to panel.xyplot(); a grouped panel draws the reference line
    # once per group.
    lattice::stripplot(factor(cyl) ~ mpg, mtcars, type = c("p", "a"), abline = list(v = 20)),
    lattice::stripplot(mpg ~ factor(cyl), mtcars, groups = am, type = c("p", "l", "r", "h")),
    lattice::dotplot(factor(cyl) ~ mpg, mtcars, type = c("p", "a"), abline = c(0, 1)),
    lattice::dotplot(VADeaths, type = c("p", "h")),
    lattice::qqmath(~mpg, mtcars, type = c("p", "h", "r", "smooth", "a")),
    lattice::qqmath(~mpg, mtcars, groups = am, type = c("p", "spline"), abline = c(20, 5)),
    lattice::qq(factor(am) ~ mpg, mtcars, type = c("p", "l", "r", "h"), abline = c(0, 1))
  )

  for (chart in charts) {
    entries <- panel_entries(chart)$entries
    testthat::expect_gt(nrow(entries), 0L)
    testthat::expect_identical(entries$name[entries$role == "unknown"], character(0))
    testthat::expect_identical(maidr:::lattice_panel_audit(entries), character(0))
  }
})

test_that("a grob renamed with identifier = is refused as one the reading does not know", {
  skip_if_no_lattice()
  p <- lattice::xyplot(mpg ~ wt, mtcars, identifier = "foo")
  testthat::expect_identical(maidr:::lattice_static_check(p), character(0))

  drawn <- panel_entries(p)
  in_panel <- grepl("::maidr\\.panel\\.1\\.1\\.vp$", drawn$scene$listing$vpPath)
  testthat::expect_true("maidr.foo.points.panel.1.1" %in% drawn$scene$listing$name[in_panel])
  testthat::expect_identical(
    maidr:::lattice_panel_audit(drawn$entries),
    "a panel draws maidr.foo.points.panel.1.1, which is not read"
  )

  orchestrator <- maidr:::LatticeAdapter$new()$create_orchestrator(p)
  testthat::expect_identical(
    orchestrator$unsupported_reasons(),
    "a panel draws maidr.foo.points.panel.1.1, which is not read"
  )
  testthat::expect_true(orchestrator$has_unsupported_layers())
})

test_that("a grob drawn twice in one panel is refused", {
  # latticeExtra's as.layer() draws a second chart's points into the first
  # chart's panel under the same name. The static check refuses it first;
  # were it drawn, the audit would still, since the selectors could not
  # tell the two apart.
  skip_if_no_lattice()
  testthat::skip_if_not_installed("latticeExtra")
  # The panels are given as lattice's own function rather than by name:
  # latticeExtra calls a panel named by a string from the global
  # environment, where lattice is not attached during the tests.
  stock <- lattice::xyplot(mpg ~ wt, mtcars, panel = lattice::panel.xyplot)
  second <- lattice::xyplot(hp / 10 ~ wt, mtcars, panel = lattice::panel.xyplot)
  overlaid <- stock + latticeExtra::as.layer(second)
  testthat::expect_true(
    "latticeExtra layers were added" %in% maidr:::lattice_static_check(overlaid)
  )

  # Classified as the stock panel's grobs would be, both are known points,
  # and the duplicate is the only thing left to go on.
  drawn <- panel_entries(overlaid, classify_as = stock)
  in_panel <- grepl("::maidr\\.panel\\.1\\.1\\.vp$", drawn$scene$listing$vpPath)
  testthat::expect_identical(
    sum(drawn$scene$listing$name[in_panel] == "maidr.xyplot.points.panel.1.1"),
    2L
  )
  testthat::expect_identical(drawn$entries$role, c("points", "points"))
  testthat::expect_identical(
    maidr:::lattice_panel_audit(drawn$entries),
    "a panel draws maidr.xyplot.points.panel.1.1 more than once"
  )
})

test_that("a panel function's error falls back rather than being drawn as text", {
  # lattice draws a failing panel's error message where its marks would be.
  # The lattice system raises it instead, so the chart is shown as an image
  # rather than read with a panel missing.
  skip_if_no_lattice()
  d <- data.frame(x = c(1, 2, 3), y = c(3, 1, 2))
  p <- lattice::xyplot(y ~ x, d, type = "spline")
  testthat::expect_error(stats::smooth.spline(d$x, d$y), "four unique")

  written <- with_native_drawing(p, function() {
    listing <- drawn_listing()
    here <- grepl("::chk\\.panel\\.1\\.1\\.vp$", listing$vpPath)
    lapply(listing$name[here], function(name) grid::grid.get(name)$label)
  })
  testthat::expect_length(written, 1L)
  testthat::expect_match(written[[1]], "four unique")

  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  testthat::expect_error(maidr:::lattice_draw(p), "four unique")

  orchestrator <- maidr:::LatticeAdapter$new()$create_orchestrator(p)
  testthat::expect_identical(
    orchestrator$unsupported_reasons(),
    "drawing it failed: need at least four unique 'x' values"
  )
  testthat::expect_true(orchestrator$has_unsupported_layers())
})

# ------------------------------------------------------------------------------
# One panel's grobs, grouped into layers
# ------------------------------------------------------------------------------

#' A small grouped series: three groups of five, x sorted within each
grouped_series <- function() {
  data.frame(
    x = rep(1:5, 3),
    y = c(1, 3, 2, 5, 4, 2, 4, 3, 6, 5, 3, 5, 4, 7, 6),
    g = factor(rep(c("a", "b", "c"), each = 5))
  )
}

test_that("points are a layer per group and lines one layer of series, points first", {
  skip_if_no_lattice()
  d <- grouped_series()
  p <- lattice::xyplot(y ~ x, d, groups = g, type = "b")

  # lattice draws each group's points and then its line, group by group.
  drawn <- panel_entries(p)$entries
  testthat::expect_identical(
    drawn$name,
    sprintf(
      "maidr.xyplot.%s.group.%d.panel.1.1",
      rep(c("points", "lines"), 3), rep(1:3, each = 2)
    )
  )

  layers <- panel_layers(p)
  testthat::expect_identical(layer_types(layers), c("point", "point", "point", "line"))
  for (k in 1:3) {
    testthat::expect_identical(layer_groups(layers[[k]]), k)
  }
  testthat::expect_identical(layer_groups(layers[[4]]), 1:3)
})

test_that("each kind of fitted or averaged line is a layer of its own after the points", {
  skip_if_no_lattice()
  d <- grouped_series()

  testthat::expect_identical(
    layer_types(panel_layers(lattice::xyplot(y ~ x, d, type = c("p", "r")))),
    c("point", "smooth")
  )
  testthat::expect_identical(
    layer_types(panel_layers(lattice::xyplot(y ~ x, d, groups = g, type = c("p", "r")))),
    c("point", "point", "point", "smooth")
  )
  # An average line and a regression line are two curves, not one, in the
  # order lattice first draws them: each group's fit before its average.
  p <- lattice::xyplot(y ~ x, d, groups = g, type = c("a", "r"))
  testthat::expect_identical(
    panel_entries(p)$entries$what[1:2],
    c("lmline.segments", "linejoin.lines")
  )
  layers <- panel_layers(p)
  testthat::expect_identical(layer_types(layers), c("smooth", "line"))
  testthat::expect_identical(layer_groups(layers[[1]]), 1:3)
  testthat::expect_identical(layer_groups(layers[[2]]), 1:3)

  # Spikes, like points, are one layer per group.
  layers <- panel_layers(lattice::xyplot(y ~ x, d, groups = g, type = "h"))
  testthat::expect_identical(layer_types(layers), rep("lollipop", 3))
  testthat::expect_identical(lapply(layers, layer_groups), list(1L, 2L, 3L))
})

test_that("draws_steps is TRUE exactly when lattice draws a staircase", {
  # A staircase through n points is drawn through 2n - 1 vertices, a line
  # through n.
  skip_if_no_lattice()
  d <- grouped_series()[1:5, ]
  adapter <- maidr:::LatticeAdapter$new()
  types <- list("l", "s", "S", "b", "o", c("p", "s"), c("g", "S"), c("p", "l"))

  for (type in types) {
    p <- lattice::xyplot(y ~ x, d, type = type)
    vertices <- with_native_drawing(p, function() {
      length(grid::grid.get("chk.xyplot.lines.panel.1.1")$x)
    })
    testthat::expect_identical(
      adapter$draws_steps(lattice::trellis.panelArgs(p, 1), NA_integer_),
      vertices == 2L * nrow(d) - 1L,
      label = paste(type, collapse = ",")
    )
  }
  testthat::expect_false(adapter$draws_steps(list(), NA_integer_))
})

test_that("distribute.type draws each group with its own type, and each kind is its own layer", {
  # With `distribute.type = TRUE` group k is drawn with the k-th type,
  # recycled: here a staircase, a line, and a staircase again. A layer
  # mixing the two reads the line as a staircase -- every other point lost
  # -- or the staircase as a line, a sample gained at every riser.
  skip_if_no_lattice()
  d <- grouped_series()
  adapter <- maidr:::LatticeAdapter$new()
  p <- lattice::xyplot(y ~ x, d, groups = g, type = c("s", "l"), distribute.type = TRUE)
  args <- lattice::trellis.panelArgs(p, 1)

  vertices <- with_native_drawing(p, function() {
    vapply(1:3, function(k) {
      length(grid::grid.get(sprintf("chk.xyplot.lines.group.%d.panel.1.1", k))$x)
    }, integer(1))
  })
  testthat::expect_identical(vertices, c(9L, 5L, 9L))
  testthat::expect_identical(
    vapply(1:3, function(k) adapter$draws_steps(args, k), logical(1)),
    vertices == 9L
  )
  testthat::expect_identical(maidr:::lattice_group_type(args, 3L), "s")
  testthat::expect_identical(maidr:::lattice_group_type(args, NA_integer_), c("s", "l"))

  layers <- panel_layers(p)
  testthat::expect_identical(layer_types(layers), c("step", "line"))
  testthat::expect_identical(layer_groups(layers[[1]]), c(1L, 3L))
  testthat::expect_identical(layer_groups(layers[[2]]), 2L)

  # The two directions of staircase are drawn differently, and are layers
  # of their own too.
  p <- lattice::xyplot(y ~ x, d, groups = g, type = c("s", "S"), distribute.type = TRUE)
  layers <- panel_layers(p)
  testthat::expect_identical(layer_types(layers), c("step", "step"))
  testthat::expect_identical(lapply(layers, layer_groups), list(c(1L, 3L), 2L))

  # Points on one group, a line on the next: the points come first.
  p <- lattice::xyplot(y ~ x, d, groups = g, type = c("p", "l", "s"), distribute.type = TRUE)
  layers <- panel_layers(p)
  testthat::expect_identical(layer_types(layers), c("point", "line", "step"))
  testthat::expect_identical(lapply(layers, layer_groups), list(1L, 2L, 3L))
})

test_that("a distributed staircase and line are each read with their own samples", {
  skip_if_no_lattice()
  d <- grouped_series()
  p <- lattice::xyplot(y ~ x, d, groups = g, type = c("s", "l"), distribute.type = TRUE)
  rendered <- render_lattice(p)
  testthat::expect_false(rendered$fallback)
  layers <- lattice_rendered_layers(rendered)
  testthat::expect_identical(layer_types(layers), c("step", "line"))

  samples <- function(series) {
    data.frame(
      x = vapply(series, function(point) as.numeric(point$x), numeric(1)),
      y = vapply(series, function(point) as.numeric(point$y), numeric(1))
    )
  }
  # Every group is read as its own five observations, whichever kind of
  # line lattice drew it as.
  read <- c(layers[[1]]$data, layers[[2]]$data)
  groups <- c("a", "c", "b")
  for (i in seq_along(read)) {
    rows <- d[d$g == groups[i], ]
    testthat::expect_equal(
      samples(read[[i]]),
      data.frame(x = as.numeric(rows$x), y = rows$y)
    )
  }

  # Each series' selector reaches the one line that group was drawn as.
  counts <- lapply(layers, function(l) lattice_selector_counts(rendered$doc, l$selectors))
  testthat::expect_identical(counts, list(c(1L, 1L), 1L))
  drawn_in <- function(selector) {
    xml2::xml_attr(xml2::xml_parent(lattice_selector_nodes(rendered$doc, selector)), "id")
  }
  testthat::expect_identical(
    lapply(layers, function(l) vapply(l$selectors, drawn_in, character(1))),
    list(
      c("maidr.xyplot.lines.group.1.panel.1.1.1", "maidr.xyplot.lines.group.3.panel.1.1.1"),
      "maidr.xyplot.lines.group.2.panel.1.1.1"
    )
  )
})

test_that("distributed staircases of both directions each say their own direction", {
  # "s" runs along and then up, so its second vertex shares the first's y;
  # "S" runs up and then along, so its second vertex shares the first's x.
  skip_if_no_lattice()
  d <- grouped_series()
  p <- lattice::xyplot(y ~ x, d, groups = g, type = c("s", "S"), distribute.type = TRUE)
  rises_first <- with_native_drawing(p, function() {
    vapply(1:3, function(k) {
      corner <- drawn_points(sprintf("chk.xyplot.lines.group.%d.panel.1.1", k))[1:2, ]
      corner$x[1] == corner$x[2]
    }, logical(1))
  })
  testthat::expect_identical(rises_first, c(FALSE, TRUE, FALSE))

  rendered <- render_lattice(p)
  testthat::expect_false(rendered$fallback)
  layers <- lattice_rendered_layers(rendered)
  testthat::expect_identical(layer_types(layers), c("step", "step"))
  testthat::expect_identical(
    vapply(layers, function(l) l$stepDirection, character(1)),
    c("hv", "vh")
  )
  testthat::expect_identical(
    lapply(layers, function(l) lattice_selector_counts(rendered$doc, l$selectors)),
    list(c(1L, 1L), 1L)
  )
})

test_that("a dotplot is read as dots where no level holds two", {
  # Read off the drawn dots: a level's position on the category axis is
  # repeated exactly when it holds several values.
  skip_if_no_lattice()
  adapter <- maidr:::LatticeAdapter$new()
  one_year <- lattice::barley[
    lattice::barley$site == "Morris" & lattice::barley$year == "1931",
  ]
  repeats <- function(p, name, axis) {
    with_native_drawing(p, function() anyDuplicated(drawn_points(name)[[axis]]) > 0L)
  }
  one_dot_per_level <- function(p) {
    adapter$is_one_dot_per_level(lattice::trellis.panelArgs(p, 1), NA_integer_)
  }

  # One value per level, horizontal and vertical.
  p <- lattice::dotplot(variety ~ yield, one_year)
  testthat::expect_false(repeats(p, "chk.dotplot.points.panel.1.1", "y"))
  testthat::expect_true(one_dot_per_level(p))
  p <- lattice::dotplot(yield ~ variety, one_year, horizontal = FALSE)
  testthat::expect_false(repeats(p, "chk.dotplot.points.panel.1.1", "x"))
  testthat::expect_true(one_dot_per_level(p))

  # Several values per level.
  several <- lattice::dotplot(factor(cyl) ~ mpg, mtcars)
  testthat::expect_true(repeats(several, "chk.dotplot.points.panel.1.1", "y"))
  testthat::expect_false(one_dot_per_level(several))

  # Grouped: VADeaths draws one dot per age band in each column's group.
  p <- lattice::dotplot(VADeaths)
  args <- lattice::trellis.panelArgs(p, 1)
  for (k in seq_len(ncol(VADeaths))) {
    name <- sprintf("chk.xyplot.points.group.%d.panel.1.1", k)
    testthat::expect_false(repeats(p, name, "y"))
    testthat::expect_true(adapter$is_one_dot_per_level(args, k))
  }
  layers <- panel_layers(p)
  testthat::expect_identical(layer_types(layers), rep("dot", 4))
  testthat::expect_identical(lapply(layers, layer_groups), as.list(1:4))

  # And a dotplot with several values on a level is read as points.
  testthat::expect_identical(layer_types(panel_layers(several)), "point")
})

test_that("bar_type follows the bars lattice draws", {
  # panel.barchart() draws plain bars as one `barchart.rect`, grouped bars
  # side by side as `barchart.<x|y>.<k>.rect`, and stacked bars as
  # `barchart.<pos|neg>.<k>.rect`.
  skip_if_no_lattice()
  adapter <- maidr:::LatticeAdapter$new()
  morris <- lattice::barley[lattice::barley$site == "Morris", ]
  plain <- "^barchart\\.rect$"
  vertical_dodged <- "^barchart\\.x\\.[0-9]+\\.rect$"
  horizontal_dodged <- "^barchart\\.y\\.[0-9]+\\.rect$"
  stacked <- "^barchart\\.(pos|neg)\\.[0-9]+\\.rect$"
  cases <- list(
    list(
      p = lattice::barchart(variety ~ yield, morris, subset = year == "1931"),
      type = "bar", drawn = plain
    ),
    list(
      p = lattice::barchart(yield ~ variety, morris, groups = year),
      type = "dodged_bar", drawn = vertical_dodged
    ),
    list(
      p = lattice::barchart(variety ~ yield, morris, groups = year),
      type = "dodged_bar", drawn = horizontal_dodged
    ),
    list(
      p = lattice::barchart(yield ~ variety, morris, groups = year, stack = TRUE),
      type = "stacked_bar", drawn = stacked
    ),
    # The table method stacks unless told not to.
    list(p = lattice::barchart(VADeaths), type = "stacked_bar", drawn = stacked),
    list(
      p = lattice::barchart(VADeaths, stack = FALSE),
      type = "dodged_bar", drawn = horizontal_dodged
    )
  )

  for (case in cases) {
    what <- maidr:::lattice_parse_grob_name(panel_grob_names(case$p), prefix = "chk")$what
    # Leaving out the reference line lattice draws at the bars' origin.
    bars <- what[!grepl("^barchart\\.abline\\.[hv]$", what)]
    testthat::expect_gt(length(bars), 0L)
    testthat::expect_true(all(grepl(case$drawn, bars)), label = case$type)
    testthat::expect_identical(
      adapter$bar_type(lattice::trellis.panelArgs(case$p, 1)),
      case$type
    )
    testthat::expect_identical(layer_types(panel_layers(case$p)), case$type)
  }
})

test_that("detect_layer_type names a grob's role from its panel function's table", {
  skip_if_no_lattice()
  adapter <- maidr:::LatticeAdapter$new()
  xy <- lattice::xyplot(mpg ~ wt, mtcars)
  density <- lattice::densityplot(~mpg, mtcars)
  role <- function(what, plot) adapter$detect_layer_type(list(what = what), plot)

  testthat::expect_identical(role("xyplot.points", xy), "points")
  testthat::expect_identical(role("lmline.segments", xy), "fit")
  testthat::expect_identical(role("grid.h", xy), "decoration")
  testthat::expect_identical(role("density rug.x", density), "observations")
  # A name the panel function never draws, or one another draws.
  testthat::expect_identical(role("foo.points", xy), "unknown")
  testthat::expect_identical(role("density.lines", xy), "unknown")
  testthat::expect_identical(adapter$detect_layer_type(list(), xy), "unknown")
  # Nothing a custom panel function draws has a known role.
  custom <- lattice::xyplot(mpg ~ wt, mtcars, panel = function(...) lattice::panel.xyplot(...))
  testthat::expect_identical(role("xyplot.points", custom), "unknown")
})

test_that("lattice keeps the status record maidr reads where maidr reads it", {
  skip_if_no_lattice()
  # lattice_keep_status() and lattice_page_open() read lattice's record of
  # the chart it drew last, which has no exported accessor. Both do nothing
  # should it move, and what they look after would then change without a
  # word; this says so at once.
  status_env <- asNamespace("lattice")[[".LatticeEnv"]]
  testthat::expect_true(is.environment(status_env))
  testthat::expect_type(status_env[["lattice.status"]], "list")

  plot_trellis <- utils::getS3method("plot", "trellis")
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  p <- lattice::xyplot(mpg ~ wt, datasets::mtcars)

  # It is the record a chart drawn with more = TRUE leaves its page open in...
  plot_trellis(p, split = c(1, 1, 2, 1), more = TRUE)
  testthat::expect_true(maidr:::lattice_page_open())
  plot_trellis(p, split = c(2, 1, 2, 1))
  testthat::expect_false(maidr:::lattice_page_open())

  # ...and the one lattice_keep_status() puts back.
  restore <- maidr:::lattice_keep_status()
  plot_trellis(p, more = TRUE)
  testthat::expect_true(maidr:::lattice_page_open())
  restore()
  testthat::expect_false(maidr:::lattice_page_open())
})

test_that("a chart is drawn and read as before where lattice keeps no such record", {
  skip_if_no_lattice()
  # Should a lattice release move the record, or leave it empty, nothing is
  # put back, no page is taken to be open, and the chart is read all the same.
  for (moved in list(NULL, new.env(parent = emptyenv()))) {
    testthat::local_mocked_bindings(lattice_status_env = function() moved, .package = "maidr")
    restore <- maidr:::lattice_keep_status()
    testthat::expect_null(restore())
    testthat::expect_false(maidr:::lattice_page_open())
    r <- render_lattice(lattice::xyplot(mpg ~ wt, datasets::mtcars))
    testthat::expect_false(r$fallback)
    testthat::expect_identical(lattice_rendered_layers(r)[[1]]$type, "point")
  }
})
