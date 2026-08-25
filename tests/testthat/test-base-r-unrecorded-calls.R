# Eight base R calls were not recorded at all, so the save stopped (#216)
#
# `classify_function()` returns "UNKNOWN" for a name in none of the three
# lists, the wrapper is never installed, and the call is never logged. The
# device then looks empty and `save_html()` raises
#
#     No Base R plots detected. Please create a plot first
#
# which is the right message for `plot.new()` and a false one for a caller
# whose chart is on the device. Measured before the fix, all eight of
# `persp`, `sunflowerplot`, `fourfoldplot`, `spineplot`, `cdplot`, `qqnorm`,
# `qqplot` and `filled.contour` raised it, while `dotchart` and `mosaicplot`
# -- unread too, but listed in HIGH -- degraded correctly to a picture.
#
# Listed in HIGH they take that same route: no branch in
# `detect_layer_type()`, so the switch falls through to "unknown",
# `unsupported_layer_flags()` sees it, and the static-image path runs.
# That is the LOWER of the two claims, not a reading.
#
# `qqnorm(x, plot.it = FALSE)` is the case that has to come with it: it is
# how you *compute* theoretical quantiles and it draws nothing, so recording
# it put a call on a blank device and the save failed the other way, with
# "Failed to create fallback image". The wrapper already declined
# `hist(x, plot = FALSE)`; `plot.it` is the same request under the spelling
# `qqnorm()` and `qqplot()` use, and both of those are now recorded, so both
# need it.
#
# **Five of the eight have since moved past the fallback.** `qqnorm` and
# `qqplot` gained a processor in #251 and are now read as the quantile
# scatter they draw; `filled.contour` followed, read as the contour it draws
# with the bands between the levels filled; `spineplot` after it, read as the
# mosaic of a two-way table it is; and `cdplot` after that, read as the 100%
# stacked area its bands make. None of the five degrades to a picture any
# more -- they do not need to. The lists below are split accordingly, and the
# five are asserted to be *read* rather than dropped from the file: what #216
# established about them is that a recorded call never stops the save, and
# that still has to hold on the far side of gaining a reading.

skip_unless_jsonlite <- function() {
  testthat::skip_if_not_installed("jsonlite")
}

