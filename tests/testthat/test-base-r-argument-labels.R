# Base R charts titled after how an argument was written.
#
# `hist(mtcars$mpg)` writes "mtcars$mpg" under its x axis and "Histogram of
# mtcars$mpg" above it: hist() takes both from `deparse1(substitute(x))`.
# maidr records the argument's value and draws the chart again from it, and
# a replay of the value hands `substitute()` the numbers themselves, so the
# chart maidr exported was titled "Histogram of c(21, 21, 22.8, 21.4, ...)".
# Every recorded function that deparses an argument had the same defect.
#
# The replay now passes such a value under a symbol spelled the way the
# argument was written. These tests compare the strings maidr's chart draws
# with the strings R draws for the same call, and check that what is drawn
# is still the recorded value rather than the expression evaluated again.

skip_slow_file_on_cran()
skip_if_not_installed("svglite")
skip_if_not_installed("xml2")

# Every string an SVG file draws, in order.
svg_strings <- function(file) {
  document <- xml2::read_xml(file)
  trimws(xml2::xml_text(
    xml2::xml_find_all(document, "//*[local-name()='text']")
  ))
}

# The strings R draws for `call` by itself: each function maidr wraps that
# the call names is bound to its original, so the call never passes through
# a wrapper, and recording is off for a wrapper reached from inside another
# function. A wrapper's pass-through is not the reference: it forwards its
# `...`, and a function that rebuilds its call from `match.call()` --
# `acf(x, type = "partial")` -- titles the chart "..1" through it.
native_strings <- function(call, env) {
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
  svg_strings(file)
}

# The strings maidr draws for `call`: recorded through its wrapper on a
# throwaway device, then every recorded call replayed onto svglite, the way
# the static-image fallback and the export replay them.
replayed_strings <- function(call, env, replay = replay_each) {
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
  eval(call, env)

  file <- tempfile(fileext = ".svg")
  on.exit(unlink(file), add = TRUE)
  svglite::svglite(file, width = 7, height = 5)
  tryCatch(replay(device_id), finally = grDevices::dev.off())
  svg_strings(file)
}

replay_each <- function(device_id) {
  for (entry in maidr:::get_device_calls(device_id)) {
    maidr:::replay_plot_call(
      entry$function_name, entry$args, entry$call_env, entry$arg_text
    )
  }
}

expect_drawn_as_r_draws <- function(call, env = parent.frame()) {
  testthat::expect_identical(
    replayed_strings(call, env),
    native_strings(call, env),
    label = deparse1(call)
  )
}

# The calls recorded on a throwaway device, after `draw()`.
recorded_calls <- function(draw) {
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
  draw()
  maidr:::get_device_calls(device_id)
}

test_that("every recorded function titling a chart after an argument draws R's titles", {
  # One call per function measured to title a chart with
  # `deparse1(substitute())` of an argument, each drawn wrong before. The
  # rest of the recorded functions -- boxplot(), barplot(), image(volcano),
  # heatmap(), pie(), the formula methods -- take their titles from
  # elsewhere and drew R's titles already.
  tg <- ToothGrowth
  xs <- c(0, 0.5, 2, 3)
  ys <- c(1, 4, 9)
  heights <- outer(xs, ys)
  calls <- list(
    quote(hist(mtcars$mpg)),
    quote(hist(as.Date("2024-01-01") + c(0, 40, 80, 120), "months")),
    quote(plot(mtcars$wt, mtcars$mpg)),
    quote(plot(mtcars$mpg)),
    quote(plot(AirPassengers)),
    quote(plot(table(mtcars$cyl))),
    quote(plot(sin, -pi, pi)),
    quote(image(xs, ys, heights)),
    quote(persp(xs, ys, heights)),
    quote(matplot(mtcars$wt, mtcars[, c("mpg", "qsec")])),
    quote(mosaicplot(table(mtcars$cyl, mtcars$gear))),
    quote(mosaicplot(~ cyl + gear, data = mtcars)),
    quote(sunflowerplot(mtcars$cyl, mtcars$gear)),
    quote(spineplot(factor(mtcars$cyl), factor(mtcars$am))),
    quote(cdplot(mtcars$mpg, factor(mtcars$am))),
    quote(qqplot(mtcars$mpg, mtcars$hp)),
    quote(acf(ldeaths)),
    quote(acf(ldeaths, type = "partial")),
    quote(pacf(ldeaths)),
    quote(ccf(mdeaths, fdeaths)),
    quote(interaction.plot(tg$dose, tg$supp, tg$len)),
    quote(cpgram(ldeaths)),
    quote(monthplot(AirPassengers)),
    quote(lag.plot(ldeaths)),
    quote(symbols(mtcars$wt, mtcars$mpg, circles = mtcars$hp))
  )

  for (call in calls) {
    expect_drawn_as_r_draws(call)
  }
})

