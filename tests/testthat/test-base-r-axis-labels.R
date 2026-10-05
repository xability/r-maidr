# Axis titles for Base R charts drawn without xlab= / ylab=.
#
# Base R's high-level functions derive their axis titles inside the call and
# never record them, so the processors used to emit `label: ""` for every
# chart whose author wrote none, and the announcement lost its nouns:
# " is Apples,  is 30". The renderer now floors a blank label at the generic
# "X"/"Y", but a Base R chart usually knows something better than that, and
# saying it is the producer's job.
#
# These tests run the full render so they assert what actually ships in the
# maidr-data payload, not just what a processor returns in isolation. The rule
# throughout: only what the call establishes, an author's own label always
# wins, and an axis a processor cannot name is omitted rather than blanked --
# which leaves the generic to the renderer, where that decision belongs.

skip_slow_file_on_cran()

label_axes <- function(draw, cell = c(1L, 1L)) {
  lapply(maidr_layers(draw, cell), function(layer) layer$axes)
}

# The layers of one subplot of what save_html() writes for `draw`.
maidr_layers <- function(draw, cell = c(1L, 1L)) {
  testthat::skip_if_not_installed("jsonlite")

  maidr:::clear_all_device_storage()
  file <- tempfile(fileext = ".html")
  on.exit(
    {
      unlink(file)
      maidr:::clear_all_device_storage()
    },
    add = TRUE
  )

  grDevices::pdf(NULL)
  draw()
  save_html(file = file)
  grDevices::dev.off()

  html <- paste(readLines(file, warn = FALSE), collapse = "\n")
  attribute <- regmatches(html, regexpr('maidr-data="([^"]*)"', html))
  testthat::expect_length(attribute, 1)
  json <- sub('"$', "", sub('^maidr-data="', "", attribute))
  json <- gsub("&quot;", '"', json, fixed = TRUE)
  json <- gsub("&lt;", "<", json, fixed = TRUE)
  json <- gsub("&gt;", ">", json, fixed = TRUE)
  json <- gsub("&amp;", "&", json, fixed = TRUE)

  subplots <- jsonlite::fromJSON(json, simplifyVector = FALSE)$subplots
  subplots[[cell[[1L]]]][[cell[[2L]]]]$layers
}

# The titles R itself draws for `call`: the text of its own svglite drawing,
# less the tick labels, drawn with the functions maidr wraps unwrapped.
r_drawn_titles <- function(call) {
  testthat::skip_if_not_installed("svglite")
  testthat::skip_if_not_installed("xml2")
  old <- options(maidr.base_r = FALSE)
  on.exit(options(old), add = TRUE)
  file <- tempfile(fileext = ".svg")
  on.exit(unlink(file), add = TRUE)
  names <- c(
    "plot", "lines", "par", "hist", "title", "mtext", "stripchart", "axis",
    "image", "contour", "boxplot"
  )
  originals <- list2env(
    stats::setNames(lapply(names, maidr:::get_original_function), names),
    parent = globalenv()
  )
  svglite::svglite(file, width = 7, height = 5)
  tryCatch(eval(call, originals), finally = grDevices::dev.off())
  text <- trimws(xml2::xml_text(
    xml2::xml_find_all(xml2::read_xml(file), "//*[local-name()='text']")
  ))
  text[!grepl("^-?[0-9.]+$", text)]
}

# ==============================================================================
# Charts that plot categories against a measured value
# ==============================================================================

test_that("a pie names its slices and their magnitudes", {
  axes <- label_axes(function() pie(c(Apples = 30, Bananas = 50, Cherries = 20)))

  testthat::expect_equal(axes[[1]]$x$label, "Category")
  testthat::expect_equal(axes[[1]]$y$label, "Value")
})

test_that("a bar chart names its categories and their heights", {
  axes <- label_axes(function() barplot(c(A = 3, B = 5, C = 2)))

  testthat::expect_equal(axes[[1]]$x$label, "Category")
  testthat::expect_equal(axes[[1]]$y$label, "Value")
})

test_that("an unnamed bar chart is still a chart of categories", {
  # Without names the bars are announced by position, but the x axis is no
  # less categorical for it: barplot() never draws a measured x scale.
  axes <- label_axes(function() barplot(c(3, 5, 2)))

  testthat::expect_equal(axes[[1]]$x$label, "Category")
  testthat::expect_equal(axes[[1]]$y$label, "Value")
})

test_that("barplot(horiz = TRUE) swaps which axis holds the values", {
  # The points swap with the drawing, so the titles have to swap with them.
  axes <- label_axes(function() barplot(c(A = 3, B = 5), horiz = TRUE))

  testthat::expect_equal(axes[[1]]$x$label, "Value")
  testthat::expect_equal(axes[[1]]$y$label, "Category")
})

test_that("stacked and dodged bar charts name their two axes", {
  m <- matrix(c(1, 2, 3, 4), 2, dimnames = list(c("g1", "g2"), c("A", "B")))

  stacked <- label_axes(function() barplot(m))
  dodged <- label_axes(function() barplot(m, beside = TRUE))

  testthat::expect_equal(stacked[[1]]$x$label, "Category")
  testthat::expect_equal(stacked[[1]]$y$label, "Value")
  testthat::expect_equal(dodged[[1]]$x$label, "Category")
  testthat::expect_equal(dodged[[1]]$y$label, "Value")
})

test_that("an author's own bar chart labels win", {
  axes <- label_axes(function() {
    barplot(c(A = 3, B = 5), xlab = "Fruit", ylab = "Sales")
  })

  testthat::expect_equal(axes[[1]]$x$label, "Fruit")
  testthat::expect_equal(axes[[1]]$y$label, "Sales")
})

# ==============================================================================
# Histograms
# ==============================================================================

test_that("a histogram names its x axis as hist() writes it and repeats its y title", {
  # hist() titles the x axis after how `x` was written, and the recorded
  # call keeps that text beside the values.
  values <- c(1, 2, 2, 3, 3, 3, 4, 5)
  axes <- label_axes(function() hist(values))

  testthat::expect_equal(axes[[1]]$x$label, "values")
  testthat::expect_equal(axes[[1]]$y$label, "Frequency")
})

