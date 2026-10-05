# A Base R chart is the page R's device shows.
#
# R draws a high-level plot that moves past the last panel of its page on a
# new page, and its device shows only the page drawn last: after
# `hist(mtcars$mpg); hist(mtcars$hp)` it shows the second histogram alone.
# maidr read every call recorded on the device as one chart -- both
# histograms' data in one subplot, under a drawing of the first -- so a
# reader heard data that was not on the chart, beside a picture R no longer
# showed. These tests compare what maidr exports with what R draws on its
# last page, and check that nothing drawn on an earlier page reaches the
# chart: not its data, its titles, its selectors or the size it is drawn at.

skip_if_not_installed("xml2")
skip_if_not_installed("jsonlite")

# Every string an SVG document draws.
last_page_strings <- function(document) {
  trimws(xml2::xml_text(
    xml2::xml_find_all(document, "//*[local-name()='text']")
  ))
}

# What `save_html()` exports for `draw()`, drawn on a throwaway device: the
# strings its SVG draws, the ids of its elements and its schema.
last_page_export <- function(draw) {
  grDevices::pdf(NULL)
  device_id <- grDevices::dev.cur()
  clear_base_r_device(device_id)
  file <- tempfile(fileext = ".html")
  on.exit(
    {
      clear_base_r_device(device_id)
      if (device_id %in% grDevices::dev.list()) grDevices::dev.off(device_id)
      unlink(file)
    },
    add = TRUE
  )
  draw()
  suppressWarnings(suppressMessages(save_html(file = file)))

  html <- paste(readLines(file, warn = FALSE), collapse = "\n")
  document <- xml2::read_html(file)
  list(
    strings = last_page_strings(document),
    ids = xml2::xml_attr(xml2::xml_find_all(document, "//*[@id]"), "id"),
    schema = schema_from(html),
    text_at = maidr_text_at(document)
  )
}

# Where maidr's SVG draws each string: its anchor, in px from the left and
# the bottom of the page. The drawing places each text with a translate()
# two levels up, in a frame whose y counts up from the bottom.
maidr_text_at <- function(document) {
  texts <- xml2::xml_find_all(document, "//*[local-name()='text']")
  moves <- vapply(
    texts,
    function(text) xml2::xml_attr(xml2::xml_parent(xml2::xml_parent(text)), "transform"),
    character(1)
  )
  moves[is.na(moves)] <- ""
  at <- regmatches(moves, regexec("translate\\(([-0-9.]+), *([-0-9.]+)\\)", moves))
  data.frame(
    string = trimws(xml2::xml_text(texts)),
    x = vapply(at, function(m) as.numeric(m[2]), numeric(1)),
    y = vapply(at, function(m) as.numeric(m[3]), numeric(1))
  )
}

# What R draws on the page its device shows for `call`, as an svglite
# document at 7 x 5 in, each function maidr wraps bound to its original so
# the call never passes through a wrapper.
r_last_page_document <- function(call, env) {
  testthat::skip_if_not_installed("svglite")
  old <- options(maidr.base_r = FALSE)
  on.exit(options(old), add = TRUE)
  file <- tempfile(fileext = ".svg")
  on.exit(unlink(file), add = TRUE)

  named <- intersect(maidr:::get_all_function_names(), all.names(call))
  reference <- list2env(
    stats::setNames(lapply(named, maidr:::get_original_function), named),
    parent = env
  )
  svglite::svglite(file, width = 7, height = 5)
  tryCatch(eval(call, reference), finally = grDevices::dev.off())
  xml2::read_xml(file)
}

# The strings R draws on the page its device shows for `call`.
r_last_page_strings <- function(call, env = parent.frame()) {
  last_page_strings(r_last_page_document(call, env))
}

# Where R draws each string of `call`'s last page, as `maidr_text_at()`
# reads maidr's: svglite counts y down from the top of the 360 px page.
r_last_page_text_at <- function(call, env = parent.frame()) {
  texts <- xml2::xml_find_all(r_last_page_document(call, env), "//*[local-name()='text']")
  data.frame(
    string = trimws(xml2::xml_text(texts)),
    x = as.numeric(xml2::xml_attr(texts, "x")),
    y = 360 - as.numeric(xml2::xml_attr(texts, "y"))
  )
}

