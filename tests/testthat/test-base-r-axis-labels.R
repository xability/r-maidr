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

label_axes <- function(draw) {
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

  layers <- jsonlite::fromJSON(json, simplifyVector = FALSE)$subplots[[1]][[1]]$layers
  lapply(layers, function(layer) layer$axes)
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