test_that("a histogram whose argument was written as no expression names its bins", {
  # do.call() writes the values themselves into the call, so there is no
  # text to name the axis after, and x says what it certainly holds.
  axes <- label_axes(function() do.call(hist, list(c(1, 2, 2, 3, 3, 3, 4, 5))))

  testthat::expect_equal(axes[[1]]$x$label, "Bin")
  testthat::expect_equal(axes[[1]]$y$label, "Frequency")
})

test_that("a density histogram is announced as a density", {
  # freq = FALSE plots densities, and extract_data() emits densities, so
  # "Frequency" would name a number that is not being announced.
  axes <- label_axes(function() hist(c(1, 2, 2, 3, 3, 3, 4, 5), freq = FALSE))

  testthat::expect_equal(axes[[1]]$y$label, "Density")
})

test_that("uneven breaks make a histogram a density one, as hist() decides", {
  # hist()'s own freq default is TRUE only for equidistant breaks; the y
  # title follows the same rule rather than assuming counts.
  axes <- label_axes(function() {
    hist(c(1, 2, 2, 3, 3, 3, 4, 5, 9), breaks = c(0, 1, 5, 10))
  })

  testthat::expect_equal(axes[[1]]$y$label, "Density")
})

test_that("an author's own histogram labels win", {
  axes <- label_axes(function() hist(c(1, 2, 3), xlab = "MPG", ylab = "Cars"))

  testthat::expect_equal(axes[[1]]$x$label, "MPG")
  testthat::expect_equal(axes[[1]]$y$label, "Cars")
})

# ==============================================================================
# Box plots
# ==============================================================================

test_that("a formula box plot announces the titles boxplot() draws", {
  axes <- label_axes(function() boxplot(mpg ~ cyl, data = mtcars))

  testthat::expect_equal(axes[[1]]$x$label, "cyl")
  testthat::expect_equal(axes[[1]]$y$label, "mpg")
})

test_that("a formula box plot joins several grouping terms the way R does", {
  # boxplot.formula() labels the category axis with the model frame's
  # non-response columns joined by " : ".
  axes <- label_axes(function() boxplot(mpg ~ cyl + gear, data = mtcars))

  testthat::expect_equal(axes[[1]]$x$label, "cyl : gear")
  testthat::expect_equal(axes[[1]]$y$label, "mpg")
})

test_that("a horizontal formula box plot swaps its titles, as R does", {
  axes <- label_axes(function() {
    boxplot(mpg ~ cyl, data = mtcars, horizontal = TRUE)
  })

  testthat::expect_equal(axes[[1]]$x$label, "mpg")
  testthat::expect_equal(axes[[1]]$y$label, "cyl")
})

test_that("a box plot of grouped values falls back to the generic pair", {
  # No formula, so nothing names the groups or the measurement -- but a box
  # plot still shows groups against their distributions.
  axes <- label_axes(function() {
    boxplot(list(a = c(1, 2, 3, 4), b = c(2, 3, 4, 5)))
  })

  testthat::expect_equal(axes[[1]]$x$label, "Category")
  testthat::expect_equal(axes[[1]]$y$label, "Value")
})

test_that("an author's own box plot labels win over the formula's", {
  axes <- label_axes(function() {
    boxplot(mpg ~ cyl, data = mtcars, xlab = "Cylinders", ylab = "Miles")
  })

  testthat::expect_equal(axes[[1]]$x$label, "Cylinders")
  testthat::expect_equal(axes[[1]]$y$label, "Miles")
})

# ==============================================================================
# Charts plot() titles after how their arguments were written
# ==============================================================================

test_that("a scatter plot names its axes as plot() writes them and keeps its grid", {
  axes <- label_axes(function() plot(1:10, (1:10)^2))

  testthat::expect_equal(axes[[1]]$x$label, "1:10")
  testthat::expect_equal(axes[[1]]$y$label, "(1:10)^2")
  testthat::expect_equal(axes[[1]]$x$max, 10)
  testthat::expect_equal(axes[[1]]$y$max, 100)
})

test_that("a scatter plot of one vector is titled Index against it, as plot() does", {
  axes <- label_axes(function() plot(mtcars$mpg))

  testthat::expect_equal(axes[[1]]$x$label, "Index")
  testthat::expect_equal(axes[[1]]$y$label, "mtcars$mpg")
})

test_that("a line plot, and the lines drawn over it, name the axes plot() wrote", {
  axes <- label_axes(function() {
    plot(1:10, (1:10)^2, type = "l")
    lines(1:10, (1:10)^1.5)
  })

  for (layer_axes in axes) {
    testthat::expect_equal(layer_axes$x$label, "1:10")
    testthat::expect_equal(layer_axes$y$label, "(1:10)^2")
  }
})

test_that("a line plot written with no expressions emits an empty axes object", {
  # do.call() writes the values themselves into the call: plot() titles
  # the axes with them deparsed, which is no name, so none is emitted.
  axes <- label_axes(function() do.call(plot, list(1:10, (1:10)^2, type = "l")))

  testthat::expect_length(axes[[1]], 0)
})

test_that("a plot() method of a class is titled as the method titles it", {
  # plot.ts() titles one series "Time" against its name, as R draws it.
  axes <- label_axes(function() plot(AirPassengers))

  testthat::expect_equal(axes[[1]]$x$label, "Time")
  testthat::expect_equal(axes[[1]]$y$label, "AirPassengers")
})