# `strings` are drawn where R draws them, each to within half a pixel.
expect_drawn_where_r_draws <- function(chart, call, strings, env = parent.frame()) {
  reference <- r_last_page_text_at(call, env)
  for (string in strings) {
    drawn <- chart$text_at[chart$text_at$string == string, c("x", "y")]
    r <- reference[reference$string == string, c("x", "y")]
    testthat::expect_identical(nrow(drawn), nrow(r), label = string)
    if (nrow(drawn) == nrow(r)) {
      testthat::expect_lt(max(abs(as.matrix(drawn) - as.matrix(r))), 0.5, label = string)
    }
  }
}

# The layers of every cell of an exported chart, row by row.
last_page_cells <- function(chart) {
  unlist(
    lapply(chart$schema$subplots, function(row) lapply(row, function(cell) cell$layers)),
    recursive = FALSE
  )
}

# The element ids a layer's selectors name, unescaped.
selector_ids <- function(layer) {
  flat <- unlist(layer$selectors, use.names = FALSE)
  ids <- regmatches(flat, regexpr("graphics-plot-[0-9]+-[a-z-]+[0-9.\\\\]*", flat))
  unique(gsub("\\\\", "", ids))
}

test_that("a plot that starts a new page is the chart, drawn and read as R draws it", {
  skip_if_no_render()
  call <- quote({
    hist(mtcars$mpg)
    hist(mtcars$hp)
  })
  chart <- last_page_export(function() eval(call))

  # One layer: the histogram R's device shows, with its counts.
  layers <- last_page_cells(chart)[[1]]
  testthat::expect_length(layers, 1L)
  testthat::expect_identical(layers[[1]]$title, "Histogram of mtcars$hp")
  testthat::expect_equal(
    vapply(layers[[1]]$data, function(bar) bar$y, numeric(1)),
    graphics::hist(mtcars$hp, plot = FALSE)$counts
  )

  # The drawing is the page R draws, and nothing of the page before it.
  testthat::expect_setequal(chart$strings, r_last_page_strings(call))
  testthat::expect_false(any(grepl("mpg", chart$strings, fixed = TRUE)))
})

test_that("a plot of another type on a new page leaves the one before out", {
  skip_if_no_render()

  heat <- last_page_export(function() {
    plot(1:5)
    heatmap(matrix(1:9, 3, dimnames = list(letters[1:3], LETTERS[1:3])))
  })
  testthat::expect_identical(
    vapply(last_page_cells(heat)[[1]], function(layer) layer$type, character(1)),
    "heat"
  )
  testthat::expect_false("Index" %in% heat$strings)

  points <- last_page_export(function() {
    barplot(c(a = 3, b = 5, c = 2))
    plot(c(10, 20, 15))
  })
  layers <- last_page_cells(points)[[1]]
  testthat::expect_identical(
    vapply(layers, function(layer) layer$type, character(1)),
    "point"
  )
  testthat::expect_equal(
    vapply(layers[[1]]$data, function(point) point$y, numeric(1)),
    c(10, 20, 15)
  )
  # The bar names drawn under the barplot are on the page before.
  testthat::expect_false(any(c("a", "b", "c") %in% points$strings))
})

test_that("calls added to a plot on an earlier page stay with that page", {
  skip_if_no_render()

  chart <- last_page_export(function() {
    hist(mtcars$mpg, freq = FALSE)
    lines(stats::density(mtcars$mpg))
    title(sub = "fuel")
    hist(mtcars$hp)
  })
  layers <- last_page_cells(chart)[[1]]

  testthat::expect_identical(
    vapply(layers, function(layer) layer$type, character(1)),
    "hist"
  )
  testthat::expect_null(chart$schema$subtitle)
  testthat::expect_false("fuel" %in% chart$strings)
})

