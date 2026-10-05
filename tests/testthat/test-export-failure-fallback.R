# An export that throws must cost the chart its interactivity, not the save.
#
# The reproducers were `matplot()` and `symbols()`, which failed inside
# gridSVG's `grid.export()` when maidr exported with it; the svglite export
# draws both. They are still exercised at the end, because whether a given
# exporter manages them is not this package's contract. The contract is the
# one asserted first: whatever the build raises, a caller who has fallback
# enabled gets a picture.

test_that("a build that throws falls back to the static image", {

  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  clear_all_device_storage()
  on.exit(clear_all_device_storage(), add = TRUE)

  plot(1:10)

  testthat::local_mocked_bindings(
    create_enhanced_svg = function(gt, maidr_data, ...) {
      stop("We shouldn't be here!")
    }
  )

  file <- tempfile(fileext = ".html")
  on.exit(unlink(file), add = TRUE)
  expect_warning(
    maidr::save_html(plot = NULL, file = file),
    "We shouldn't be here!"
  )

  html <- paste(readLines(file, warn = FALSE), collapse = "\n")
  expect_true(grepl("base64", html, fixed = TRUE))
})

test_that("the warning names the failure so it can be reported upstream", {

  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  clear_all_device_storage()
  on.exit(clear_all_device_storage(), add = TRUE)

  plot(1:10)

  testthat::local_mocked_bindings(
    create_enhanced_svg = function(gt, maidr_data, ...) {
      stop("non-numeric argument to binary operator")
    }
  )

  file <- tempfile(fileext = ".html")
  on.exit(unlink(file), add = TRUE)
  expect_warning(
    maidr::save_html(plot = NULL, file = file),
    "non-numeric argument to binary operator"
  )
})

test_that("a caller who disabled fallback gets the error, not the picture", {

  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  clear_all_device_storage()
  on.exit(clear_all_device_storage(), add = TRUE)
  previous <- options(maidr.fallback_enabled = FALSE)
  on.exit(options(previous), add = TRUE)

  plot(1:10)

  testthat::local_mocked_bindings(
    create_enhanced_svg = function(gt, maidr_data, ...) {
      stop("We shouldn't be here!")
    }
  )

  file <- tempfile(fileext = ".html")
  on.exit(unlink(file), add = TRUE)
  expect_error(
    maidr::save_html(plot = NULL, file = file),
    "We shouldn't be here!"
  )
})

test_that("a plot that exports cleanly is still read, not fallen back", {

  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  clear_all_device_storage()
  on.exit(clear_all_device_storage(), add = TRUE)

  plot(1:10)

  file <- tempfile(fileext = ".html")
  on.exit(unlink(file), add = TRUE)
  suppressWarnings(maidr::save_html(plot = NULL, file = file))

  html <- paste(readLines(file, warn = FALSE), collapse = "\n")
  expect_true(grepl("maidr-data", html, fixed = TRUE))
  expect_false(grepl("base64", html, fixed = TRUE))
})

# The two calls that surfaced this. An exporter that manages them (the
# svglite export does) makes these plots interactive, which is a better
# outcome and not a regression -- so the assertion is on the save
# completing, not on which of the two answers it gives.
test_that("matplot and symbols leave the caller with a file either way", {

  for (draw in list(
    function() matplot(matrix(1:12, 4)),
    function() symbols(1:3, 1:3, circles = c(1, 2, 3), inches = 0.2)
  )) {
    grDevices::pdf(NULL)
    clear_all_device_storage()

    draw()
    file <- tempfile(fileext = ".html")
  on.exit(unlink(file), add = TRUE)
    suppressWarnings(maidr::save_html(plot = NULL, file = file))

    expect_true(file.exists(file))
    expect_gt(file.size(file), 0)

    clear_all_device_storage()
    grDevices::dev.off()
  }
})

test_that("a chart gridGraphics cannot draw again falls back to the picture, with a warning", {
  # It was exported with an empty drawing and nothing said: the replay fell
  # back to grabbing the Base R drawing as grid graphics, which holds none.
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  clear_all_device_storage()
  on.exit(clear_all_device_storage(), add = TRUE)

  testthat::local_mocked_bindings(
    grid.echo = function(...) stop("Unrecognised text argument type"),
    .package = "gridGraphics"
  )

  draws <- list(
    function() plot(1:10),
    function() {
      par(mfrow = c(1, 2))
      plot(1:3)
      plot(1:4)
    }
  )
  for (draw in draws) {
    clear_all_device_storage()
    draw()
    file <- tempfile(fileext = ".html")
    on.exit(unlink(file), add = TRUE)
    expect_warning(
      maidr::save_html(plot = NULL, file = file),
      "could not draw the chart again: Unrecognised text argument type"
    )
    html <- paste(readLines(file, warn = FALSE), collapse = "\n")
    expect_true(grepl("base64", html, fixed = TRUE))
    graphics::par(mfrow = c(1, 1))
  }
})

