# `records_as_frames()` hands jsonlite a data frame in place of a run of
# per-point records, purely for speed. The payload is a contract with the
# bundled maidr.js, so the one thing these tests hold it to is that the JSON
# does not change: every case serialises the payload both ways, with the
# options `set_maidr_data_attr()` uses, and compares the strings.

payload_json <- function(x) {
  as.character(jsonlite::toJSON(x, auto_unbox = TRUE, na = "null", digits = NA))
}

expect_same_json <- function(payload) {
  expect_identical(
    payload_json(maidr:::records_as_frames(payload)),
    payload_json(payload)
  )
}

layer_with <- function(data) {
  list(subplots = list(list(list(layers = list(list(
    type = "point", selectors = "circle", data = data
  ))))))
}

test_that("a run of flat records becomes a data frame with identical JSON", {
  records <- lapply(1:5, function(i) {
    list(x = i * 1.5, y = as.integer(i), label = paste0("p", i), on = i > 2)
  })
  converted <- maidr:::records_as_frames(layer_with(records))
  data <- converted$subplots[[1]][[1]]$layers[[1]]$data
  expect_s3_class(data, "data.frame")
  expect_identical(names(data), c("x", "y", "label", "on"))
  expect_same_json(layer_with(records))
})

test_that("missing and non-finite values serialise as before", {
  records <- list(
    list(x = NA_real_, y = NA_character_, z = NA, n = NA_integer_),
    list(x = NaN, y = "", z = TRUE, n = 1L),
    list(x = Inf, y = "a\"b\\c\né☃", z = FALSE, n = -2L),
    list(x = -Inf, y = "<tag>&", z = NA, n = .Machine$integer.max)
  )
  expect_same_json(layer_with(records))
})

test_that("full numeric precision survives the conversion", {
  values <- c(
    0.1 + 0.2, 1 / 3, pi * 1e10, 123456789.123456789, 1e-300, 5e-324,
    1e15, 1e16, 1e21, -0, 0, 2^53 + 1, -1.5e-7, 100, 1e5, 123456.7
  )
  records <- lapply(values, function(v) list(x = v, y = -v))
  expect_same_json(layer_with(records))
})

test_that("a single record keeps its array brackets", {
  expect_same_json(layer_with(list(list(x = 1, y = 2))))
  expect_same_json(list(list(x = "only")))
})

test_that("runs nested at any depth are found", {
  series <- lapply(1:3, function(s) {
    lapply(1:4, function(i) list(x = i, y = s * i, fill = letters[s]))
  })
  payload <- layer_with(series)
  converted <- maidr:::records_as_frames(payload)
  inner <- converted$subplots[[1]][[1]]$layers[[1]]$data
  expect_true(all(vapply(inner, is.data.frame, logical(1))))
  expect_same_json(payload)
})

test_that("anything that might serialise differently stays a list", {
  unchanged <- list(
    mixed_type = list(list(x = 1L), list(x = 2.5)),
    mixed_class = list(list(x = 1), list(x = "a")),
    ragged_names = list(list(x = 1, y = 2), list(x = 1)),
    reordered = list(list(x = 1, y = 2), list(y = 2, x = 1)),
    vector_field = list(list(x = c(1, 2)), list(x = 3)),
    empty_field = list(list(x = numeric(0)), list(x = 1)),
    null_field = list(list(x = NULL, y = 1), list(x = NULL, y = 2)),
    nested_field = list(list(x = list(1)), list(x = list(2))),
    factor_field = list(list(x = factor("a")), list(x = factor("b"))),
    date_field = list(list(x = Sys.Date()), list(x = Sys.Date())),
    named_value = list(list(x = c(a = 1)), list(x = c(a = 2))),
    unnamed_records = list(list(1, 2), list(3, 4)),
    blank_name = list(stats::setNames(list(1), ""), stats::setNames(list(2), "")),
    duplicate_names = list(list(x = 1, x = 2), list(x = 3, x = 4)),
    empty_records = list(list(), list()),
    scalars = list(1, 2, 3)
  )
  for (case in names(unchanged)) {
    payload <- unchanged[[case]]
    converted <- maidr:::records_as_frames(payload)
    expect_false(is.data.frame(converted), label = case)
    expect_same_json(payload)
  }
})

test_that("a named list is an object, not a run of records", {
  payload <- list(a = list(x = 1), b = list(x = 2))
  expect_false(is.data.frame(maidr:::records_as_frames(payload)))
  expect_same_json(payload)
})

test_that("rendered charts carry the same payload either way", {
  testthat::skip_if_not_installed("ggplot2")
  plots <- list(
    point = ggplot2::ggplot(
      data.frame(x = c(1, 2, NA, 4), y = c(0.1, NA, 0.3, 1 / 3)),
      ggplot2::aes(x, y)
    ) + ggplot2::geom_point(),
    line = ggplot2::ggplot(
      data.frame(x = 1:6, y = c(1, 3, 2, 5, 4, 6), g = rep(c("a", "b"), 3)),
      ggplot2::aes(x, y, colour = g)
    ) + ggplot2::geom_line(),
    bar = ggplot2::ggplot(
      data.frame(x = c("a", "b", "c"), y = c(3, 1, 2)),
      ggplot2::aes(x, y)
    ) + ggplot2::geom_col()
  )
  captured <- NULL
  local_mocked_bindings(
    set_maidr_data_attr = function(svg_doc, maidr_data) {
      captured <<- maidr_data
      invisible(NULL)
    },
    .package = "maidr"
  )
  for (case in names(plots)) {
    captured <- NULL
    suppressWarnings(maidr:::create_maidr_html(plots[[case]]))
    expect_false(is.null(captured), label = case)
    prepared <- maidr:::flatten_single_selectors(
      maidr:::drop_empty_selectors(captured)
    )
    expect_same_json(prepared)
  }
})