test_that("the chart is titled from its own page only", {
  skip_if_no_render()

  chart <- last_page_export(function() {
    plot(1:5, main = "First page")
    barplot(c(a = 1, b = 2))
  })

  # barplot() gives no title, and R draws none above it.
  testthat::expect_null(chart$schema$title)
  testthat::expect_false("First page" %in% chart$strings)
  testthat::expect_identical(
    vapply(last_page_cells(chart)[[1]], function(layer) layer$type, character(1)),
    "bar"
  )
})

test_that("a grid followed by a plot after a reset is that plot alone", {
  skip_if_no_render()
  call <- quote({
    par(mfrow = c(2, 2))
    for (i in 1:4) plot(seq_len(i + 1), main = paste("panel", i))
    par(mfrow = c(1, 1))
    plot(1:3, main = "last")
  })
  chart <- last_page_export(function() eval(call))

  testthat::expect_length(chart$schema$subplots, 1L)
  testthat::expect_length(chart$schema$subplots[[1]], 1L)
  layers <- chart$schema$subplots[[1]][[1]]$layers
  testthat::expect_length(layers, 1L)
  testthat::expect_identical(layers[[1]]$title, "last")
  testthat::expect_setequal(chart$strings, r_last_page_strings(call))
})

test_that("plot.new() and frame() take a panel, as they do in R", {
  skip_if_no_render()

  # plot.new() takes the fourth panel of the first page, so the fifth
  # plot is drawn on a page of its own, in its first panel.
  call <- quote({
    par(mfrow = c(2, 2))
    for (i in 1:3) plot(seq_len(i + 1), main = paste("panel", i))
    plot.new()
    plot(1:6, main = "next page")
  })
  chart <- last_page_export(function() eval(call))
  testthat::expect_identical(
    lapply(last_page_cells(chart), function(layers) {
      vapply(layers, function(layer) layer$title, character(1))
    }),
    list("next page", character(0), character(0), character(0))
  )
  testthat::expect_setequal(chart$strings, r_last_page_strings(call))

  framed <- last_page_export(function() {
    par(mfrow = c(1, 2))
    plot(1:3, main = "left")
    frame()
    plot(4:6, main = "after frame")
  })
  testthat::expect_identical(
    lapply(last_page_cells(framed), function(layers) {
      vapply(layers, function(layer) layer$title, character(1))
    }),
    list("after frame", character(0))
  )
})

test_that("a plot drawn after par(new = TRUE) is drawn on the page with the one before", {
  skip_if_no_render()
  call <- quote({
    plot(1:5, main = "first")
    par(new = TRUE)
    plot(5:1, main = "second", col = 2)
  })
  chart <- last_page_export(function() eval(call))
  layers <- last_page_cells(chart)[[1]]

  testthat::expect_identical(
    vapply(layers, function(layer) layer$title, character(1)),
    c("first", "second")
  )
  # Both plots are in the drawing, and each layer addresses its own marks.
  ids <- lapply(layers, selector_ids)
  testthat::expect_identical(ids, list("graphics-plot-1-points-1.1", "graphics-plot-2-points-1.1"))
  for (id in unlist(ids)) {
    testthat::expect_true(id %in% chart$ids, label = id)
  }
  testthat::expect_setequal(chart$strings, r_last_page_strings(call))
})

# The layers of each cell of an exported chart, as their titles.
cell_titles <- function(chart) {
  lapply(last_page_cells(chart), function(layers) {
    vapply(layers, function(layer) layer$title, character(1))
  })
}

# Every selector of every layer names an element the drawing has.
expect_selectors_drawn <- function(chart) {
  for (layers in last_page_cells(chart)) {
    for (layer in layers) {
      ids <- selector_ids(layer)
      testthat::expect_length(ids, 1L)
      testthat::expect_true(any(startsWith(chart$ids, ids)), label = ids)
    }
  }
}