test_that("the picture of a chart that could not be made interactive says so, and names it", {
  # Its alt text, which is what a screen reader says of it, said the chart
  # contained unsupported elements, which it does not, and named nothing.
  skip_if_not_installed("xml2")
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  clear_all_device_storage()
  on.exit(clear_all_device_storage(), add = TRUE)

  testthat::local_mocked_bindings(
    grid.echo = function(...) stop("Unrecognised text argument type"),
    .package = "gridGraphics"
  )

  picture <- function(draw) {
    clear_all_device_storage()
    draw()
    file <- tempfile(fileext = ".html")
    on.exit(unlink(file), add = TRUE)
    suppressWarnings(maidr::save_html(plot = NULL, file = file))
    page <- xml2::read_html(file)
    list(
      alt = xml2::xml_attr(xml2::xml_find_all(page, "//img"), "alt"),
      notice = xml2::xml_text(xml2::xml_find_all(page, "//p[@class='fallback-notice']"))
    )
  }

  shown <- picture(function() plot(1:5, main = 'Speed & "fuel"'))
  expect_identical(
    shown$alt,
    'Speed & "fuel" (rendered as image - could not be made interactive)'
  )
  expect_identical(
    shown$notice,
    "This plot could not be made interactive and is rendered as a static image."
  )

  shown <- picture(function() {
    plot(1:5)
    title(main = 2024)
  })
  expect_identical(shown$alt, "2024 (rendered as image - could not be made interactive)")

  shown <- picture(function() plot(1:5))
  expect_identical(shown$alt, "Plot (rendered as image - could not be made interactive)")

  # A picture of several panels was named by its last titled panel alone.
  # It is named by the title R drew over them all, or by every panel.
  shown <- picture(function() {
    par(mfrow = c(1, 2))
    plot(1:5, main = "Sales 2023")
    plot(5:1, main = c("Costs", "2024"))
  })
  expect_identical(
    shown$alt,
    "2 panels: Sales 2023, Costs 2024 (rendered as image - could not be made interactive)"
  )
  graphics::par(mfrow = c(1, 1))

  shown <- picture(function() {
    par(mfrow = c(1, 2))
    plot(1:5, main = "Left")
    plot(5:1)
  })
  expect_identical(
    shown$alt,
    "2 panels: Left, untitled (rendered as image - could not be made interactive)"
  )
  graphics::par(mfrow = c(1, 1))

  shown <- picture(function() {
    par(mfrow = c(1, 2), oma = c(0, 0, 2, 0))
    plot(1:5, main = "A")
    plot(5:1, main = "B")
    title("Overview", outer = TRUE)
  })
  expect_identical(shown$alt, "Overview (rendered as image - could not be made interactive)")
  graphics::par(mfrow = c(1, 1), oma = c(0, 0, 0, 0))

  # The picture holds the page R shows, the last one, and the panels R drew
  # on it. It was named by an outer title from an earlier page, called
  # panels titled with title() untitled, and counted maidr's cells: a
  # panel spanning two twice, and an empty one as a panel.
  named <- function(draw) {
    on.exit(graphics::par(mfrow = c(1, 1), oma = c(0, 0, 0, 0)), add = TRUE)
    sub(" \\(rendered as image - could not be made interactive\\)$", "", picture(draw)$alt)
  }
  expect_identical(named(function() {
    par(mfrow = c(1, 2), oma = c(0, 0, 2, 0))
    plot(1:5, main = "A")
    plot(5:1, main = "B")
    title("Page one", outer = TRUE)
    plot(1:5, main = "C")
    plot(5:1, main = "D")
  }), "2 panels: C, D")
  expect_identical(named(function() {
    par(mfrow = c(1, 2))
    plot(1:5, ann = FALSE)
    title("Speed")
    plot(5:1)
    title(main = "Cost")
  }), "2 panels: Speed, Cost")
  expect_identical(named(function() {
    par(mfrow = c(2, 2))
    plot(1:5, main = "Only")
  }), "Only")
  expect_identical(named(function() {
    par(mfrow = c(2, 2))
    plot(1:5, main = "one")
    plot(1:5, main = "two")
    plot(1:5, main = "three")
  }), "3 panels: one, two, three")
  expect_identical(named(function() {
    layout(matrix(c(1, 1, 2, 3), 2, byrow = TRUE))
    plot(1:5, main = "Top")
    hist(c(1, 2, 2, 3), main = "H")
    barplot(c(a = 1, b = 2), main = "B")
  }), "3 panels: Top, H, B")
  expect_identical(named(function() {
    par(mfrow = c(1, 2), oma = c(0, 0, 3, 0))
    plot(1:5, main = "A")
    plot(5:1, main = "B")
    mtext("Overview", outer = TRUE, cex = 1.5)
  }), "Overview")
  expect_identical(named(function() {
    plot(1:5, ann = FALSE)
    title("Speed")
  }), "Speed")
  # A title drawn over the panels from a panel `plot.new()` took, which no
  # recorded plot is in, is the page's all the same.
  expect_identical(named(function() {
    par(mfrow = c(1, 3), oma = c(0, 0, 2, 0))
    plot(1:5, main = "A")
    plot(5:1, main = "B")
    plot.new()
    mtext("Overview", outer = TRUE)
  }), "Overview")
  expect_identical(named(function() {
    par(mfrow = c(1, 3), oma = c(0, 0, 2, 0))
    plot.new()
    title("Overview", outer = TRUE)
    plot(1:5, main = "A")
    plot(5:1, main = "B")
  }), "Overview")
})
