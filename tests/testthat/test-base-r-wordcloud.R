# `wordcloud::wordcloud()` drew a chart and nothing recorded it
#
# Measured before this: a four-term call left the device with **zero**
# recorded plot calls, because `wordcloud` is a Suggests package and its
# entry point was not on the patched list. So `save_html()` reported "No
# Base R plots detected" -- the cloud was invisible rather than misread.
#
# The reading is a term and its number, which is the whole of what a cloud
# encodes and none of what it draws.
#
# **The counts survive here, unlike in Python.** `wordcloud()` takes `words`
# and `freq` directly, so the recorded call carries the raw frequencies and
# the y axis can honestly say "Occurrences". `wordcloud.WordCloud` divides
# by the largest frequency and keeps only the ratio, so py-maidr can only
# announce a relative one. Same chart, two different honest readings.

wordcloud_layers <- function(draw) {
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

  draw()
  subplots <- BaseRPlotOrchestrator$new(device_id)$generate_maidr_data()$subplots
  subplots[[1]][[1]]$layers
}

terms_of <- function(layer) {
  vapply(layer$data, function(point) point$x, character(1))
}
counts_of <- function(layer) {
  vapply(layer$data, function(point) point$y, numeric(1))
}

#' A processor result for a bare set of arguments, with no drawing
read_args <- function(args) {
  BaseRWordcloudLayerProcessor$new(NULL)$process(
    NULL, NULL,
    layer_info = list(plot_call = list(args = args))
  )
}


test_that("a word cloud is recorded and read rather than missed", {
  testthat::skip_if_not_installed("wordcloud")
  # The reproduction: before this, the device held no plot call at all.
  layers <- wordcloud_layers(function() {
    set.seed(1)
    wordcloud(
      words = c("machine", "learning", "data", "model"),
      freq = c(412, 300, 250, 120), min.freq = 1, random.order = FALSE
    )
  })

  testthat::expect_length(layers, 1)
  testthat::expect_equal(layers[[1]]$type, "word_cloud")
})


test_that("each term is announced with the count the caller passed", {
  testthat::skip_if_not_installed("wordcloud")
  # Not a ratio. `wordcloud()` is handed the counts and they reach the
  # recorded call intact, so there is nothing to normalise away.
  layer <- wordcloud_layers(function() {
    set.seed(1)
    wordcloud(
      words = c("machine", "learning", "data", "model"),
      freq = c(412, 300, 250, 120), min.freq = 1, random.order = FALSE
    )
  })[[1]]

  testthat::expect_equal(terms_of(layer), c("machine", "learning", "data", "model"))
  testthat::expect_equal(counts_of(layer), c(412, 300, 250, 120))
})


test_that("the axes name what a term holds rather than where it sits", {
  testthat::skip_if_not_installed("wordcloud")
  # A cloud has no scale -- the glyph positions are packing, not data -- so
  # the axes say what the two halves of a point mean.
  layer <- wordcloud_layers(function() {
    set.seed(1)
    wordcloud(words = c("a", "b"), freq = c(5, 3), min.freq = 1)
  })[[1]]

  testthat::expect_equal(layer$axes$x$label, "Term")
  testthat::expect_equal(layer$axes$y$label, "Occurrences")
})


test_that("the terms come out heaviest first", {
  testthat::skip_if_not_installed("wordcloud")
  # The core sorts again for navigation, so this is not what makes the
  # reading right -- it is what a producer reading the payload directly gets.
  layer <- wordcloud_layers(function() {
    set.seed(1)
    wordcloud(words = c("small", "big", "mid"), freq = c(1, 99, 50), min.freq = 1)
  })[[1]]

  testthat::expect_equal(terms_of(layer), c("big", "mid", "small"))
})


test_that("a cloud carries no selectors", {
  testthat::skip_if_not_installed("wordcloud")
  # Measured through the package's own export: the result carries no `id`
  # attributes at all, so there is no addressable element per term and no
  # named grob to build a selector from. `wordcloud()` draws each term with
  # a bare `text()` at a rotation, and nothing names those.
  layer <- wordcloud_layers(function() {
    set.seed(1)
    wordcloud(words = c("a", "b"), freq = c(5, 3), min.freq = 1)
  })[[1]]

  testthat::expect_null(layer$selectors)
})