# The strings and the schema of the chart `save_html()` exports for `draw()`.
exported_chart <- function(draw) {
  grDevices::pdf(NULL)
  device_id <- grDevices::dev.cur()
  clear_base_r_device(device_id)
  file <- tempfile(fileext = ".html")
  on.exit(
    {
      clear_base_r_device(device_id)
      grDevices::dev.off(device_id)
      unlink(file)
    },
    add = TRUE
  )
  draw()
  suppressMessages(save_html(file = file))

  html <- paste(readLines(file, warn = FALSE), collapse = "\n")
  document <- xml2::read_html(file)
  list(
    strings = trimws(xml2::xml_text(
      xml2::xml_find_all(document, "//*[local-name()='text']")
    )),
    schema = schema_from(html)
  )
}

test_that("the exported chart is titled as R titles it and holds the same counts", {
  skip_if_no_render()

  chart <- exported_chart(function() hist(mtcars$mpg))

  testthat::expect_true("Histogram of mtcars$mpg" %in% chart$strings)
  testthat::expect_true("mtcars$mpg" %in% chart$strings)
  testthat::expect_false(any(grepl("c(21, 21", chart$strings, fixed = TRUE)))

  bars <- chart$schema$subplots[[1]][[1]]$layers[[1]]$data
  testthat::expect_equal(
    vapply(bars, function(bar) bar$y, numeric(1)),
    graphics::hist(mtcars$mpg, plot = FALSE)$counts
  )
})

test_that("each chart a loop draws keeps its own data and R's title", {
  # `v` is "b" by the time the figure is exported. Each histogram must still
  # draw the column it was drawn from, and be titled `df[[v]]`, as R titles
  # both.
  skip_if_no_render()
  df <- data.frame(a = c(1, 2, 2, 3, 3, 3, 9), b = c(10, 20, 20, 20, 30, 50, 90))
  draw <- quote({
    par(mfrow = c(1, 2))
    for (v in c("a", "b")) hist(df[[v]])
  })

  expect_drawn_as_r_draws(draw)

  chart <- exported_chart(function() eval(draw))
  testthat::expect_equal(sum(chart$strings == "Histogram of df[[v]]"), 2)
  testthat::expect_equal(sum(chart$strings == "df[[v]]"), 2)

  panels <- unlist(chart$schema$subplots, recursive = FALSE)
  testthat::expect_length(panels, 2)
  for (i in 1:2) {
    bars <- panels[[i]]$layers[[1]]$data
    testthat::expect_equal(
      vapply(bars, function(bar) bar$y, numeric(1)),
      graphics::hist(df[[i]], plot = FALSE)$counts
    )
  }
})

test_that("the recorded value is drawn, never the expression evaluated again", {
  evaluated <- 0
  values <- function() {
    evaluated <<- evaluated + 1
    c(1, 2, 2, 3, 3, 3)
  }

  strings <- replayed_strings(quote(hist(values())), environment())

  testthat::expect_equal(evaluated, 1)
  testthat::expect_true("Histogram of values()" %in% strings)

  calls <- recorded_calls(function() hist(mtcars$mpg))
  testthat::expect_identical(calls[[1]]$args[[1]], mtcars$mpg)
  testthat::expect_identical(calls[[1]]$arg_text, "mtcars$mpg")
})

test_that("a title the call gives explicitly still wins", {
  expect_drawn_as_r_draws(quote(hist(mtcars$mpg, xlab = "Miles", main = "Fuel")))
  strings <- replayed_strings(
    quote(hist(mtcars$mpg, xlab = "Miles", main = "Fuel")),
    environment()
  )
  testthat::expect_false("mtcars$mpg" %in% strings)
})

test_that("an argument the chart is not titled after is passed as its value", {
  # monthplot() evaluates its `...` again in a frame of its own, where a
  # symbol bound only for the replay could not be found.
  ttl <- "Passengers"
  calls <- recorded_calls(function() monthplot(AirPassengers, main = ttl))
  testthat::expect_identical(calls[[1]]$arg_text, c("AirPassengers", NA))
  expect_drawn_as_r_draws(quote(monthplot(AirPassengers, main = ttl)))

  calls <- recorded_calls(function() {
    plot(1:3)
    text(1, 2, labels = ttl)
  })
  testthat::expect_true(all(is.na(calls[[2]]$arg_text)))
})