test_that("a time series, a one-way table and a two-column data frame are titled as R draws them", {
  # Written after another argument as well as first. plot() dispatches on
  # the series, the table or the frame wherever it is written, and their
  # methods' titles were read only when such a call was taken for
  # plot.default(), from the first argument written.
  cases <- list(
    list(quote(plot(type = "l", AirPassengers)), "Time", "AirPassengers"),
    list(quote(plot(main = "Nile", Nile)), "Time", "Nile"),
    list(quote(plot(EuStockMarkets[, "DAX", drop = FALSE])), "Time", "DAX"),
    list(quote(plot(table(cyl = mtcars$cyl))), "cyl", "table(cyl = mtcars$cyl)"),
    list(quote(plot(main = "T", table(c(1, 1, 2, 3, 3, 3)))), NULL, "table(c(1, 1, 2, 3, 3, 3))"),
    list(quote(plot(xlab = "v", table(c(1, 1, 2, 3, 3, 3)))), "v", "table(c(1, 1, 2, 3, 3, 3))"),
    list(quote(plot(mtcars[, c("wt", "mpg")])), "wt", "mpg"),
    list(quote(plot(main = "DF", mtcars[, c("wt", "mpg")])), "wt", "mpg")
  )

  for (case in cases) {
    call <- case[[1]]
    axes <- label_axes(function() eval(call))
    testthat::expect_identical(axes[[1]]$x$label, case[[2]], label = deparse1(call))
    testthat::expect_identical(axes[[1]]$y$label, case[[3]], label = deparse1(call))
  }
})

test_that("an axis the call leaves untitled is announced with no title, as R draws none", {
  testthat::skip_if_not_installed("svglite")
  testthat::skip_if_not_installed("xml2")
  # A plot() method draws the title it derives for an axis only where the
  # call gives that axis none: `ylab = ""` draws the blank instead, and
  # `ann = FALSE` no titles at all. Read as no title, the blank fell through
  # to the derived one, and "AirPassengers" was announced where R drew
  # nothing.
  drawn_titles <- function(call) {
    old <- options(maidr.base_r = FALSE)
    on.exit(options(old), add = TRUE)
    file <- tempfile(fileext = ".svg")
    on.exit(unlink(file), add = TRUE)
    originals <- list2env(
      list(
        plot = maidr:::get_original_function("plot"),
        lines = maidr:::get_original_function("lines")
      ),
      parent = globalenv()
    )
    svglite::svglite(file, width = 7, height = 5)
    tryCatch(eval(call, originals), finally = grDevices::dev.off())
    text <- trimws(xml2::xml_text(
      xml2::xml_find_all(xml2::read_xml(file), "//*[local-name()='text']")
    ))
    text[!grepl("^-?[0-9.]+$", text)]
  }

  cases <- list(
    list(quote(plot(AirPassengers, ylab = "")), "Time", NULL),
    list(quote(plot(Nile, xlab = "")), NULL, "Nile"),
    list(quote(plot(AirPassengers, ann = FALSE)), NULL, NULL),
    list(quote(plot(table(mtcars$cyl), ylab = "")), NULL, NULL),
    list(quote(plot(mtcars[, c("wt", "mpg")], xlab = "")), NULL, "mpg"),
    list(quote(plot(mtcars[, c("wt", "mpg")], ann = FALSE)), NULL, NULL),
    list(quote(plot(mtcars$mpg, ylab = "")), "Index", NULL),
    list(quote(plot(1:10, (1:10)^2, ann = FALSE)), NULL, NULL),
    list(quote(plot(sin, -pi, pi, ylab = "")), "x", NULL),
    list(quote(plot(sin, -pi, pi, ann = FALSE)), NULL, NULL),
    list(quote({
      plot(Nile, ylab = "")
      lines(Nile)
    }), "Time", NULL)
  )

  for (case in cases) {
    call <- case[[1]]
    label <- deparse1(call)
    axes <- label_axes(function() eval(call))
    for (layer_axes in axes) {
      testthat::expect_identical(layer_axes$x$label, case[[2]], label = label)
      testthat::expect_identical(layer_axes$y$label, case[[3]], label = label)
    }
    testthat::expect_identical(
      drawn_titles(call), as.character(c(case[[2]], case[[3]])),
      label = label
    )
  }
})

test_that("a title given as NULL, or turned off by par(ann = FALSE), is announced as R draws it", {
  testthat::skip_if_not_installed("svglite")
  testthat::skip_if_not_installed("xml2")
  # plot.ts() draws no title for an `xlab` or `ylab` given as NULL, and
  # plot.data.frame() hands the NULL on to plot.default(), which titles the
  # axis after the column it was handed, "x[[1L]]". `par(ann = FALSE)` turns
  # the derived titles off, as the call's own `ann = FALSE` does. Read from
  # the call alone, a NULL was taken for no argument and par() was not read,
  # so "Time" and "Nile" were announced where R drew neither.
  cases <- list(
    list(quote(plot(Nile, xlab = NULL)), NULL, "Nile"),
    list(quote(plot(Nile, ylab = NULL)), "Time", NULL),
    list(quote({
      framed <- function(x, xlab = NULL, ylab = NULL) plot(x, xlab = xlab, ylab = ylab)
      framed(AirPassengers)
    }), NULL, NULL),
    list(quote(plot(data.frame(a = 1:5, b = c(2, 4, 3, 5, 1)), ylab = NULL)), "a", "x[[2L]]"),
    list(quote(plot(cars, xlab = NULL)), "x[[1L]]", "dist"),
    # Where a method draws its derived title for a NULL, it is announced.
    list(quote(plot(table(c(1, 1, 2)), ylab = NULL)), NULL, "table(c(1, 1, 2))"),
    list(quote(plot(1:3, xlab = NULL)), "Index", "1:3"),
    list(quote(plot(sin, -pi, pi, ylab = NULL)), "x", "sin"),
    list(quote({
      op <- par(ann = FALSE)
      plot(Nile)
      par(op)
    }), NULL, NULL),
    list(quote({
      op <- par(ann = FALSE)
      plot(table(c(1, 1, 2)))
      par(op)
    }), NULL, NULL),
    list(quote({
      op <- par(ann = FALSE)
      plot(cars)
      par(op)
    }), NULL, NULL),
    list(quote({
      op <- par(ann = FALSE)
      plot(sin, -pi, pi)
      par(op)
    }), NULL, NULL),
    list(quote({
      op <- par(ann = FALSE)
      plot(1:10, (1:10)^2)
      par(op)
    }), NULL, NULL),
    # The call's own `ann` wins over par()'s, in R as here.
    list(quote({
      op <- par(ann = FALSE)
      plot(Nile, ann = TRUE)
      par(op)
    }), "Time", "Nile")
  )

  for (case in cases) {
    call <- case[[1]]
    label <- deparse1(call)
    axes <- label_axes(function() eval(call))
    for (layer_axes in axes) {
      testthat::expect_identical(layer_axes$x$label, case[[2]], label = label)
      testthat::expect_identical(layer_axes$y$label, case[[3]], label = label)
    }
    testthat::expect_identical(
      r_drawn_titles(call), as.character(c(case[[2]], case[[3]])),
      label = label
    )
  }
})