test_that("a plot drawn after par(new = TRUE) shares the panel of the one before", {
  skip_if_no_render()
  call <- quote({
    par(mfrow = c(1, 2))
    plot(1:3, main = "a")
    par(new = TRUE)
    plot(3:1, main = "b")
    plot(4:6, main = "c")
  })
  chart <- last_page_export(function() eval(call))

  testthat::expect_identical(cell_titles(chart), list(c("a", "b"), "c"))
  testthat::expect_identical(
    lapply(last_page_cells(chart), function(layers) unlist(lapply(layers, selector_ids))),
    list(
      c("graphics-plot-1-points-1.1", "graphics-plot-2-points-1.1"),
      "graphics-plot-3-points-1.1"
    )
  )
  expect_selectors_drawn(chart)
  testthat::expect_setequal(chart$strings, r_last_page_strings(call))
  # Each where R draws it: `c` in the second panel, not over `b`.
  expect_drawn_where_r_draws(chart, call, c("a", "b", "c"))

  # An overlay in the first of four panels leaves the next plots in theirs.
  grid <- quote({
    par(mfrow = c(2, 2))
    plot(1:5, main = "P1")
    par(new = TRUE)
    plot(5:1, axes = FALSE, xlab = "", ylab = "", type = "l")
    plot(c(2, 1, 3), main = "P2")
    barplot(c(a = 1, b = 3), main = "P3")
  })
  chart <- last_page_export(function() eval(grid))
  testthat::expect_identical(
    vapply(last_page_cells(chart), length, integer(1)),
    c(2L, 1L, 1L, 0L)
  )
  expect_drawn_where_r_draws(chart, grid, c("P1", "P2", "P3"))
})

test_that("a plot that lays out its own page after a grid is the chart alone", {
  skip_if_no_render()

  # heatmap() sets up a layout of its own, on a page of its own. The grid
  # before it was still read as the page's, with an empty panel beside the
  # heatmap that is not on R's page.
  call <- quote({
    par(mfrow = c(1, 2))
    plot(1:3)
    heatmap(as.matrix(mtcars[1:6, 1:4]))
  })
  chart <- last_page_export(function() eval(call))
  testthat::expect_length(chart$schema$subplots, 1L)
  testthat::expect_length(chart$schema$subplots[[1]], 1L)
  testthat::expect_identical(
    vapply(last_page_cells(chart)[[1]], function(layer) layer$type, character(1)),
    "heat"
  )
  # The drawing, which draws some labels empty, has R's.
  testthat::expect_setequal(chart$strings[nzchar(chart$strings)], r_last_page_strings(call))

  # A plot after it is in the grid again, as R puts it there.
  after <- last_page_export(function() {
    par(mfrow = c(1, 2))
    heatmap(as.matrix(mtcars[1:6, 1:4]))
    plot(1:3, main = "after")
  })
  testthat::expect_identical(cell_titles(after), list("after", character(0)))
})

test_that("a plot drawn with add = TRUE highlights nothing of the plot it is drawn over", {
  skip_if_no_render()

  # Its bars are named after the plot they are drawn over, and its layer
  # addressed that plot's own bars, which it then highlighted; or, on a
  # page of one panel, those of a plot drawn after it with par(new = TRUE).
  names_drawn <- function(chart, layer) {
    vapply(selector_ids(layer), function(id) any(startsWith(chart$ids, id)), logical(1))
  }
  grid <- last_page_export(function() {
    par(mfrow = c(1, 2))
    barplot(c(5, 3, 4), ylim = c(0, 6))
    barplot(c(2, 1, 3), add = TRUE, col = "red")
    plot(1:5)
  })
  layers <- last_page_cells(grid)[[1]]
  testthat::expect_length(layers, 2L)
  testthat::expect_true(all(names_drawn(grid, layers[[1]])))
  testthat::expect_false(any(names_drawn(grid, layers[[2]])))

  single <- last_page_export(function() {
    barplot(c(5, 3, 4), ylim = c(0, 6))
    barplot(c(2, 1, 3), add = TRUE, col = "red")
    par(new = TRUE)
    barplot(c(1, 1, 1), ylim = c(0, 6), axes = FALSE)
  })
  layers <- last_page_cells(single)[[1]]
  testthat::expect_length(layers, 3L)
  testthat::expect_false(any(names_drawn(single, layers[[2]])))
  testthat::expect_true(all(names_drawn(single, layers[[3]])))
})