test_that("maidr exports the wrapper the bare call has to resolve to", {
  # This is how interception works for a Suggests package, and it is the one
  # part of it a source-tree test run cannot see. `wrap_function("wordcloud")`
  # assigns the wrapper into maidr's *own* namespace, so a bare `wordcloud()`
  # after `library(maidr)` reaches the recording wrapper rather than
  # upstream's function. But by the time `wordcloud` loads, maidr's namespace
  # is sealed and that assignment silently no-ops -- which is why the stub in
  # `base_r_wrapper_exports.R` has to be a full recording wrapper, exported.
  #
  # Missing that export is invisible under `load_all()`, which leaves the
  # namespace open and lets `wrap_function()` succeed. It shows up only
  # against an installed package: the drawing tests below reported
  # `could not find function "wordcloud"`, and the cloud was silent for
  # every real user. Pinned here so the dev-path run catches it too.
  testthat::expect_true("wordcloud" %in% getNamespaceExports("maidr"))
  testthat::expect_true(is.function(getExportedValue("maidr", "wordcloud")))
})


test_that("the call routes to the processor that reads it", {
  # The name the adapter types it as and the name the factory answers to have
  # to be the same string, and the registry has to list it (#200, #214).
  adapter <- BaseRAdapter$new()

  testthat::expect_equal(
    adapter$detect_layer_type(list(function_name = "wordcloud", args = list())),
    "word_cloud"
  )

  factory <- BaseRProcessorFactory$new()
  testthat::expect_true("word_cloud" %in% factory$get_supported_types())
  testthat::expect_s3_class(
    factory$create_processor("word_cloud", list(plot_call = list(args = list()))),
    "BaseRWordcloudLayerProcessor"
  )
})


test_that("a term below min.freq is not announced", {
  # `wordcloud()` draws nothing rarer than `min.freq`, which defaults to 3.
  # Announcing a term the chart left out would name a word a sighted reader
  # cannot find.
  result <- read_args(list(
    words = c("common", "rare"), freq = c(10, 1)
  ))

  testthat::expect_equal(terms_of(result), "common")
})


test_that("a threshold above every count draws the cloud rather than nothing", {
  # `wordcloud()`'s own rule, copied rather than approximated: `min.freq`
  # drops to 0 when it exceeds every frequency, which is what stops a cloud
  # of rare terms coming out empty. Reading it any other way would announce
  # no terms for a chart that drew them all.
  result <- read_args(list(
    words = c("a", "b"), freq = c(1, 2), min.freq = 5
  ))

  testthat::expect_equal(terms_of(result), c("b", "a"))
})


test_that("a zero count is announced, because the cloud draws it", {
  # Reviewed as a possible drift: with `min.freq` reset to 0, does a term
  # whose count is 0 get announced for a chart that skipped it?
  #
  # Measured against `wordcloud()` itself rather than assumed. Its filter is
  # `freq >= min.freq` and nothing else -- there is no separate zero-skip --
  # so with the threshold at 0 a zero-count term is drawn like any other.
  # Tracing `graphics::text` through the real call confirmed it: all three
  # terms below reach the page, `zero` among them.
  #
  # So announcing it is not drift, it is the match. Pinned here because the
  # honest answer is the counter-intuitive one.
  result <- read_args(list(
    words = c("alpha", "beta", "zero"), freq = c(1, 2, 0), min.freq = 5
  ))

  testthat::expect_equal(terms_of(result), c("beta", "alpha", "zero"))
  testthat::expect_equal(counts_of(result), c(2, 1, 0))
})


test_that("max.words keeps the heaviest terms and drops the rest", {
  result <- read_args(list(
    words = c("a", "b", "c", "d"), freq = c(1, 40, 2, 30),
    min.freq = 1, max.words = 2
  ))

  testthat::expect_equal(terms_of(result), c("b", "d"))
})


test_that("a call with nothing to read is declined", {
  # The arguments of a call that stopped are recorded all the same, so the
  # processor is asked about calls that drew nothing.
  testthat::expect_null(read_args(list()))
  testthat::expect_null(read_args(list(words = character(0), freq = numeric(0))))
  # Mismatched lengths: pairing them would invent a term's count.
  testthat::expect_null(read_args(list(words = c("a", "b"), freq = 1)))
})


test_that("a non-numeric frequency is dropped rather than announced as NA", {
  result <- read_args(list(
    words = c("a", "b"), freq = c("10", "not a number"), min.freq = 1
  ))

  testthat::expect_equal(terms_of(result), "a")
  testthat::expect_equal(counts_of(result), 10)
})