test_that("a formula or density plot() title the call leaves off is not announced", {
  # plot.formula() titles its axes after the formula's variables and
  # plot.density() its y axis "Density", where the call leaves them their
  # titles. Read as defaults of their own, they were announced where the
  # call blanked them, so `plot(mpg ~ wt, data = mtcars, ylab = "")` was
  # announced with "mpg" where `plot(mtcars$wt, mtcars$mpg, ylab = "")`
  # was not, and R draws neither.
  cases <- list(
    list(quote(plot(mpg ~ wt, data = mtcars)), "wt", "mpg"),
    list(quote(plot(mpg ~ wt, data = mtcars, ylab = "")), "wt", NULL),
    list(quote(plot(mpg ~ wt, data = mtcars, xlab = "")), NULL, "mpg"),
    list(quote(plot(mpg ~ wt, data = mtcars, ann = FALSE)), NULL, NULL),
    list(quote({
      op <- par(ann = FALSE)
      plot(mpg ~ wt, data = mtcars)
      par(op)
    }), NULL, NULL)
  )
  for (case in cases) {
    call <- case[[1]]
    label <- deparse1(call)
    axes <- label_axes(function() eval(call))
    testthat::expect_identical(axes[[1]]$x$label, case[[2]], label = label)
    testthat::expect_identical(axes[[1]]$y$label, case[[3]], label = label)
    testthat::expect_identical(
      r_drawn_titles(call), as.character(c(case[[2]], case[[3]])),
      label = label
    )
  }

  # plot.density() draws a title of its own too, which maidr does not
  # announce, so only its "Density" is checked.
  densities <- list(
    list(quote(plot(density(c(1, 2, 2, 3, 5)))), "Density"),
    list(quote(plot(density(c(1, 2, 2, 3, 5)), ylab = "")), NULL),
    list(quote(plot(density(c(1, 2, 2, 3, 5)), ann = FALSE)), NULL),
    list(quote({
      op <- par(ann = FALSE)
      plot(density(c(1, 2, 2, 3, 5)))
      par(op)
    }), NULL)
  )
  for (case in densities) {
    call <- case[[1]]
    label <- deparse1(call)
    axes <- label_axes(function() eval(call))
    testthat::expect_identical(axes[[1]]$y$label, case[[2]], label = label)
    testthat::expect_identical(
      "Density" %in% r_drawn_titles(call), !is.null(case[[2]]),
      label = label
    )
  }
})

test_that("a density plot() with another argument written first is read as the density", {
  # plot() dispatches on its first unnamed argument, so
  # `plot(main = "D", density(x))` draws the density, as
  # `plot(density(x), main = "D")` does. It was typed by the argument
  # written first and read as a scatter of the density's 512 points, and
  # announced without the "Density" R draws.
  same <- function(layer) layer[setdiff(names(layer), "id")]
  reference <- maidr_layers(function() plot(density(c(1, 2, 2, 3, 5)), main = "D"))
  testthat::expect_length(reference, 1L)
  testthat::expect_identical(reference[[1]]$type, "smooth")
  calls <- list(
    quote(plot(main = "D", density(c(1, 2, 2, 3, 5)))),
    quote(plot(col = 2, density(c(1, 2, 2, 3, 5)), main = "D"))
  )
  for (call in calls) {
    label <- deparse1(call)
    layers <- maidr_layers(function() eval(call))
    testthat::expect_length(layers, 1L)
    testthat::expect_identical(same(layers[[1]]), same(reference[[1]]), label = label)
    testthat::expect_identical(layers[[1]]$axes$y$label, "Density", label = label)
    testthat::expect_true("Density" %in% r_drawn_titles(call), label = label)
  }
})

test_that("a time series plot() with another argument written first is read as its line", {
  # plot.ts() draws a series as a line, wherever it is written among the
  # arguments. Typed by the argument written first, `plot(xlab = "", Nile)`
  # was read as a scatter, with a selector on a points grob R never drew.
  same <- function(layer) layer[setdiff(names(layer), "id")]
  reference <- maidr_layers(function() plot(Nile, xlab = ""))
  testthat::expect_length(reference, 1L)
  testthat::expect_identical(reference[[1]]$type, "line")
  layers <- maidr_layers(function() plot(xlab = "", Nile))
  testthat::expect_length(layers, 1L)
  testthat::expect_identical(same(layers[[1]]), same(reference[[1]]))
})