test_that("a panel plot.new() or frame() passes over stays empty", {
  skip_if_no_render()
  call <- quote({
    par(mfrow = c(1, 2))
    plot.new()
    plot(1:3, main = "right")
  })
  chart <- last_page_export(function() eval(call))
  testthat::expect_identical(cell_titles(chart), list(character(0), "right"))
  expect_selectors_drawn(chart)
  testthat::expect_setequal(chart$strings, r_last_page_strings(call))

  laid_out <- quote({
    layout(matrix(1:3, 1))
    plot(1:3, main = "first")
    frame()
    plot(3:1, main = "third")
  })
  chart <- last_page_export(function() eval(laid_out))
  testthat::expect_identical(cell_titles(chart), list("first", character(0), "third"))
  expect_selectors_drawn(chart)
  testthat::expect_setequal(chart$strings, r_last_page_strings(laid_out))
})

test_that("a low-level call on a plot no recorded call started is drawn there, read with none", {
  skip_if_no_render()

  # A panel of its own for a legend: the plots after it go on in the panels
  # after it, and each highlights its own marks.
  legend_panel <- quote({
    par(mfrow = c(2, 2))
    hist(mtcars$mpg, main = "MPG")
    plot.new()
    legend("center", legend = c("4 cyl", "6 cyl", "8 cyl"), pch = 19, col = 1:3, title = "Key")
    plot(mtcars$wt, mtcars$mpg, pch = 19, main = "Weight")
    barplot(table(mtcars$cyl), main = "Counts")
  })
  chart <- last_page_export(function() eval(legend_panel))
  testthat::expect_identical(
    cell_titles(chart),
    list("MPG", character(0), "Weight", "Counts")
  )
  expect_selectors_drawn(chart)
  expect_drawn_where_r_draws(
    chart, legend_panel, c("MPG", "Key", "4 cyl", "8 cyl", "Weight", "Counts")
  )

  noted <- quote({
    par(mfrow = c(2, 2))
    plot(1:3, main = "A")
    plot(3:1, main = "B")
    frame()
    mtext("Blank panel note", side = 3)
    plot(c(1, 3, 2), main = "D")
  })
  chart <- last_page_export(function() eval(noted))
  testthat::expect_identical(cell_titles(chart), list("A", "B", character(0), "D"))
  expect_selectors_drawn(chart)
  expect_drawn_where_r_draws(chart, noted, c("A", "B", "Blank panel note", "D"))

  # Before the page's first recorded plot. Each text() is set on its
  # baseline: centred, svglite and the drawing's grid text place it a pixel
  # apart, on any plot.
  leading <- quote({
    par(mfrow = c(1, 2))
    plot.new()
    text(0.5, 0.5, "Note panel", adj = c(0.5, 0))
    hist(mtcars$mpg, main = "Right hist")
  })
  chart <- last_page_export(function() eval(leading))
  testthat::expect_identical(cell_titles(chart), list(character(0), "Right hist"))
  expect_selectors_drawn(chart)
  expect_drawn_where_r_draws(chart, leading, c("Note panel", "Right hist"))

  # On a plot maidr does not record: drawn over it, in its coordinates, and
  # not read as a layer of the histogram before it.
  testthat::skip_if_not_installed("KernSmooth")
  unrecorded <- quote({
    par(mfrow = c(1, 2))
    hist(mtcars$mpg, main = "Left hist")
    smoothScatter(mtcars$wt, mtcars$mpg, main = "Right smooth")
    abline(h = 20)
    text(4, 30, "smoothed", adj = c(0.5, 0))
  })
  chart <- last_page_export(function() eval(unrecorded))
  testthat::expect_identical(
    lapply(last_page_cells(chart), function(layers) {
      vapply(layers, function(layer) layer$type, character(1))
    }),
    list("hist", character(0))
  )
  expect_drawn_where_r_draws(chart, unrecorded, c("Left hist", "smoothed"))
  testthat::expect_true(any(startsWith(chart$ids, "graphics-plot-2-abline")))
})

