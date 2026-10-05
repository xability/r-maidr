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

  # Under a grid of the shape of its own, too. R starts a page of a grid in
  # its first cell, and the heatmap's image starts its page in the corner of
  # its own 2 x 2 layout: it was read as cell [2, 2] of the grid, beside
  # three empty panels that are not on R's page.
  square <- last_page_export(function() {
    par(mfrow = c(2, 2))
    plot(1:3)
    heatmap(as.matrix(mtcars[1:6, 1:4]))
  })
  testthat::expect_length(square$schema$subplots, 1L)
  testthat::expect_length(square$schema$subplots[[1]], 1L)
  testthat::expect_identical(
    vapply(last_page_cells(square)[[1]], function(layer) layer$type, character(1)),
    "heat"
  )
  # A plot after it is in the grid again, as R puts it there.
  after <- last_page_export(function() {
    par(mfrow = c(1, 2))
    heatmap(as.matrix(mtcars[1:6, 1:4]))
    plot(1:3, main = "after")
  })
  testthat::expect_identical(cell_titles(after), list("after", character(0)))
})

test_that("a grid no recorded call set up is read from the cells R drew its plots in", {
  skip_if_no_render()

  # R's page, whichever way its grid was set up.
  page <- quote({
    graphics::par(mfrow = c(1, 2))
    hist(mtcars$wt, main = "Left")
    barplot(c(a = 1, b = 3), main = "Right")
  })
  expect_read_as_r_draws <- function(draw) {
    chart <- last_page_export(draw)
    testthat::expect_identical(cell_titles(chart), list("Left", "Right"))
    expect_selectors_drawn(chart)
    expect_drawn_where_r_draws(chart, page, c("Left", "Right", "a", "b"))
  }

  # The par() call was recorded, and cleared with the chart an earlier
  # save_html() on the device saved.
  expect_read_as_r_draws(function() {
    par(mfrow = c(1, 2))
    hist(mtcars$mpg, main = "First")
    hist(mtcars$hp, main = "Second")
    suppressMessages(save_html(file = tempfile(fileext = ".html")))
    hist(mtcars$wt, main = "Left")
    barplot(c(a = 1, b = 3), main = "Right")
  })
  # Set by a call maidr does not record.
  expect_read_as_r_draws(function() eval(page))
  expect_read_as_r_draws(function() {
    withr::with_par(list(mfrow = c(1, 2)), {
      hist(mtcars$wt, main = "Left")
      barplot(c(a = 1, b = 3), main = "Right")
    })
  })

  # A plot that lays out a grid of its own is not in one it was not drawn in.
  pairs <- last_page_export(function() {
    graphics::par(mfrow = c(1, 2))
    pairs(iris[1:3])
  })
  testthat::expect_length(pairs$schema$subplots, 3L)
})