test_that("an axis titled by title() or mtext() after the plot is announced with that title", {
  # The idiom blanks a plot's own titles to write them with title() or
  # mtext(), on a line of the author's choosing. R draws them on the axes,
  # but the axes were read from the plot call alone, so they were announced
  # untitled: "X is 1.51, Y is 30.4" where R drew "Weight" and "MPG".
  cases <- list(
    list(quote({
      plot(mtcars$wt, mtcars$mpg, xlab = "", ylab = "")
      title(xlab = "Weight", ylab = "MPG")
    }), "Weight", "MPG"),
    list(quote({
      plot(mtcars$wt, mtcars$mpg, ann = FALSE)
      title(main = "Cars", xlab = "Weight", ylab = "MPG")
    }), "Weight", "MPG", c("Cars", "Weight", "MPG")),
    list(quote({
      plot(mtcars$wt, mtcars$mpg, ann = FALSE)
      mtext("Weight", side = 1, line = 3)
      mtext("MPG", side = 2, line = 3)
    }), "Weight", "MPG"),
    list(quote({
      plot(1:10, xlab = "", ylab = "")
      title(xlab = "X axis", line = 2)
      title(ylab = "Y axis", line = 2)
    }), "X axis", "Y axis"),
    list(quote({
      x <- 1:20
      plot(x, sin(x), type = "l", xlab = "", ylab = "")
      title(xlab = "Time (s)", ylab = "Signal")
    }), "Time (s)", "Signal"),
    list(quote({
      plot(sin, -pi, pi, ylab = "")
      title(ylab = "sine")
    }), "x", "sine"),
    list(quote({
      op <- par(ann = FALSE)
      plot(Nile)
      par(op)
      title(xlab = "Year")
    }), "Year", NULL),
    list(quote({
      hist(c(1, 2, 2, 3), xlab = "")
      title(xlab = "Width")
    }), "Width", "Frequency", c("Histogram of c(1, 2, 2, 3)", "Frequency", "Width")),
    # Drawn over the plot's own title, as R draws it, title()'s is the one
    # on top.
    list(quote({
      plot(1:3)
      title(xlab = "Second")
    }), "Second", "1:3", c("Index", "1:3", "Second")),
    # A note in the margin, set off to one side or in the outer margin, is
    # no axis title, and a title in the outer margin is the page's.
    list(quote({
      plot(1:3, xlab = "")
      mtext("n = 3", side = 1, line = 3, adj = 1)
    }), NULL, "1:3", c("1:3", "n = 3")),
    list(quote({
      plot(1:3, xlab = "")
      mtext("Note", side = 1, line = 3, outer = TRUE)
      title(xlab = "Page", outer = TRUE)
    }), NULL, "1:3", c("1:3", "Note", "Page")),
    list(quote({
      plot(1:3, xlab = "")
      mtext("A", side = 3)
    }), NULL, "1:3", c("1:3", "A"))
  )

  for (case in cases) {
    call <- case[[1]]
    label <- deparse1(call)
    axes <- label_axes(function() eval(call))
    for (layer_axes in axes) {
      testthat::expect_identical(layer_axes$x$label, case[[2]], label = label)
      testthat::expect_identical(layer_axes$y$label, case[[3]], label = label)
    }
    drawn <- if (length(case) > 3L) case[[4]] else c(case[[2]], case[[3]])
    testthat::expect_setequal(r_drawn_titles(call), drawn)
  }

  # Written first, as on every other axis, ahead of the grid fields.
  scatter <- label_axes(function() {
    plot(mtcars$wt, mtcars$mpg, ann = FALSE)
    title(xlab = "Weight", ylab = "MPG")
  })[[1]]
  testthat::expect_identical(names(scatter$x), c("label", "min", "max", "tickStep"))
  testthat::expect_identical(names(scatter$y), c("label", "min", "max", "tickStep"))

  # Each plot of a grid keeps the titles written on it.
  grid <- function() {
    op <- par(mfrow = c(1, 2))
    on.exit(par(op))
    plot(1:5, ylab = "")
    title(ylab = "A")
    plot(5:1, xlab = "")
    title(xlab = "B")
  }
  left <- label_axes(grid, cell = c(1L, 1L))[[1]]
  right <- label_axes(grid, cell = c(1L, 2L))[[1]]
  testthat::expect_identical(c(left$x$label, left$y$label), c("Index", "A"))
  testthat::expect_identical(c(right$x$label, right$y$label), c("B", "5:1"))
})

test_that("of several mtext() strings on one side, the one nearest the axis titles it", {
  # A note under the axis title, such as the source of the data, is written
  # on a line farther out. The last string written was taken for the title,
  # so the chart was announced "Source: mtcars" where R drew "Weight" at the
  # axis, and written the other way round it was "Weight".
  cases <- list(
    list(quote({
      plot(mtcars$wt, mtcars$mpg, ann = FALSE)
      mtext("Weight", side = 1, line = 2.5)
      mtext("Source: mtcars", side = 1, line = 4, cex = 0.8)
    }), "Weight", NULL, c("Weight", "Source: mtcars")),
    list(quote({
      plot(mtcars$wt, mtcars$mpg, ann = FALSE)
      mtext("Source: mtcars", side = 1, line = 4, cex = 0.8)
      mtext("Weight", side = 1, line = 2.5)
    }), "Weight", NULL, c("Weight", "Source: mtcars")),
    list(quote({
      plot(sin, -pi, pi, xlab = "")
      mtext("angle (rad)", side = 1, line = 2.5)
      mtext("n = 101", side = 1, line = 4)
    }), "angle (rad)", "sin", c("sin", "angle (rad)", "n = 101")),
    list(quote({
      plot(1:3, ann = FALSE)
      mtext("Height", 2, 2.5)
      mtext("in metres", 2, 4)
    }), NULL, "Height", c("Height", "in metres")),
    # One inside the plot, on a negative line, is a note in the plot where
    # the margin has a title.
    list(quote({
      plot(1:3, ann = FALSE)
      mtext("Index", 1, 3)
      mtext("n = 3", 1, -1.5)
    }), "Index", NULL, c("Index", "n = 3")),
    # Written on one line, the last is the one on top.
    list(quote({
      plot(1:3, ann = FALSE)
      mtext("A", side = 1, line = 3)
      mtext("B", side = 1, line = 3)
    }), "B", NULL, c("A", "B"))
  )

  for (case in cases) {
    call <- case[[1]]
    label <- deparse1(call)
    axes <- label_axes(function() eval(call))
    for (layer_axes in axes) {
      testthat::expect_identical(layer_axes$x$label, case[[2]], label = label)
      testthat::expect_identical(layer_axes$y$label, case[[3]], label = label)
    }
    testthat::expect_setequal(r_drawn_titles(call), case[[4]])
  }
})