test_that("a plot after one that drew several panels is in the panel R drew it in", {
  skip_if_no_render()
  call <- quote({
    par(mfrow = c(2, 3))
    plot(stats::lm(mpg ~ wt, data = mtcars), which = 1:4)
    hist(mtcars$mpg, main = "fifth")
  })
  chart <- last_page_export(function() eval(call))

  # The histogram is the fifth panel, in reading order the second row's
  # second cell, and the fifth plot of the drawing.
  hist_layer <- chart$schema$subplots[[2]][[2]]$layers
  testthat::expect_identical(
    vapply(hist_layer, function(layer) layer$title, character(1)),
    "fifth"
  )
  testthat::expect_match(selector_ids(hist_layer[[1]]), "^graphics-plot-5-rect")
  expect_selectors_drawn(chart)
  testthat::expect_true("fifth" %in% chart$strings)
})

test_that("a plot par(fig = ) or a screen placed is drawn in the region R gave it", {
  skip_if_no_render()

  # An inset, which was drawn over the whole of the plot it sits in.
  inset <- quote({
    plot(1:10, main = "Main")
    par(fig = c(0.55, 0.95, 0.15, 0.55), new = TRUE)
    hist(mtcars$mpg, main = "Inset")
  })
  chart <- last_page_export(function() eval(inset))
  testthat::expect_identical(cell_titles(chart), list(c("Main", "Inset")))
  expect_selectors_drawn(chart)
  testthat::expect_setequal(chart$strings, r_last_page_strings(inset))
  expect_drawn_where_r_draws(chart, inset, c("Main", "Inset"))

  # The screens of split.screen(), one beside the other.
  screens <- quote({
    split.screen(c(1, 2))
    screen(1)
    plot(1:3, main = "S1")
    screen(2)
    hist(mtcars$mpg, main = "S2")
    close.screen(all.screens = TRUE)
  })
  chart <- last_page_export(function() eval(screens))
  expect_selectors_drawn(chart)
  testthat::expect_setequal(chart$strings, r_last_page_strings(screens))
  expect_drawn_where_r_draws(chart, screens, c("S1", "S2"))
})

test_that("a plot par(mfg = ) sends out of turn is in the panel R drew it in", {
  skip_if_no_render()

  # On, past a panel: it was read and drawn in the first, over the plot
  # there.
  forward <- quote({
    par(mfrow = c(2, 2))
    plot(1:3, main = "TL")
    par(mfg = c(2, 2))
    plot(3:1, main = "BR")
  })
  chart <- last_page_export(function() eval(forward))
  testthat::expect_identical(
    cell_titles(chart),
    list("TL", character(0), character(0), "BR")
  )
  expect_selectors_drawn(chart)
  expect_drawn_where_r_draws(chart, forward, c("TL", "BR"))

  # Back, over a plot drawn before: it was read and drawn over the last.
  # A plot after it moves on from there, as R moves on.
  back <- quote({
    par(mfcol = c(1, 3))
    plot(1:3, main = "one")
    plot(1:3, main = "two")
    plot(1:3, main = "three")
    par(mfg = c(1, 1))
    plot(3:1, main = "over one")
    plot(3:1, main = "over two")
  })
  chart <- last_page_export(function() eval(back))
  testthat::expect_identical(
    cell_titles(chart),
    list(c("one", "over one"), c("two", "over two"), "three")
  )
  expect_drawn_where_r_draws(chart, back, c("one", "two", "three", "over one", "over two"))
})