test_that("a layout() no recorded call set up is read from the regions R gave its panels", {
  skip_if_no_render()

  # A panel that spans cells spans them in the chart too, as it does when
  # the layout() call is recorded, and leaves no cell empty.
  expect_read_as_r_draws <- function(page, titles, strings = NULL) {
    for (draw in list(
      function() eval(page),
      # Recorded, and cleared with the chart an earlier save_html() saved.
      function() {
        layout(eval(page[[2]][[2]]))
        for (i in 1:3) plot(i, main = "Before")
        suppressMessages(save_html(file = tempfile(fileext = ".html")))
        eval(page[-2])
      }
    )) {
      chart <- last_page_export(draw)
      testthat::expect_identical(cell_titles(chart), titles)
      expect_selectors_drawn(chart)
      expect_drawn_where_r_draws(chart, page, c(unique(unlist(titles)), strings))
    }
  }
  expect_read_as_r_draws(
    quote({
      graphics::layout(matrix(c(1, 1, 2, 3), 2, byrow = TRUE))
      hist(mtcars$mpg, main = "Top")
      plot(1:3, main = "BL")
      barplot(c(a = 1, b = 2), main = "BR")
    }),
    list("Top", "Top", "BL", "BR")
  )
  expect_read_as_r_draws(
    quote({
      graphics::layout(matrix(c(1, 2, 1, 3), 2, byrow = TRUE))
      hist(mtcars$mpg, main = "Left")
      plot(1:3, main = "TR")
      barplot(c(a = 1, b = 2), main = "BR")
    }),
    list("Left", "TR", "Left", "BR")
  )

  # A panel plot.new() took for a legend is a panel of the layout too, read
  # with no layer: after the last plot, the page R shows was started again
  # for it, and lost every plot; spanning a row, it was drawn in one cell.
  expect_read_as_r_draws(
    quote({
      graphics::layout(matrix(c(1, 1, 2, 3), 2, byrow = TRUE))
      hist(mtcars$mpg, main = "LgTop")
      plot(1:3, main = "LgBL")
      plot.new()
      legend("center", legend = c("alpha", "beta"), fill = 1:2)
    }),
    list("LgTop", "LgTop", "LgBL", character(0)),
    c("alpha", "beta")
  )
  expect_read_as_r_draws(
    quote({
      graphics::layout(matrix(c(1, 2, 3, 3), 2, byrow = TRUE))
      plot(1:3, main = "A1")
      hist(mtcars$mpg, main = "A2")
      plot.new()
      legend("center", legend = c("alpha", "beta"), fill = 1:2, horiz = TRUE)
    }),
    list("A1", "A2", character(0), character(0)),
    c("alpha", "beta")
  )
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

test_that("a plot that opened the device is the first plot of its page", {
  skip_if_no_render()
  testthat::skip_if_not_installed("withr")

  # With no device open, as at the start of a script, the `plot.new()` a
  # note is written on opens one, and a plot is drawn over it after
  # `par(new = TRUE)`.
  while (grDevices::dev.cur() != 1L) grDevices::dev.off()
  withr::local_options(device = function(...) grDevices::pdf(NULL))
  # As in a session that has drawn on no device of the number it opens.
  pages <- maidr:::.maidr_base_r_pages
  pages$at[["2"]] <- NULL
  file <- tempfile(fileext = ".html")
  on.exit(
    {
      while (grDevices::dev.cur() != 1L) grDevices::dev.off()
      clear_all_device_storage()
      unlink(file)
    },
    add = TRUE
  )
  clear_all_device_storage()
  call <- quote({
    plot.new()
    text(0.5, 0.95, "Topnote", adj = c(0.5, 0))
    par(new = TRUE)
    plot(1:3, main = "Over")
  })
  eval(call)
  suppressWarnings(suppressMessages(save_html(file = file)))

  document <- xml2::read_html(file)
  chart <- list(
    strings = last_page_strings(document),
    ids = xml2::xml_attr(xml2::xml_find_all(document, "//*[@id]"), "id"),
    schema = schema_from(paste(readLines(file, warn = FALSE), collapse = "\n")),
    text_at = maidr_text_at(document)
  )
  testthat::expect_identical(cell_titles(chart), list("Over"))
  expect_selectors_drawn(chart)
  expect_drawn_where_r_draws(chart, call, c("Topnote", "Over"))
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

test_that("a series drawn over a plot on a plot.new() of its panel is read with it", {
  skip_if_no_render()

  # A second series with an axis of its own, on a plot started over the
  # first after par(new = TRUE), in the same panel.
  dual <- quote({
    x <- 1:10
    plot(x, x^2, type = "l", main = "Dual", ylab = "squares")
    par(new = TRUE)
    plot.new()
    plot.window(xlim = range(x), ylim = c(0, 1))
    lines(x, sqrt(x) / sqrt(10), col = "red")
    axis(4)
  })
  chart <- last_page_export(function() eval(dual))
  layers <- last_page_cells(chart)[[1]]
  testthat::expect_identical(
    vapply(layers, function(layer) layer$type, character(1)),
    c("line", "line")
  )
  series <- function(layer) unlist(lapply(layer$data[[1]], function(point) point$y))
  testthat::expect_equal(series(layers[[1]]), (1:10)^2)
  testthat::expect_equal(series(layers[[2]]), sqrt(1:10) / sqrt(10))
  # Each highlights its own line.
  first <- selector_ids(layers[[1]])
  second <- selector_ids(layers[[2]])
  testthat::expect_false(identical(first, second))
  expect_selectors_drawn(chart)
  testthat::expect_setequal(chart$strings[nzchar(chart$strings)], r_last_page_strings(dual))
  expect_drawn_where_r_draws(chart, dual, "Dual")

  # Over the plot of an earlier panel or screen, which par(mfg = ) or
  # screen() sent R back to: it was read as part of no plot, or with the
  # plot drawn last. A page of screens is read as one subplot.
  shapes <- list(
    list(
      back = quote({
        par(mfrow = c(1, 2))
        plot(1:10, main = "PA")
        plot(10:1, main = "PB")
        par(mfg = c(1, 1))
      }),
      cells = list(c("PA", ""), "PB")
    ),
    list(
      back = quote({
        split.screen(c(1, 2))
        screen(1)
        plot(1:10, main = "PA")
        screen(2)
        plot(10:1, main = "PB")
        screen(1, new = FALSE)
      }),
      cells = list(c("PA", "", "PB"))
    )
  )
  for (shape in shapes) {
    over_earlier <- bquote({
      .(shape$back)
      par(new = TRUE)
      plot.new()
      plot.window(c(1, 10), c(0, 100))
      points(1:10, (1:10)^2, col = "red", pch = 19)
      axis(4)
      text(5.5, 50, "squares", adj = c(0.5, 0))
      close.screen(all.screens = TRUE)
    })
    chart <- last_page_export(function() eval(over_earlier))
    testthat::expect_identical(cell_titles(chart), shape$cells)
    over <- last_page_cells(chart)[[1]][[2]]
    testthat::expect_equal(unlist(lapply(over$data, function(point) point$y)), (1:10)^2)
    expect_selectors_drawn(chart)
    expect_drawn_where_r_draws(chart, over_earlier, c("PA", "PB", "squares"))
  }
})

test_that("the picture of a page draws a call on a plot no recorded call started where R did", {
  testthat::skip_if_not_installed("svglite")

  # A page maidr shows as a picture, as it does a sunflowerplot(), with a
  # note on a panel of its own.
  noted <- quote({
    par(mfrow = c(1, 2))
    sunflowerplot(iris[, 3:4], main = "Sun")
    plot.new()
    text(0.5, 0.5, "Note panel", adj = c(0.5, 0))
  })
  grDevices::pdf(NULL)
  device_id <- grDevices::dev.cur()
  clear_base_r_device(device_id)
  file <- tempfile(fileext = ".svg")
  on.exit(
    {
      clear_base_r_device(device_id)
      if (device_id %in% grDevices::dev.list()) grDevices::dev.off(device_id)
      unlink(file)
    },
    add = TRUE
  )
  eval(noted)
  svglite::svglite(file, width = 7, height = 5)
  tryCatch(maidr:::replay_base_r_plot(device_id), finally = grDevices::dev.off())

  texts <- xml2::xml_find_all(xml2::read_xml(file), "//*[local-name()='text']")
  picture <- data.frame(
    string = trimws(xml2::xml_text(texts)),
    x = as.numeric(xml2::xml_attr(texts, "x")),
    y = 360 - as.numeric(xml2::xml_attr(texts, "y"))
  )
  reference <- r_last_page_text_at(noted)
  for (string in c("Sun", "Note panel")) {
    drawn <- picture[picture$string == string, c("x", "y")]
    r <- reference[reference$string == string, c("x", "y")]
    testthat::expect_identical(nrow(drawn), 1L, label = string)
    testthat::expect_lt(max(abs(as.matrix(drawn) - as.matrix(r))), 0.5, label = string)
  }
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

  # The whole page, over a grid, as a legend for all its panels is drawn:
  # it was drawn in the grid's last panel, and, where the grid was not
  # recorded, every plot of the grid was drawn in one.
  for (grid in list(quote(par(mfrow = c(2, 2))), quote(graphics::par(mfrow = c(2, 2))))) {
    legend_over_grid <- bquote({
      .(grid)
      for (i in 1:4) plot(seq_len(5) * i, main = paste("P", i))
      par(fig = c(0, 1, 0, 1), oma = c(0, 0, 0, 0), mar = c(0, 0, 0, 0), new = TRUE)
      plot(0, 0, type = "l", bty = "n", xaxt = "n", yaxt = "n")
      legend("bottom", c("alpha", "beta"), xpd = TRUE, horiz = TRUE, bty = "n", lty = 1, col = 1:2)
    })
    chart <- last_page_export(function() eval(legend_over_grid))
    testthat::expect_identical(
      lapply(cell_titles(chart), function(titles) titles[[1]]),
      list("P 1", "P 2", "P 3", "P 4")
    )
    expect_drawn_where_r_draws(
      chart, legend_over_grid, c("P 1", "P 2", "P 3", "P 4", "alpha", "beta")
    )
  }

  # The whole page, over a grid, after par(mfrow = c(1, 1), new = TRUE):
  # the grid was read as one panel, and its plots drawn over each other.
  reset_over_grid <- quote({
    par(mfrow = c(1, 2))
    plot(1:5, main = "M1")
    plot(5:1, main = "M2")
    par(mfrow = c(1, 1), new = TRUE, mar = c(0, 0, 0, 0))
    plot(0, 0, type = "l", bty = "n", xaxt = "n", yaxt = "n")
    legend("bottom", c("alpha", "beta"), lty = 1, col = 1:2, horiz = TRUE, bty = "n", xpd = TRUE)
  })
  chart <- last_page_export(function() eval(reset_over_grid))
  testthat::expect_identical(
    lapply(cell_titles(chart), function(titles) titles[[1]]),
    list("M1", "M2")
  )
  expect_drawn_where_r_draws(chart, reset_over_grid, c("M1", "M2", "alpha", "beta"))

  # The whole page, over regions or screens: it was drawn in the last.
  for (regions in list(
    quote({
      par(fig = c(0, 0.5, 0, 1))
      plot(1:5, main = "RL")
      par(fig = c(0.5, 1, 0, 1), new = TRUE)
      plot(5:1, main = "RR")
    }),
    quote({
      split.screen(c(1, 2))
      screen(1)
      plot(1:5, main = "RL")
      screen(2)
      plot(5:1, main = "RR")
      close.screen(all.screens = TRUE)
    })
  )) {
    legend_over_regions <- bquote({
      .(regions)
      par(fig = c(0, 1, 0, 1), new = TRUE, mar = c(0, 0, 0, 0))
      plot(0, 0, type = "l", bty = "n", xaxt = "n", yaxt = "n")
      legend("bottom", c("alpha", "beta"), xpd = TRUE, horiz = TRUE, bty = "n", lty = 1, col = 1:2)
    })
    chart <- last_page_export(function() eval(legend_over_regions))
    expect_drawn_where_r_draws(chart, legend_over_regions, c("RL", "RR", "alpha", "beta"))
  }
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

test_that("a call on a panel par(mfg = ) sends R to is drawn in that panel", {
  skip_if_no_render()

  # A legend on a panel of its own, out of turn. par(mfg = ) does not move
  # R's count of panels on, and the legend was read as drawn over the plot
  # before it: that plot, and the one after it, were lost from the drawing.
  legend_panel <- quote({
    par(mfrow = c(1, 3))
    plot(1:3, main = "QA")
    par(mfg = c(1, 3))
    plot.new()
    legend("center", legend = c("qa", "qb"), pch = 1:2)
    par(mfg = c(1, 2))
    hist(mtcars$mpg, main = "QB")
  })
  chart <- last_page_export(function() eval(legend_panel))
  testthat::expect_identical(cell_titles(chart), list("QA", "QB", character(0)))
  expect_selectors_drawn(chart)
  testthat::expect_setequal(chart$strings, r_last_page_strings(legend_panel))
  expect_drawn_where_r_draws(chart, legend_panel, c("QA", "QB", "qa", "qb"))

  # Back to the panel of an earlier plot: what is drawn there is read with
  # the plot there, not with the plot before it, and the plot after it
  # moves on from there.
  back <- quote({
    par(mfrow = c(2, 2))
    plot(1:3, main = "M1")
    plot(3:1, main = "M2")
    par(mfg = c(1, 1))
    plot.new()
    plot.window(c(0, 1), c(0, 1))
    lines(c(0, 1), c(1, 0), col = "red")
    text(0.5, 0.5, "Over M1", adj = c(0.5, 0))
    plot(2:4, main = "M3")
  })
  chart <- last_page_export(function() eval(back))
  testthat::expect_identical(
    cell_titles(chart),
    list(c("M1", ""), c("M2", "M3"), character(0), character(0))
  )
  expect_selectors_drawn(chart)
  expect_drawn_where_r_draws(chart, back, c("M1", "M2", "M3", "Over M1"))
})

test_that("a call made after R was sent back to a plot is drawn and read with that plot", {
  skip_if_no_render()

  # screen(n, new = FALSE) puts back screen n and the coordinates of its
  # plot, to add to it, as ?split.screen's own example does. The line was
  # read as a layer of the plot in the other screen, and drawn on it.
  screens <- quote({
    split.screen(c(1, 2))
    screen(1)
    plot(1:10, main = "ScA")
    screen(2)
    plot(c(50, 40, 30, 20, 10), main = "ScB")
    screen(1, new = FALSE)
    abline(h = 5, col = "red")
    text(5, 5.6, "on ScA", adj = c(0.5, 0))
    close.screen(all.screens = TRUE)
  })
  chart <- last_page_export(function() eval(screens))
  testthat::expect_identical(cell_titles(chart), list(c("ScA", "ScA", "ScB")))
  line <- last_page_cells(chart)[[1]][[2]]
  testthat::expect_identical(line$type, "line")
  testthat::expect_equal(unlist(lapply(line$data[[1]], function(point) point$y)), c(5, 5))
  expect_selectors_drawn(chart)
  expect_drawn_where_r_draws(chart, screens, c("ScA", "ScB", "on ScA"))

  # par(mfg = ) keeps the coordinates of the plot R was on: what is drawn
  # in the panel it sends R to is drawn in them.
  panels <- quote({
    par(mfrow = c(1, 2))
    plot(1:5, main = "Left")
    plot(c(10, 20, 30, 40, 50), main = "Right")
    par(mfg = c(1, 1))
    abline(h = 30, col = "red")
    text(3, 33, "in Right's", adj = c(0.5, 0))
  })
  chart <- last_page_export(function() eval(panels))
  testthat::expect_identical(cell_titles(chart), list(c("Left", "Left"), "Right"))
  expect_selectors_drawn(chart)
  expect_drawn_where_r_draws(chart, panels, c("Left", "Right", "in Right's"))
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

test_that("symbols() drawing a plot of its own is the plot of its page", {
  skip_if_no_render()

  # symbols() is a low-level call that, without add = TRUE, starts a plot, on
  # a page of its own after another. It was read as one added to the plot
  # before it, so the page R shows held no plot, and the chart was empty:
  # nothing drawn, nothing read. maidr does not read it, so the chart is a
  # picture of it, as it was when the plot before it was read too.
  for (draw in list(
    function() {
      hist(mtcars$mpg)
      symbols(mtcars$wt, mtcars$mpg, circles = mtcars$hp / 100, inches = 0.2, main = "Bubbles")
    },
    function() {
      plot(1:3, main = "first")
      symbols(1:3, c(2, 1, 3), circles = 1:3, main = "Bubbles")
    },
    function() symbols(1:3, c(2, 1, 3), circles = 1:3, main = "Bubbles")
  )) {
    grDevices::pdf(NULL)
    device_id <- grDevices::dev.cur()
    clear_base_r_device(device_id)
    file <- tempfile(fileext = ".html")
    draw()
    groups <- maidr:::group_device_calls(device_id)$groups
    suppressWarnings(save_html(file = file))
    clear_base_r_device(device_id)
    grDevices::dev.off(device_id)

    testthat::expect_identical(
      vapply(groups, function(group) group$high_call$function_name, character(1)),
      "symbols"
    )
    html <- paste(readLines(file, warn = FALSE), collapse = "\n")
    unlink(file)
    testthat::expect_true(grepl("data:image/png;base64", html, fixed = TRUE))
    testthat::expect_false(grepl("maidr-data", html, fixed = TRUE))
  }
})

test_that("a call whose argument drew a plot is drawn on that plot, and read with it", {
  skip_if_no_render()
  h <- c(A = 3, B = 5, C = 2)

  # barplot() draws while text()'s arguments are evaluated, and text()
  # labels its bars. The labels were left out: the text() call was taken to
  # draw nothing of its own beside the barplot() it made.
  labelled <- quote(
    text(barplot(h, ylim = c(0, 6), main = "Bars"), h, labels = paste0("v", h), pos = 3)
  )
  chart <- last_page_export(function() eval(labelled))
  testthat::expect_identical(cell_titles(chart), list("Bars"))
  expect_drawn_where_r_draws(chart, labelled, c("Bars", "v3", "v5", "v2"))

  in_grid <- quote({
    par(mfrow = c(1, 2))
    text(barplot(h, ylim = c(0, 6), main = "Bars"), h, labels = paste0("v", h), pos = 3)
    hist(mtcars$mpg, main = "Hist")
  })
  chart <- last_page_export(function() eval(in_grid))
  testthat::expect_identical(cell_titles(chart), list("Bars", "Hist"))
  expect_selectors_drawn(chart)
  expect_drawn_where_r_draws(chart, in_grid, c("Bars", "v3", "v5", "v2", "Hist"))

  # A line drawn after the points its argument drew.
  chart <- last_page_export(function() {
    plot(1:5, main = "base")
    lines(1:5, {
      points(1:5, 5:1)
      c(2, 3, 2, 3, 2)
    })
  })
  testthat::expect_identical(
    vapply(last_page_cells(chart)[[1]], function(layer) layer$type, character(1)),
    c("point", "point", "line")
  )

  # Error bars maidr does not read make the chart a picture, as they do
  # drawn on a barplot drawn before them.
  grDevices::pdf(NULL)
  device_id <- grDevices::dev.cur()
  clear_base_r_device(device_id)
  file <- tempfile(fileext = ".html")
  arrows(barplot(h, ylim = c(0, 7)), h - 1, y1 = h + 1, angle = 90, code = 3)
  suppressWarnings(save_html(file = file))
  clear_base_r_device(device_id)
  grDevices::dev.off(device_id)
  html <- paste(readLines(file, warn = FALSE), collapse = "\n")
  unlink(file)
  testthat::expect_true(grepl("data:image/png;base64", html, fixed = TRUE))
})

test_that("a call that ran onto the page R shows is drawn with only its plots on it", {
  skip_if_no_render()
  fit <- stats::lm(mpg ~ wt, data = mtcars)

  # plot() of a fitted model draws four plots. Started in the second panel,
  # it fills the first page and draws its last on a page of its own, which
  # R shows. It was drawn whole from the first panel of that page.
  for (diagnostics in list(
    quote({
      par(mfrow = c(2, 2))
      hist(mtcars$mpg, main = "Hist first")
      plot(fit)
    }),
    quote({
      par(mfrow = c(1, 2))
      plot(1:3, main = "Before")
      plot(fit)
    })
  )) {
    chart <- last_page_export(function() eval(diagnostics))
    expect_drawn_where_r_draws(chart, diagnostics, "Residuals vs Leverage")
    testthat::expect_false(
      any(c("Residuals vs Fitted", "Q-Q Residuals", "Scale-Location") %in% chart$strings)
    )
  }

  # So with termplot(): only the term on R's page is read.
  terms <- stats::lm(mpg ~ wt + hp + qsec + drat, data = mtcars)
  partial <- quote({
    par(mfrow = c(2, 2))
    hist(mtcars$mpg, main = "Before")
    termplot(terms)
  })
  chart <- last_page_export(function() eval(partial))
  testthat::expect_identical(
    vapply(unlist(last_page_cells(chart), recursive = FALSE), function(layer) {
      layer$axes$x$label
    }, character(1)),
    "drat"
  )
  testthat::expect_setequal(chart$strings[nzchar(chart$strings)], r_last_page_strings(partial))
})

test_that("a page replayPlot() puts back is the page read", {
  skip_if_no_render()

  # R does not start a plot when it replays a page, as RStudio's device does
  # with a display list, so the page R shows is not the last it started.
  replayed <- function(after = NULL) {
    function() {
      grDevices::dev.control("enable")
      hist(mtcars$mpg, main = "First")
      shown <- grDevices::recordPlot()
      hist(mtcars$hp, main = "Second")
      grDevices::replayPlot(shown)
      if (!is.null(after)) after()
    }
  }
  chart <- last_page_export(replayed())
  testthat::expect_identical(cell_titles(chart), list("First"))
  testthat::expect_true("First" %in% chart$strings)
  testthat::expect_false("Second" %in% chart$strings)

  # A call drawn next is added to it.
  chart <- last_page_export(replayed(function() abline(v = 20)))
  testthat::expect_identical(cell_titles(chart), list(c("First", "First")))
  testthat::expect_identical(
    vapply(last_page_cells(chart)[[1]], function(layer) layer$type, character(1)),
    c("hist", "line")
  )

  # And a plot drawn next starts a page of its own, with none of the second.
  chart <- last_page_export(replayed(function() hist(mtcars$wt, main = "Third")))
  testthat::expect_identical(cell_titles(chart), list("Third"))

  # A page that holds no plot maidr recorded on the device, put back: R
  # shows it, and the page R had started before, which was read in its
  # place by its number, is not the chart.
  saved <- list(
    "drawn while maidr_off() was in effect" = function() {
      maidr_off()
      on.exit(maidr_on(), add = TRUE)
      plot(1:5, main = "Unrecorded")
      grDevices::recordPlot()
    },
    "saved on another device" = function() {
      shown <- grDevices::dev.cur()
      grDevices::pdf(NULL)
      other <- grDevices::dev.cur()
      on.exit(
        {
          clear_base_r_device(other)
          grDevices::dev.off(other)
          grDevices::dev.set(shown)
        },
        add = TRUE
      )
      grDevices::dev.control("enable")
      barplot(c(a = 1, b = 2), main = "Elsewhere")
      grDevices::recordPlot()
    }
  )
  for (name in names(saved)) {
    grDevices::pdf(NULL)
    device_id <- grDevices::dev.cur()
    clear_base_r_device(device_id)
    grDevices::dev.control("enable")
    page <- saved[[name]]()
    hist(mtcars$mpg, main = "Recorded")
    grDevices::replayPlot(page)
    for (export in list(
      function() save_html(file = tempfile(fileext = ".html")),
      function() show()
    )) {
      testthat::expect_error(export(), "holds no Base R plot maidr recorded", label = name)
    }
    clear_base_r_device(device_id)
    grDevices::dev.off(device_id)
  }
})

test_that("a page replayPlot() puts back holds what was drawn on it before it was saved", {
  skip_if_no_render()

  # `recordPlot()` saves the page as it is then; replayed, it holds none of
  # what was drawn on it after.
  chart <- last_page_export(function() {
    grDevices::dev.control("enable")
    hist(mtcars$mpg, main = "Snap")
    shown <- grDevices::recordPlot()
    abline(v = 20)
    text(30, 10, "Afternote")
    grDevices::replayPlot(shown)
  })
  testthat::expect_identical(cell_titles(chart), list("Snap"))
  testthat::expect_false("Afternote" %in% chart$strings)

  # In a grid, the panels drawn after it are empty again, and a plot drawn
  # next takes the panel after the one R had reached when it was saved.
  saved_in_grid <- function(after = NULL) {
    function() {
      grDevices::dev.control("enable")
      par(mfrow = c(1, 2))
      hist(mtcars$mpg, main = "Q1")
      shown <- grDevices::recordPlot()
      plot(1:3, main = "Q2")
      grDevices::replayPlot(shown)
      if (!is.null(after)) after()
    }
  }
  chart <- last_page_export(saved_in_grid())
  testthat::expect_identical(cell_titles(chart), list("Q1", character(0)))
  testthat::expect_false("Q2" %in% chart$strings)

  chart <- last_page_export(saved_in_grid(function() barplot(c(a = 1, b = 3), main = "Q3")))
  testthat::expect_identical(cell_titles(chart), list("Q1", "Q3"))
  testthat::expect_false("Q2" %in% chart$strings)
  expect_selectors_drawn(chart)
  expect_drawn_where_r_draws(
    chart,
    quote({
      par(mfrow = c(1, 2))
      hist(mtcars$mpg, main = "Q1")
      barplot(c(a = 1, b = 3), main = "Q3")
    }),
    c("Q1", "Q3")
  )
})

test_that("a drawing that runs the author's own code calling recorded functions is drawn", {
  skip_if_no_render()

  # Drawn again, `pairs()` calls the panel functions, whose `points()`,
  # `abline()` and `text()` are maidr's own recording functions.
  correlation <- function(x, y, ...) {
    usr <- par("usr")
    on.exit(par(usr = usr))
    par(usr = c(0, 1, 0, 1))
    text(0.5, 0.5, sprintf("r=%.2f", stats::cor(x, y)))
  }
  call <- quote(pairs(
    iris[, 1:3],
    lower.panel = function(x, y, ...) {
      points(x, y, ...)
      abline(stats::lm(y ~ x), col = "red")
    },
    upper.panel = correlation
  ))
  chart <- last_page_export(function() eval(call))
  testthat::expect_true(all(c("Sepal.Length", "Sepal.Width", "Petal.Length") %in% chart$strings))
  testthat::expect_true(sprintf("r=%.2f", stats::cor(iris[[1]], iris[[2]])) %in% chart$strings)
  testthat::expect_setequal(chart$strings[nzchar(chart$strings)], r_last_page_strings(call))
  # The points of each panel below the diagonal, as the lower panel drew
  # them, are what its layer's selector names.
  cells <- last_page_cells(chart)
  for (cell in c(4L, 7L, 8L)) {
    ids <- selector_ids(cells[[cell]][[1]])
    testthat::expect_true(any(startsWith(chart$ids, ids[[1]])), label = ids[[1]])
  }
})

test_that("gridGraphics can echo a Base R drawing maidr recorded", {
  skip_if_not_installed("gridGraphics")
  file <- tempfile(fileext = ".png")
  # What maidr recorded on gridGraphics' own device, which it closes.
  on.exit(
    {
      unlink(file)
      clear_all_device_storage()
    },
    add = TRUE
  )
  echoed <- function(drawing) {
    grDevices::png(file)
    tryCatch(
      {
        grid::grid.draw(gridGraphics::echoGrob(drawing))
        "echoed"
      },
      error = conditionMessage,
      finally = grDevices::dev.off()
    )
  }

  # A drawing echoed as it is drawn, as patchwork's `wrap_elements(~ ...)`
  # and ggplotify echo one.
  testthat::expect_identical(
    echoed(function() {
      hist(mtcars$mpg)
      abline(v = 20)
    }),
    "echoed"
  )

  # And the page a device that keeps a display list holds.
  grDevices::pdf(NULL)
  device_id <- grDevices::dev.cur()
  clear_base_r_device(device_id)
  on.exit(
    {
      clear_base_r_device(device_id)
      if (device_id %in% grDevices::dev.list()) grDevices::dev.off(device_id)
    },
    add = TRUE
  )
  grDevices::dev.control("enable")
  hist(mtcars$mpg)
  abline(v = 20)
  page <- grDevices::recordPlot()
  testthat::expect_identical(echoed(page), "echoed")
})

test_that("recording keeps nothing of a call once its device is cleared and closed", {
  kept <- function() length(serialize(maidr:::.maidr_base_r_pages, NULL))
  grDevices::pdf(NULL)
  device_id <- grDevices::dev.cur()
  clear_base_r_device(device_id)
  grDevices::dev.control("enable")
  plot(1:3)
  clear_base_r_device(device_id)
  before <- kept()
  for (i in seq_len(200)) points(2, 2)
  clear_base_r_device(device_id)
  grDevices::dev.off(device_id)
  testthat::expect_lt(kept() - before, 1000)
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

test_that("a page read before and added to since says its plot was let go of", {
  # show() and save_html() let go of the calls recorded on a device once
  # they have read its page. A line added to the plot is then all maidr
  # holds of the page, and the message said R had started it with
  # plot.new(), or a plot maidr does not record. A page started since is
  # one of those, and says so.
  resave <- function(display_list, added) {
    grDevices::pdf(NULL)
    device_id <- grDevices::dev.cur()
    on.exit(
      {
        clear_base_r_device(device_id)
        grDevices::dev.off(device_id)
      },
      add = TRUE
    )
    clear_base_r_device(device_id)
    if (display_list) grDevices::dev.control("enable")
    plot(1:3, main = "Saved once")
    suppressMessages(save_html(file = tempfile(fileext = ".html")))
    added()
    tryCatch(
      {
        save_html(file = tempfile(fileext = ".html"))
        ""
      },
      error = conditionMessage
    )
  }
  for (display_list in c(FALSE, TRUE)) {
    said <- resave(display_list, function() abline(h = 2, col = 2))
    testthat::expect_match(said, "holds no Base R plot maidr recorded")
    testthat::expect_match(said, "An earlier show() or save_html() read the plot", fixed = TRUE)
    testthat::expect_no_match(said, "plot.new()", fixed = TRUE)

    said <- resave(display_list, function() {
      graphics::plot.new()
      text(0.5, 0.5, "Only text")
    })
    testthat::expect_match(said, "holds no Base R plot maidr recorded")
    testthat::expect_match(said, "R started that page with plot.new()", fixed = TRUE)
  }
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