test_that("a title written in a margin titles the series whose axis is drawn there", {
  # A chart of two y axes draws its second series over the first with
  # par(new = TRUE) and axes = FALSE, gives it an axis of its own on the
  # right with axis(4), and often writes every title after it. Read only on
  # the plot written last, the second series was titled after the left axis,
  # "Squares", and the first series had no title at all.
  dual <- function(titles) {
    bquote({
      x <- 1:10
      op <- par(mar = c(5, 4, 4, 5))
      plot(x, x^2, type = "l", ann = FALSE)
      par(new = TRUE)
      plot(x, sqrt(x), type = "l", axes = FALSE, ann = FALSE)
      axis(4)
      .(titles)
      par(op)
    })
  }
  cases <- list(
    list(dual(quote({
      title(xlab = "Time")
      mtext("Squares", side = 2, line = 3)
      mtext("Roots", side = 4, line = 3)
    })), list(list("Time", "Squares"), list(NULL, "Roots"))),
    list(dual(quote({
      title(xlab = "Time", ylab = "Squares")
      mtext("Roots", side = 4, line = 3)
    })), list(list("Time", "Squares"), list(NULL, "Roots"))),
    # With `par(new = TRUE)` made where maidr does not record it, through
    # `graphics::par()`, or `withr::with_par()`. R draws the second series
    # over the first all the same, and maidr's drawing did, but every title
    # went to the second series: the first was untitled, the second titled
    # "Time", and "Squares" was announced nowhere.
    list(quote({
      x <- 1:10
      op <- graphics::par(mar = c(5, 4, 4, 5))
      plot(x, x^2, type = "l", ann = FALSE)
      graphics::par(new = TRUE)
      plot(x, sqrt(x), type = "l", axes = FALSE, ann = FALSE)
      axis(4)
      title(xlab = "Time")
      mtext("Squares", side = 2, line = 3)
      mtext("Roots", side = 4, line = 3)
      graphics::par(op)
    }), list(list("Time", "Squares"), list(NULL, "Roots"))),
    list(quote({
      x <- 1:10
      op <- par(mar = c(5, 4, 4, 5))
      plot(x, x^2, type = "l", ann = FALSE)
      withr::with_par(
        list(new = TRUE),
        plot(x, sqrt(x), type = "l", axes = FALSE, ann = FALSE)
      )
      axis(4)
      title(xlab = "Time")
      mtext("Squares", side = 2, line = 3)
      mtext("Roots", side = 4, line = 3)
      par(op)
    }), list(list("Time", "Squares"), list(NULL, "Roots"))),
    # Each written after its own plot.
    list(quote({
      x <- 1:10
      op <- par(mar = c(5, 4, 4, 5))
      plot(x, x^2, type = "l", xlab = "Time", ylab = "")
      mtext("Squares", side = 2, line = 3)
      par(new = TRUE)
      plot(x, sqrt(x), type = "l", axes = FALSE, xlab = "", ylab = "")
      axis(4)
      mtext("Roots", side = 4, line = 3)
      par(op)
    }), list(list("Time", "Squares"), list(NULL, "Roots"))),
    # The second series draws the x axis too, so it shares its title.
    list(quote({
      x <- 1:10
      op <- par(mar = c(5, 4, 4, 5))
      plot(x, x^2, type = "l", ann = FALSE)
      par(new = TRUE)
      plot(x, sqrt(x), type = "l", yaxt = "n", ann = FALSE)
      axis(4)
      title(xlab = "Time", ylab = "Squares")
      mtext("Roots", side = 4, line = 3)
      par(op)
    }), list(list("Time", "Squares"), list("Time", "Roots"))),
    # One plot whose only y axis is on the right.
    list(quote({
      op <- par(mar = c(5, 4, 4, 5))
      plot(1:10, yaxt = "n", ylab = "")
      axis(4)
      mtext("Right", side = 4, line = 3)
      par(op)
    }), list(list("Index", "Right")), c("Index", "Right")),
    # With the y axis drawn on the left as well, the right margin's text is
    # a note.
    list(quote({
      op <- par(mar = c(5, 4, 4, 5))
      plot(1:10, ylab = "")
      axis(4)
      mtext("Note", side = 4, line = 3)
      par(op)
    }), list(list("Index", NULL)), c("Index", "Note"))
  )

  for (case in cases) {
    call <- case[[1]]
    label <- deparse1(call)
    axes <- label_axes(function() eval(call))
    expected <- case[[2]]
    testthat::expect_length(axes, length(expected))
    for (i in seq_along(expected)) {
      testthat::expect_identical(axes[[i]]$x$label, expected[[i]][[1]], label = label)
      testthat::expect_identical(axes[[i]]$y$label, expected[[i]][[2]], label = label)
    }
    drawn <- if (length(case) > 2L) case[[3]] else c("Time", "Squares", "Roots")
    testthat::expect_setequal(r_drawn_titles(call), drawn)
  }
})

test_that("of several axes on one side, a title titles the series it is written beside", {
  # A chart of three series can draw two y axes on one side, one at the edge
  # of the plot and one farther out with axis(line = ), and title each on a
  # line just outside it. Every series with an axis on that side was given
  # the string nearest the plot, so the third series was announced with the
  # second one's title.
  right <- function(titles) {
    bquote({
      op <- par(mar = c(5, 4, 4, 7))
      plot(1:10, ylab = "Left")
      par(new = TRUE)
      plot(10:1, type = "l", axes = FALSE, ann = FALSE)
      axis(4)
      par(new = TRUE)
      plot((1:10)^2, type = "l", axes = FALSE, ann = FALSE, col = 2)
      axis(4, line = 3.5)
      .(titles)
      par(op)
    })
  }
  cases <- list(
    list(right(quote({
      mtext("Second", side = 4, line = 2)
      mtext("Third", side = 4, line = 5.5)
    })), list(list("Index", "Left"), list(NULL, "Second"), list(NULL, "Third")),
    c("Index", "Left", "Second", "Third")),
    list(right(quote({
      mtext("Third", side = 4, line = 5.5)
      mtext("Second", side = 4, line = 2)
    })), list(list("Index", "Left"), list(NULL, "Second"), list(NULL, "Third")),
    c("Index", "Left", "Second", "Third")),
    # On the left, title() writes on line 3, beside the plot's own axis.
    list(quote({
      op <- par(mar = c(5, 7, 4, 2))
      plot(1:10, ann = FALSE)
      par(new = TRUE)
      plot((1:10)^2, type = "l", axes = FALSE, ann = FALSE)
      axis(2, line = 3.5)
      title(ylab = "First")
      mtext("Squares", side = 2, line = 5.5)
      par(op)
    }), list(list(NULL, "First"), list(NULL, "Squares")), c("First", "Squares"))
  )

  for (case in cases) {
    call <- case[[1]]
    label <- deparse1(call)
    axes <- label_axes(function() eval(call))
    expected <- case[[2]]
    testthat::expect_length(axes, length(expected))
    for (i in seq_along(expected)) {
      testthat::expect_identical(axes[[i]]$x$label, expected[[i]][[1]], label = label)
      testthat::expect_identical(axes[[i]]$y$label, expected[[i]][[2]], label = label)
    }
    testthat::expect_setequal(r_drawn_titles(call), case[[3]])
  }
})