test_that("a call made by another as it draws is read and drawn once, where R drew it", {
  skip_if_no_render()

  # `grid()` is recorded as `plot()` draws it, before `plot()` is: it kept
  # neither plot in its panel, and the third was drawn over the first.
  call <- quote({
    par(mfrow = c(2, 2))
    plot(1:3, panel.first = grid(), main = "first")
    plot.new()
    plot(3:1, panel.first = grid(), main = "third")
  })
  chart <- last_page_export(function() eval(call))
  testthat::expect_identical(
    cell_titles(chart),
    list("first", character(0), "third", character(0))
  )
  expect_selectors_drawn(chart)
  expect_drawn_where_r_draws(chart, call, c("first", "third"))

  # A method of an author's own that draws with `plot()` and `lines()`: the
  # two calls it makes are its plot, in the panel R drew them in. It cannot
  # be registered for this test alone, so its class is the test's own.
  registerS3method(
    "plot",
    "maidr_last_page_drawing",
    function(x, ...) {
      plot(x$a, x$b, main = "custom")
      lines(x$a, x$b)
    },
    envir = baseenv()
  )
  drawing <- structure(list(a = 1:5, b = c(2, 4, 3, 5, 1)), class = "maidr_last_page_drawing")
  call <- quote({
    par(mfrow = c(1, 3))
    barplot(c(3, 1, 2), main = "bars")
    plot(drawing)
    hist(mtcars$mpg, main = "third")
  })
  chart <- last_page_export(function() eval(call))
  testthat::expect_identical(
    lapply(last_page_cells(chart), function(layers) {
      vapply(layers, function(layer) layer$type, character(1))
    }),
    list("bar", c("point", "line"), "hist")
  )
  expect_drawn_where_r_draws(chart, call, c("bars", "custom", "third"))

  # On a page of its own it is drawn once, and read once.
  single <- quote(plot(drawing))
  chart <- last_page_export(function() eval(single))
  testthat::expect_identical(
    vapply(last_page_cells(chart)[[1]], function(layer) layer$type, character(1)),
    c("point", "line")
  )
  testthat::expect_identical(sum(chart$strings == "custom"), 1L)
  expect_selectors_drawn(chart)
})

test_that("each recorded plot carries the page, panel and plot number R drew it at", {
  grDevices::pdf(NULL)
  device_id <- grDevices::dev.cur()
  clear_base_r_device(device_id)
  on.exit(
    {
      clear_base_r_device(device_id)
      grDevices::dev.off(device_id)
    },
    add = TRUE
  )
  # R's own answer, read after each plot: the panel it is drawing in.
  seen <- new.env()
  seen$panels <- integer()
  panel_now <- function() {
    mfg <- graphics::par("mfg")
    seen$panels <- c(seen$panels, as.integer((mfg[1] - 1L) * mfg[4] + mfg[2]))
  }
  par(mfrow = c(2, 2))
  plot(1:3)
  panel_now()
  par(new = TRUE)
  plot(3:1)
  panel_now()
  plot.new()
  frame()
  hist(mtcars$mpg)
  panel_now()
  hist(mtcars$hp, add = TRUE)
  panel_now()
  plot(1:3)
  panel_now()

  high <- Filter(
    function(entry) identical(entry$class_level, "HIGH"),
    maidr:::get_device_calls(device_id)
  )
  testthat::expect_identical(vapply(high, function(e) e$figure, integer(1)), seen$panels)
  testthat::expect_identical(vapply(high, function(e) e$plot, integer(1)), c(1L, 2L, 5L, 5L, 1L))
  testthat::expect_identical(
    vapply(high, function(e) e$new_plot, logical(1)),
    c(TRUE, TRUE, TRUE, FALSE, TRUE)
  )
  pages <- vapply(high, function(e) e$page, integer(1))
  testthat::expect_identical(diff(pages), c(0L, 0L, 0L, 1L))
})

test_that("a page that holds no recorded plot is not read as the plot before it", {
  # R's device shows a blank page, a plot maidr does not record, or one
  # drawn while recording was off, and at most a low-level call over it.
  # The histogram before it is not on that page, and is not the chart;
  # what is on it maidr cannot read, or draw: what started it was not
  # recorded. So maidr says so rather than export another page, or nothing.
  started <- list(
    "plot.new()" = function() graphics::plot.new(),
    "frame()" = function() graphics::frame(),
    "ts.plot()" = function() stats::ts.plot(datasets::ldeaths),
    "smoothScatter()" = function() graphics::smoothScatter(mtcars$wt, mtcars$mpg),
    "maidr_off()" = function() {
      maidr_off()
      on.exit(maidr_on(), add = TRUE)
      hist(mtcars$hp)
    },
    "maidr_off(), then abline()" = function() {
      maidr_off()
      on.exit(maidr_on(), add = TRUE)
      hist(mtcars$hp)
      maidr_on()
      abline(v = 100)
    },
    "plot.new(), then text()" = function() {
      graphics::plot.new()
      text(0.5, 0.5, "Only text")
    }
  )
  for (name in names(started)) {
    grDevices::pdf(NULL)
    device_id <- grDevices::dev.cur()
    clear_base_r_device(device_id)
    hist(mtcars$mpg)
    started[[name]]()
    for (export in list(
      function() save_html(file = tempfile(fileext = ".html")),
      function() show(),
      function() maidr:::maidr_widget(NULL)
    )) {
      testthat::expect_error(export(), "holds no Base R plot maidr recorded", label = name)
    }
    clear_base_r_device(device_id)
    grDevices::dev.off(device_id)
  }

  # As on a device that never held a plot.
  grDevices::pdf(NULL)
  device_id <- grDevices::dev.cur()
  clear_base_r_device(device_id)
  on.exit(
    {
      clear_base_r_device(device_id)
      grDevices::dev.off(device_id)
    },
    add = TRUE
  )
  graphics::plot.new()
  text(0.5, 0.5, "Only text")
  testthat::expect_error(
    save_html(file = tempfile(fileext = ".html")),
    "holds no Base R plot maidr recorded"
  )
})