# Draw on an off-screen device, save as a user would, report what arrived.
# Errors are captured rather than raised, because "it raised at all" is the
# defect under test.
save_base_figure <- function(plot_fun) {
  clear_all_device_storage()
  file <- tempfile(fileext = ".html")
  grDevices::pdf(NULL)
  on.exit(
    {
      while (grDevices::dev.cur() != 1L) grDevices::dev.off()
      unlink(file)
      clear_all_device_storage()
    },
    add = TRUE
  )

  warnings_seen <- character(0)
  error_seen <- NULL
  withCallingHandlers(
    tryCatch(
      {
        plot_fun()
        maidr::save_html(plot = NULL, file = file)
      },
      error = function(e) {
        error_seen <<- conditionMessage(e)
      }
    ),
    warning = function(w) {
      warnings_seen <<- c(warnings_seen, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )

  html <- if (is.null(error_seen) && file.exists(file)) {
    paste(readLines(file, warn = FALSE), collapse = "\n")
  } else {
    ""
  }

  list(
    error = error_seen,
    fell_back = grepl("base64", html, fixed = TRUE),
    warned = any(grepl("unsupported elements", warnings_seen, fixed = TRUE)),
    html = html
  )
}

# The three of the eight that are still recorded-but-unread, with the smallest
# call that draws each. They are not alike, and #251's sweep separates them:
# `persp` and `fourfoldplot` are **declined** -- a 3D surface has no 2D
# reading that is not a different chart, and a fourfold plot's radii encode
# an odds ratio rather than the table it came from -- while
# `sunflowerplot` is **blocked**, on a maidr release carrying the
# `sunflower` trace xability/maidr#1161 added after the 4.4.0
# `MAIDR_VERSION` pins. The distinction matters here because a reading
# arriving for the third would move it to `read_calls` below, and the other
# two should stay put.
unrecorded_calls <- list(
  persp = function() {
    z <- outer(
      seq(-2, 2, length.out = 12),
      seq(-2, 2, length.out = 12),
      function(a, b) a * b
    )
    persp(z = z)
  },
  sunflowerplot = function() {
    sunflowerplot(y ~ x, data = data.frame(x = c(1, 1, 2, 2, 3),
                                           y = c(1, 1, 2, 3, 3)))
  },
  fourfoldplot = function() fourfoldplot(matrix(c(10, 5, 3, 12), nrow = 2))
)

# The five that are now read (#251). Still here, because #216's claim about
# them -- that a recorded call never stops the save -- has to survive their
# gaining a reading.
read_calls <- list(
  qqnorm = function() qqnorm(c(1, 2, 3, 4, 5, 6, 7, 8)),
  qqplot = function() qqplot(c(1, 2, 3, 4), c(2, 3, 4, 5)),
  filled.contour = function() filled.contour(matrix(1:12, nrow = 3)),
  spineplot = function() spineplot(factor(c("a", "a", "b")) ~ c(1, 2, 3)),
  cdplot = function() {
    cdplot(factor(c("a", "a", "b", "b")) ~ c(1, 2, 3, 4))
  }
)

all_calls <- c(unrecorded_calls, read_calls)


test_that("none of the eight stops the save any more", {
  skip_unless_jsonlite()

  # All eight, read and unread alike. This is #216's claim and it does not
  # weaken as names move from one list to the other.
  for (name in names(all_calls)) {
    result <- save_base_figure(all_calls[[name]])
    expect_null(result$error, info = name)
  }
})

test_that("the four still unread fall back to a picture, and say so", {
  skip_unless_jsonlite()

  for (name in names(unrecorded_calls)) {
    result <- save_base_figure(unrecorded_calls[[name]])
    expect_true(result$fell_back, info = name)
    expect_true(result$warned, info = name)
  }
})

test_that("the four that gained a reading are read, not pictured", {
  skip_unless_jsonlite()

  # The far side of #216 for `qqnorm`, `qqplot`, `filled.contour` and
  # `spineplot`: not
  # "does not stop the save" but "is a chart". Asserted here rather than only
  # in each type's own file so that a regression which put any of them back
  # on the fallback shows up as a contradiction between two files rather than
  # as one quietly weakened expectation.
  for (name in names(read_calls)) {
    result <- save_base_figure(read_calls[[name]])
    expect_false(result$fell_back, info = name)
    expect_false(result$warned, info = name)
  }
})

test_that("it is the same path a recorded-but-unread call already took", {
  skip_unless_jsonlite()

  # A HIGH call with no processor degrades correctly. Asserted beside the
  # eight so the two cannot drift apart.
  #
  # Which call plays the part lives in `helper.R`, because it keeps moving:
  # `dotchart` stood here until #242, then `mosaicplot` until #242's
  # remainder. The subject is a recorded-but-unread call, not a function.
  result <- save_base_figure(draw_unread_base_r_chart)

  expect_null(result$error)
  expect_true(result$fell_back)
  expect_true(result$warned)
})

# One PNG through the device `create_fallback_image()` uses: 7x5 inches at
# 150 dpi, which is the 1050x750 the header check below expects.
png_bytes <- function(draw) {
  file <- tempfile(fileext = ".png")
  on.exit(unlink(file), add = TRUE)
  grDevices::png(file, width = 7 * 150, height = 5 * 150, res = 150)
  suppressWarnings(draw())
  grDevices::dev.off()
  file.info(file)$size
}


test_that("the picture is the chart, not a blank canvas", {
  skip_unless_jsonlite()
  skip_if_not_installed("base64enc")

  # The replay has to rebuild `y ~ x` in the caller's frame, so a fallback
  # that silently drew nothing would still pass every assertion above.
  # `sunflowerplot` plays the part, having the formula shape this needs and
  # being one of the three still unread -- `spineplot` stood here until it
  # gained a reading, then `cdplot` until it gained one too, and when
  # `sunflowerplot` does the next one moves in.
  #
  # Measured against two references rendered on the same machine, rather
  # than against a byte count: this first read `> 10000`, calibrated on
  # Linux, and the identical chart encodes to 9,600 bytes on Windows -- a
  # threshold that was really asserting which PNG encoder ran. Asking
  # whether the captured image is nearer the chart than an empty page is
  # the question that was meant, and it needs no constant at all.
  blank <- png_bytes(function() graphics::plot.new())
  reference <- png_bytes(unrecorded_calls$sunflowerplot)
  expect_gt(reference, blank)

  result <- save_base_figure(unrecorded_calls$sunflowerplot)
  encoded <- regmatches(
    result$html,
    regexpr("base64,[A-Za-z0-9+/=]+", result$html)
  )
  expect_length(encoded, 1)

  decoded <- base64enc::base64decode(sub("^base64,", "", encoded))
  expect_gt(length(decoded), (blank + reference) / 2)

  # The PNG header carries the size: bytes 17-24 of IHDR, big-endian. A
  # capture that produced a thumbnail or an empty page would not match the
  # device the fallback asks for.
  header <- as.integer(decoded[1:24])
  expect_equal(sum(header[17:20] * 256^(3:0)), 1050)
  expect_equal(sum(header[21:24] * 256^(3:0)), 750)
})

test_that("a call that computes without drawing is still not recorded", {
  skip_unless_jsonlite()

  # `qqnorm(x, plot.it = FALSE)` returns the quantiles and draws nothing.
  # Recorded, it would send an empty device down the fallback path and fail
  # with "Failed to create fallback image" -- a worse answer than the one
  # this call has always had, which is correct for a device with no plot.
  result <- save_base_figure(function() {
    qqnorm(c(1, 2, 3, 4), plot.it = FALSE)
  })

  expect_match(result$error, "No Base R plots detected")
  expect_false(result$fell_back)
})

test_that("plot.it = FALSE is refused without disturbing plot = FALSE", {
  skip_unless_jsonlite()

  # The guard gained a second name; this pins that it kept the first. Both
  # spellings mean the same thing and neither may reach the recorder.
  computed <- save_base_figure(function() hist(c(1, 2, 3), plot = FALSE))
  expect_match(computed$error, "No Base R plots detected")

  # `cdplot.default` has a real `plot` argument, so the existing half of the
  # guard covers it -- and it has to keep covering it now that a drawn
  # `cdplot()` is read rather than dropped.
  computed <- save_base_figure(function() {
    cdplot(factor(c("a", "a", "b", "b")) ~ c(1, 2, 3, 4), plot = FALSE)
  })
  expect_match(computed$error, "No Base R plots detected")

  # The other function that spells it `plot.it`. Asserted separately from
  # `qqnorm` because the guard reads the argument off the recorded call, so
  # it holds for a second function only if that function is recorded at all.
  computed <- save_base_figure(function() {
    qqplot(c(1, 2, 3, 4), c(2, 3, 4, 5), plot.it = FALSE)
  })
  expect_match(computed$error, "No Base R plots detected")
})

test_that("qqnorm still hands back the quantiles it computed", {
  # The wrapper returns the original's value; a chart the package cannot read
  # must not also break the call's contract as a computation.
  clear_all_device_storage()
  grDevices::pdf(NULL)
  on.exit(
    {
      while (grDevices::dev.cur() != 1L) grDevices::dev.off()
      clear_all_device_storage()
    },
    add = TRUE
  )

  drawn <- qqnorm(c(1, 2, 3, 4))
  expect_equal(drawn$y, c(1, 2, 3, 4))

  computed <- qqnorm(c(1, 2, 3, 4), plot.it = FALSE)
  expect_equal(computed$y, c(1, 2, 3, 4))
})

test_that("the charts that already read still read", {
  skip_unless_jsonlite()

  # Eight names added to HIGH and one name to the computation-only guard.
  # This pins that neither reached a chart with a processor.
  result <- save_base_figure(function() barplot(c(a = 1, b = 2, c = 3)))
  expect_null(result$error)
  expect_false(result$fell_back)

  result <- save_base_figure(function() plot(1:10, (1:10)^2))
  expect_null(result$error)
  expect_false(result$fell_back)

  result <- save_base_figure(function() hist(c(1, 2, 2, 3, 3, 3)))
  expect_null(result$error)
  expect_false(result$fell_back)
})

test_that("all eight are classified, and classification is what changed", {
  for (name in names(all_calls)) {
    expect_equal(classify_function(name), "HIGH", info = name)
  }

  # Being in HIGH is not a claim that the type is read: none of the four
  # gains a `detect_layer_type()` branch, so each falls through to "unknown".
  # That is what #216 changed and all it changed -- the four that have since
  # been read got there by gaining a processor, which is a separate step, so
  # they are excluded from this half rather than from the classification
  # above. The check is by *function* name, which is why it keeps holding as
  # calls gain readings: `lag.plot` is read as the layer type "lag", so the
  # function's own name is still absent from the registry.
  factory <- BaseRProcessorFactory$new()
  for (name in names(unrecorded_calls)) {
    expect_false(name %in% factory$get_supported_types(), info = name)
  }
})


# `stem()` is not a plot, and listing it as one cost two things (#260)
#
# `stem()` writes a stem-and-leaf display to the console. It opens no device,
# draws no marks and returns invisibly -- it lives in `package:graphics` for
# documentation reasons rather than because it plots. It was nevertheless in
# the HIGH list, between `stripchart` and `pie`, so it was recorded as a
# chart.
#
# The two failures that produced are the mirror image of each other: on its
# own it claimed a chart that was not there, and beside a real chart it made
# the real one unreadable.

test_that("stem() is not classified as a plotting call", {
  expect_equal(maidr:::classify_function("stem"), "UNKNOWN")
})

test_that("stem() alone reports no plot rather than a failed fallback", {
  skip_unless_jsonlite()

  # Measured before the fix: "Failed to create fallback image" -- a recorded
  # call over a blank device, the shape #216 found for
  # `qqnorm(plot.it = FALSE)`. That message claims a plot exists and the
  # picture of it could not be made; the truth is that there is no plot, and
  # "No Base R plots detected" is what says so.
  result <- save_base_figure(function() {
    invisible(utils::capture.output(stem(c(10, 11, 12, 20, 21, 30))))
  })

  expect_match(result$error, "No Base R plots detected")
})

test_that("a stem beside a histogram leaves the histogram interactive", {
  skip_unless_jsonlite()

  # The half that costs a reader something. Measured before the fix, the
  # histogram -- interactive on its own -- degraded to a static image with
  # "Plot contains unsupported elements", because the `stem` call recorded
  # beside it had no reading. The console output the caller asked for cost
  # them the accessible chart they also drew, and nothing on the page said
  # why. `hist(x); stem(x)` is not contrived: they are the two ways of
  # looking at one distribution, and R's own documentation pairs them.
  drawn <- save_base_figure(function() hist(c(1, 2, 2, 3, 3, 3, 4, 5)))
  both <- save_base_figure(function() {
    hist(c(1, 2, 2, 3, 3, 3, 4, 5))
    invisible(utils::capture.output(stem(c(1, 2, 2, 3, 3, 3, 4, 5))))
  })

  expect_null(both$error)
  expect_false(drawn$fell_back)
  expect_false(both$fell_back)
  expect_false(both$warned)
})


# Twelve more that drew a chart and were told there was none (#262)
#
# #216's defect, found again by sweeping every drawing entry point rather
# than the eight it started from. Each of these draws directly instead of
# going through `plot()`, so being absent from the classification list meant
# nothing was recorded and `save_html()` reported "No Base R plots detected.
# Please create a plot first" -- to a caller whose chart was on the device.
#
# Measured with **bare** calls, which is load-bearing: a qualified
# `stats::acf(v)` does not go through the search-path patch, and a sweep
# written that way reported `assocplot` and `coplot` as broken when they are
# not. The fixtures below therefore call each function by its bare name, the
# way a caller writes it.
#
# What reaches these through `plot()` was already fine and is asserted below
# so it stays that way: `plot` is listed, so its methods record.
#
# **Seven of the twelve have since moved past the fallback.** `bxp()` was the
# first, read as the box plot it draws -- it is `boxplot()`'s own drawing
# half, handed the five-number summaries instead of the observations, and it
# puts the same marks on the page. `acf`, `pacf` and `ccf` followed, each
# drawing one vertical spike per lag (#276); `interaction.plot` after them,
# drawing one line per trace level over the cell means it computes (#278);
# `monthplot` after that, drawing one line per cycle position over that
# position's own subseries; and `lag.plot` last, which is the only one of the
# twelve that draws a *grid* -- one scatter per series and lag. The lists
# below are split accordingly, and the seven are asserted to be *read* rather
# than dropped from the file: what #262 established about them is that a
# recorded call never stops the save, and that still has to hold on the far
# side of gaining a reading.

DRAWS_DIRECTLY <- local({
  set.seed(5)
  v <- stats::rnorm(60)
  m <- matrix(stats::rnorm(40), nrow = 10)
  seasonal <- stats::ts(cumsum(stats::rnorm(48)), frequency = 12)
  list(
    biplot = function() biplot(stats::prcomp(m)),
    cpgram = function() cpgram(v),
    spectrum = function() spectrum(v),
    termplot = function() termplot(stats::lm(v ~ seq_along(v))),
    stars = function() stars(abs(m))
  )
})

# The seven of the twelve that are now read. `bxp` was the first; the three
# correlogram entry points followed, each drawing one vertical spike per lag
# -- the shape `type = "h"` already read as a `lollipop` for (#276);
# `interaction.plot` after them, which computes a grid of cell means and hands
# it to `matplot`, so it is the set of lines that already reads (#278);
# `monthplot` after that, one line per cycle position over that position's own
# subseries, which is the same set of lines once more; and `lag.plot` last,
# which is not a set of lines at all but a grid of scatters, read the way
# `pairs()` is -- as a figure of subplots.
#
# `lag.plot` is listed in its *default* spelling on purpose. Its default is
# the labelled one -- `labels` follows `do.lines`, which is `n <= 150` -- and
# a labelled panel draws text where the others draw symbols, so listing the
# spelling that draws points would have exercised the easier half.
DRAWS_DIRECTLY_READ <- local({
  set.seed(5)
  v <- stats::rnorm(60)
  list(
    bxp = function() bxp(boxplot(stats::rnorm(60), plot = FALSE)),
    acf = function() acf(v),
    pacf = function() pacf(v),
    ccf = function() ccf(v, rev(v)),
    interaction.plot = function() {
      interaction.plot(factor(rep(1:2, 30)), factor(rep(1:3, 20)), v)
    },
    monthplot = function() {
      monthplot(stats::ts(cumsum(stats::rnorm(48)), frequency = 12))
    },
    lag.plot = function() {
      lag.plot(stats::ts(cumsum(stats::rnorm(48)), frequency = 12), lags = 2)
    }
  )
})

DRAWS_DIRECTLY_ALL <- c(DRAWS_DIRECTLY, DRAWS_DIRECTLY_READ)

test_that("a call that draws without plot() no longer stops the save", {
  skip_unless_jsonlite()

  # Read and unread alike. This is #262's claim and it does not weaken as a
  # name moves from one list to the other.
  for (name in names(DRAWS_DIRECTLY_ALL)) {
    result <- save_base_figure(function() {
      invisible(utils::capture.output(suppressWarnings(DRAWS_DIRECTLY_ALL[[name]]())))
    })

    expect_null(result$error, info = name)
  }
})

test_that("the five still unread degrade to the picture rather than to nothing", {
  skip_unless_jsonlite()

  # Being listed is the *lower* of the two claims -- recorded, so the figure
  # falls back to a static image, not read. Asserting the fallback actually
  # arrives is what keeps "listed" from meaning "silently empty".
  for (name in names(DRAWS_DIRECTLY)) {
    result <- save_base_figure(function() {
      invisible(utils::capture.output(suppressWarnings(DRAWS_DIRECTLY[[name]]())))
    })

    expect_true(result$fell_back, info = name)
  }
})

test_that("bxp() ships a box plot rather than a picture of one", {
  skip_unless_jsonlite()

  # The upper claim, for the first of the twelve to have it. Before the
  # reading this call fell back with "Plot contains unsupported elements";
  # `boxplot()` on the same numbers never did, and the two draw the same
  # marks.
  result <- save_base_figure(DRAWS_DIRECTLY_READ$bxp)

  expect_null(result$error)
  expect_false(result$fell_back)
  expect_false(result$warned)
  # The payload is HTML-escaped inside the `maidr-data` attribute.
  expect_match(result$html, "&quot;type&quot;:&quot;box&quot;", fixed = TRUE)
})

test_that("the correlograms ship spikes rather than a picture of them", {
  skip_unless_jsonlite()

  # The same upper claim for the three that gained it next. Each drew a
  # chart that fell back with "Plot contains unsupported elements" while
  # `plot(x, y, type = "h")` -- the same spikes, drawn per observation
  # rather than per lag -- never did (#276).
  for (name in c("acf", "pacf", "ccf")) {
    result <- save_base_figure(DRAWS_DIRECTLY_READ[[name]])

    expect_null(result$error, info = name)
    expect_false(result$fell_back, info = name)
    expect_match(
      result$html, "&quot;type&quot;:&quot;lollipop&quot;",
      fixed = TRUE, info = name
    )
  }
})

test_that("monthplot() ships its subseries rather than a picture of them", {
  skip_unless_jsonlite()

  # The same upper claim for the sixth. It drew twelve lines and fell back
  # with "Plot contains unsupported elements", while `matplot()` on the same
  # twelve series -- the shape `monthplot` lays out by hand -- never did.
  result <- save_base_figure(DRAWS_DIRECTLY_READ$monthplot)

  expect_null(result$error)
  expect_false(result$fell_back)
  expect_match(
    result$html, "&quot;type&quot;:&quot;line&quot;",
    fixed = TRUE
  )
})

test_that("lag.plot() ships its grid of scatters rather than a picture", {
  skip_unless_jsonlite()

  # The same upper claim for the seventh, and the first of the twelve to
  # answer with a *figure* rather than a layer: two panels, each a scatter of
  # the series against a shifted copy of itself. Before the reading it fell
  # back with "Plot contains unsupported elements".
  result <- save_base_figure(DRAWS_DIRECTLY_READ$lag.plot)

  expect_null(result$error)
  expect_false(result$fell_back)
  expect_match(
    result$html, "&quot;type&quot;:&quot;point&quot;",
    fixed = TRUE
  )
  # A grid, so the payload carries a second subplot rather than a second
  # layer in the first.
  expect_match(
    result$html, "maidr-subplot-2-1",
    fixed = TRUE
  )
})

test_that("what reaches stats plots through plot() still reads", {
  skip_unless_jsonlite()

  # The bound on the change. These are S3 methods dispatched from `plot`,
  # which is listed, so they were never part of the defect -- and none of
  # them may start falling back to a picture now that their direct-drawing
  # siblings are recorded.
  set.seed(5)
  v <- stats::rnorm(40)

  through_plot <- list(
    density = function() plot(stats::density(v)),
    ecdf = function() plot(stats::ecdf(v)),
    ts = function() plot(stats::ts(cumsum(v))),
    acf_object = function() plot(acf(v, plot = FALSE))
  )

  for (name in names(through_plot)) {
    result <- save_base_figure(through_plot[[name]])

    expect_null(result$error, info = name)
    expect_false(result$fell_back, info = name)
  }
})