test_that("a plot placed beside or inset in another keeps the titles written after it", {
  # par(fig = , new = TRUE) and par(plt = , new = TRUE) draw the next plot on
  # the same page, but beside the last one or inset in it rather than over
  # it. Read as drawn over it, a title() or mtext() written for the second
  # plot titled the first too, over the first one's own title.
  cases <- list(
    list(quote({
      par(fig = c(0, 0.5, 0, 1))
      plot(1:10, xlab = "Left")
      par(fig = c(0.5, 1, 0, 1), new = TRUE)
      plot(10:1, xlab = "")
      title(xlab = "Right")
    }), list(list("Left", "1:10"), list("Right", "10:1")), c("Left", "1:10", "10:1", "Right")),
    list(quote({
      par(fig = c(0, 0.5, 0, 1))
      plot(sin, -pi, pi, ann = FALSE)
      mtext("A", side = 1, line = 3)
      par(fig = c(0.5, 1, 0, 1), new = TRUE)
      plot(cos, -pi, pi, ann = FALSE)
      mtext("B", side = 1, line = 3)
    }), list(list("A", NULL), list("B", NULL)), c("A", "B")),
    list(quote({
      plot(sin, -pi, pi, ylab = "sine")
      par(fig = c(0.55, 0.95, 0.5, 0.95), new = TRUE)
      plot(cos, 0, 1, ann = FALSE)
      title(ylab = "cos")
    }), list(list("x", "sine"), list(NULL, "cos")), c("x", "sine", "cos")),
    list(quote({
      plot(1:10, ann = FALSE)
      title(ylab = "Main y")
      par(plt = c(0.6, 0.9, 0.6, 0.9), new = TRUE)
      plot(10:1, ann = FALSE)
      title(ylab = "Inset y")
    }), list(list(NULL, "Main y"), list(NULL, "Inset y")), c("Main y", "Inset y")),
    list(quote({
      plot(1:10, ann = FALSE)
      par(fig = c(0.5, 0.95, 0.5, 0.95), new = TRUE)
      plot(10:1, ann = FALSE)
      mtext("Inset x", side = 1, line = 2)
    }), list(list(NULL, NULL), list("Inset x", NULL)), "Inset x")
  )

  for (case in cases) {
    call <- case[[1]]
    label <- deparse1(call)
    axes <- label_axes(function() eval(call))
    expected <- case[[2]]
    testthat::expect_length(axes, length(expected))
    for (i in seq_along(expected)) {
      testthat::expect_identical(axes[[i]]$x$label, expected[[i]][[1]], label = label)
      testthat::expect_identical(axes[[i]]$y$label, expected[[i]][[2]], label = label)
    }
    testthat::expect_setequal(r_drawn_titles(call), case[[3]])
  }
})

test_that("a plot drawn after screen() erased its screen keeps its own titles", {
  # screen(n) erases screen n before the plot drawn next, with a plot of its
  # own filled with the background, so the plot drawn there before is no
  # longer seen: the next one is not drawn over it, as one after
  # screen(n, new = FALSE) is. Read as drawn over it, the erased plot was
  # announced with the axis titles written for the plot after it, in place
  # of those R drew with it.
  cases <- list(
    list(quote({
      split.screen(c(1, 2))
      screen(1)
      plot(1:10, main = "A", xlab = "xa", ylab = "ya")
      screen(1)
      plot(5:1, ann = FALSE)
      title(xlab = "xc", ylab = "yc")
      screen(2)
      plot(Nile, main = "N")
      close.screen(all.screens = TRUE)
    }), list(list("xa", "ya"), list("xc", "yc"), list("Time", "Nile")),
    c("A", "xa", "ya", "xc", "yc", "N", "Time", "Nile")),
    list(quote({
      split.screen(c(1, 2))
      screen(1)
      plot(1:10, ann = FALSE)
      title(main = "A", xlab = "xa", ylab = "ya")
      screen(1)
      plot(5:1, ann = FALSE)
      title(xlab = "xc", ylab = "yc")
      close.screen(all.screens = TRUE)
    }), list(list("xa", "ya"), list("xc", "yc")), c("A", "xa", "ya", "xc", "yc")),
    # Sent back with new = FALSE, the screen is not erased, and the second
    # series is drawn over the first, as on a chart of two y axes.
    list(quote({
      x <- 1:10
      split.screen(c(1, 2))
      screen(1)
      par(mar = c(5, 4, 4, 5))
      plot(x, x^2, type = "l", ann = FALSE)
      screen(1, new = FALSE)
      plot(x, sqrt(x), type = "l", axes = FALSE, ann = FALSE)
      axis(4)
      title(xlab = "Time")
      mtext("Squares", side = 2, line = 3)
      mtext("Roots", side = 4, line = 3)
      close.screen(all.screens = TRUE)
    }), list(list("Time", "Squares"), list(NULL, "Roots")), c("Time", "Squares", "Roots"))
  )

  for (case in cases) {
    call <- case[[1]]
    label <- deparse1(call)
    axes <- label_axes(function() eval(call))
    expected <- case[[2]]
    testthat::expect_length(axes, length(expected))
    for (i in seq_along(expected)) {
      testthat::expect_identical(axes[[i]]$x$label, expected[[i]][[1]], label = label)
      testthat::expect_identical(axes[[i]]$y$label, expected[[i]][[2]], label = label)
    }
    testthat::expect_setequal(r_drawn_titles(call), case[[3]])
  }
})