test_that("the size a chart is drawn at is settled by its own page", {
  # A six-row grid does not fit maidr's own 7 x 5 in and is drawn larger,
  # with a message. Drawn on the page before, it says nothing about the
  # picture of the chart R shows now. (The device is tall enough for R to
  # draw the grid on it.)
  grDevices::pdf(NULL, width = 7, height = 20)
  device_id <- grDevices::dev.cur()
  clear_base_r_device(device_id)
  on.exit(
    {
      clear_base_r_device(device_id)
      grDevices::dev.off(device_id)
    },
    add = TRUE
  )
  par(mfrow = c(6, 1))
  for (i in 1:6) plot(1:3)
  par(mfrow = c(1, 1))
  suppressWarnings(draw_unread_base_r_chart())

  orchestrator <- maidr:::BaseRPlotOrchestrator$new(device_id)
  testthat::expect_true(orchestrator$should_fallback())
  testthat::expect_no_message(size <- orchestrator$picture_size())
  testthat::expect_equal(size, c(width = 7, height = 5))
})

test_that("only the calls on the last page are read", {
  entry <- function(name, class_level, page) {
    list(function_name = name, class_level = class_level, page = page)
  }
  calls <- list(
    entry("par", "LAYOUT", 0L),
    entry("hist", "HIGH", 1L),
    entry("lines", "LOW", 1L),
    entry("par", "LAYOUT", 1L),
    entry("hist", "HIGH", 2L),
    entry("abline", "LOW", 2L)
  )
  kept <- maidr:::last_page_calls(calls)
  testthat::expect_identical(
    vapply(kept, function(call) call$function_name, character(1)),
    c("par", "par", "hist", "abline")
  )

  # On a page R started after them, only the layout calls are.
  testthat::expect_identical(
    vapply(maidr:::last_page_calls(calls, page = 3L), function(call) call$function_name, ""),
    c("par", "par")
  )

  # Calls recorded without a page, as code that records calls itself does,
  # are all kept.
  unpaged <- lapply(calls, function(call) {
    call$page <- NULL
    call
  })
  testthat::expect_identical(maidr:::last_page_calls(unpaged), unpaged)
})

test_that("the page count is taken out on unload and set again by a recorded call", {
  counted <- function() {
    any(vapply(getHook("before.plot.new"), identical, NA, maidr:::note_base_r_plot_new))
  }
  maidr:::set_base_r_page_hook()
  maidr:::set_base_r_page_hook()
  testthat::expect_identical(
    sum(vapply(getHook("before.plot.new"), identical, NA, maidr:::note_base_r_plot_new)),
    1L
  )
  maidr:::remove_base_r_page_hook()
  testthat::expect_false(counted())

  grDevices::pdf(NULL)
  device_id <- grDevices::dev.cur()
  on.exit(
    {
      clear_base_r_device(device_id)
      grDevices::dev.off(device_id)
      maidr:::set_base_r_page_hook()
    },
    add = TRUE
  )
  plot(1:3)
  testthat::expect_true(counted())
})