test_that("two arguments written alike keep their own values", {
  # Both are titled "rnorm(5)" by R, and one name can hold one value: the
  # second is drawn as its value rather than as the first's.
  calls <- recorded_calls(function() {
    set.seed(1)
    plot(rnorm(5), rnorm(5))
  })
  entry <- calls[[1]]
  testthat::expect_identical(entry$arg_text, c("rnorm(5)", "rnorm(5)"))

  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  maidr:::replay_plot_call(
    entry$function_name, entry$args, entry$call_env, entry$arg_text
  )
  padded <- function(values) {
    range(values) + c(-1, 1) * 0.04 * diff(range(values))
  }
  testthat::expect_equal(
    graphics::par("usr"),
    c(padded(entry$args[[1]]), padded(entry$args[[2]]))
  )
})

test_that("text no symbol can carry falls back to the value", {
  long <- str2lang(paste0("c(", paste(rep("1", 4000), collapse = ", "), ")"))
  testthat::expect_gt(nchar(deparse1(long), type = "bytes"), 10000)
  testthat::expect_true(is.na(maidr:::written_label(long)))
  testthat::expect_true(is.na(maidr:::written_label(quote(..1))))
  testthat::expect_true(is.na(maidr:::written_label(quote(...))))
  testthat::expect_true(is.na(maidr:::written_label(3)))
  testthat::expect_true(is.na(maidr:::written_label("x")))
  testthat::expect_identical(maidr:::written_label(quote(df$`my col`)), "df$`my col`")

  # And the chart is still drawn, from the recorded values.
  long_call <- as.call(list(as.name("hist"), long))
  strings <- replayed_strings(long_call, environment())
  testthat::expect_true(any(startsWith(strings, "Histogram of c(1, 1")))

  forwarded <- function(...) hist(..1)
  calls <- recorded_calls(function() forwarded(mtcars$mpg))
  testthat::expect_true(is.na(calls[[1]]$arg_text))
  testthat::expect_identical(calls[[1]]$args[[1]], mtcars$mpg)
})

test_that("the static-image fallback draws R's titles too", {
  # persp() has no reading, so its chart is the fallback's picture, drawn by
  # replay_base_r_plot().
  xs <- c(0, 0.5, 2, 3)
  ys <- c(1, 4, 9)
  heights <- outer(xs, ys)
  call <- quote(persp(xs, ys, heights))

  testthat::expect_identical(
    replayed_strings(call, environment(), replay = maidr:::replay_base_r_plot),
    native_strings(call, environment())
  )
})

test_that("chartSeries() is titled after its series as R titles it", {
  skip_if_not_installed("quantmod")
  s <- xts::xts(c(1, 3, 2, 5, 4, 6, 5, 8, 7, 9), as.Date("2024-01-01") + 0:9)
  expect_drawn_as_r_draws(quote(chartSeries(s, theme = "white")))
})

test_that("a name R prints with backticks inside a call is drawn as written", {
  df <- data.frame(`my col` = c(1, 2, 2, 3), check.names = FALSE)
  expect_drawn_as_r_draws(quote(hist(df$`my col`)))
})

test_that("the arguments forwarded through a caller's dots keep their text", {
  through_dots <- function(...) hist(...)
  through_name <- function(v) hist(v)
  expect_drawn_as_r_draws(quote(through_dots(mtcars$mpg)))
  expect_drawn_as_r_draws(quote(through_name(mtcars$mpg)))
})

test_that("the formals a function reads with substitute() are found in its code", {
  testthat::expect_identical(
    maidr:::substituted_formals(graphics:::hist.default),
    "x"
  )
  testthat::expect_setequal(
    maidr:::substituted_formals(stats::qqplot),
    c("x", "y")
  )
  testthat::expect_setequal(
    maidr:::substituted_formals(stats::interaction.plot),
    c("x.factor", "trace.factor", "response", "fun")
  )
  testthat::expect_identical(
    maidr:::substituted_formals(graphics:::text.default),
    character(0)
  )
})

test_that("a function's code is read for substitute() once", {
  # Walking hist.default() takes milliseconds, and a loop of hist() calls
  # would pay it on every call.
  definition <- function(x) deparse1(substitute(x))
  testthat::expect_identical(maidr:::substituted_formals(definition), "x")

  testthat::local_mocked_bindings(
    read_substituted_formals = function(definition) stop("read again")
  )
  testthat::expect_identical(maidr:::substituted_formals(definition), "x")
  other <- function(y) deparse1(substitute(y))
  testthat::expect_error(maidr:::substituted_formals(other), "read again")
})