test_that("a title written after par(mfg = ) titles the panel R draws it under", {
  # par(mfg = ) moves back to an earlier panel of a grid, and a title() or
  # mtext() written then is drawn under that panel. It was recorded with the
  # plot drawn last, and titled the last panel instead.
  cases <- list(
    list(quote({
      par(mfrow = c(1, 2))
      plot(1:10, xlab = "")
      plot(10:1, xlab = "")
      par(mfg = c(1, 1))
      mtext("Left panel x", side = 1, line = 3)
    }), list(list("Left panel x", "1:10"), list(NULL, "10:1")), c("1:10", "10:1", "Left panel x")),
    list(quote({
      par(mfrow = c(1, 2))
      plot(1:10, ann = FALSE)
      plot(10:1, ann = FALSE)
      par(mfg = c(1, 1))
      title(xlab = "First")
      par(mfg = c(1, 2))
      title(ylab = "Second")
    }), list(list("First", NULL), list(NULL, "Second")), c("First", "Second"))
  )

  for (case in cases) {
    call <- case[[1]]
    label <- deparse1(call)
    expected <- case[[2]]
    for (i in seq_along(expected)) {
      axes <- label_axes(function() eval(call), cell = c(1L, i))
      testthat::expect_length(axes, 1L)
      testthat::expect_identical(axes[[1]]$x$label, expected[[i]][[1]], label = label)
      testthat::expect_identical(axes[[1]]$y$label, expected[[i]][[2]], label = label)
    }
    testthat::expect_setequal(r_drawn_titles(call), case[[3]])
  }
})

test_that("a title written after a chart drawn onto a plot with add = TRUE titles both", {
  # contour(add = TRUE) and boxplot(add = TRUE) draw onto the plot drawn
  # last, against its axes, but as high-level calls they are recorded as
  # plots of their own. A title written after one titled that layer only,
  # and the plot it was drawn onto, the one R titles, was announced
  # untitled.
  cases <- list(
    list(quote({
      image(volcano, ann = FALSE)
      contour(volcano, add = TRUE, drawlabels = FALSE)
      title(xlab = "Easting", ylab = "Northing")
    }), list("Easting", "Northing"), c("Easting", "Northing")),
    list(quote({
      image(volcano, ann = FALSE)
      title(xlab = "Easting")
      contour(volcano, add = TRUE, drawlabels = FALSE)
      title(ylab = "Northing")
    }), list("Easting", "Northing"), c("Easting", "Northing")),
    list(quote({
      boxplot(len ~ supp, data = ToothGrowth, ann = FALSE)
      boxplot(len ~ supp, data = ToothGrowth, add = TRUE, col = NA, border = 2)
      title(xlab = "Supp", ylab = "Len")
    }), list("Supp", "Len"), c("OJ", "VC", "OJ", "VC", "Supp", "Len"))
  )

  for (case in cases) {
    call <- case[[1]]
    label <- deparse1(call)
    axes <- label_axes(function() eval(call))
    testthat::expect_length(axes, 2L)
    for (layer_axes in axes) {
      testthat::expect_identical(layer_axes$x$label, case[[2]][[1]], label = label)
      testthat::expect_identical(layer_axes$y$label, case[[2]][[2]], label = label)
    }
    testthat::expect_setequal(r_drawn_titles(call), case[[3]])
  }
})

test_that("a title() after a chart read as several layers titles each of them", {
  # stripchart() is read as one layer per group, and the titles were written
  # on the result that holds them rather than on the layers themselves, so
  # every strip kept its "Value" and "Category" where R drew "Val".
  cases <- list(
    list(quote({
      stripchart(list(a = 1:5, b = 3:8))
      title(xlab = "Val")
    }), "Val", "Category", c("a", "b", "Val")),
    # The formula's own "len" is drawn too, under title()'s, which is on top.
    list(quote({
      stripchart(len ~ supp, data = ToothGrowth)
      title(xlab = "Length", ylab = "Supplement")
    }), "Length", "Supplement", c("OJ", "VC", "len", "Length", "Supplement"))
  )

  for (case in cases) {
    call <- case[[1]]
    label <- deparse1(call)
    axes <- label_axes(function() eval(call))
    testthat::expect_length(axes, 2L)
    for (layer_axes in axes) {
      testthat::expect_identical(layer_axes$x$label, case[[2]], label = label)
      testthat::expect_identical(layer_axes$y$label, case[[3]], label = label)
    }
    testthat::expect_setequal(r_drawn_titles(call), case[[4]])
  }
})

test_that("an author's own scatter plot labels are still announced", {
  axes <- label_axes(function() {
    plot(1:10, (1:10)^2, xlab = "Index", ylab = "Square")
  })

  testthat::expect_equal(axes[[1]]$x$label, "Index")
  testthat::expect_equal(axes[[1]]$y$label, "Square")
})

test_that("heatmap() names the matrix dimensions it draws", {
  axes <- label_axes(function() {
    heatmap(matrix(c(1, 9, 2, 8, 3, 7, 4, 6, 5, 2, 2, 9, 7, 1, 4), nrow = 5))
  })

  testthat::expect_equal(axes[[1]]$x$label, "Columns")
  testthat::expect_equal(axes[[1]]$y$label, "Rows")
})

test_that("image() draws a coordinate grid and so claims no dimension names", {
  axes <- label_axes(function() image(matrix(1:9, 3)))

  testthat::expect_null(axes[[1]]$x)
  testthat::expect_null(axes[[1]]$y)
  testthat::expect_equal(axes[[1]]$z$label, "value")
})
