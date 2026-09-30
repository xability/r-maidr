# The payload passes that visit every data point run in C++
# (src/payload_kernels.cpp): the record-run check behind
# `records_as_frames()`, the two selector passes `set_maidr_data_attr()`
# makes, and the heatmap's cell lookup. Each is held to the R it replaced.

walk_payload <- function(records, selectors = list("#a use"), type = "point") {
  list(
    id = "p",
    subplots = list(list(list(id = "s", layers = list(
      list(id = 1, selectors = selectors, type = type, data = records),
      list(id = 2, selectors = list(), type = "line", data = list()),
      list(id = 3, selectors = c("#b rect", "#c rect"), type = "bar", data = list(1, 2))
    ))))
  )
}

test_that("records_as_frames() converts what is_record_run() accepts", {
  runs <- list(
    lapply(1:5, function(i) list(x = i, y = i * 2.5)),
    lapply(1:5, function(i) list(x = i, label = letters[i], on = i > 2)),
    list(list(x = 1, y = 2), list(y = 2, x = 1)),
    list(list(x = 1, y = 2), list(x = 1)),
    list(list(x = 1, y = 2), list(x = 1L, y = 2)),
    list(list(x = 1, y = 2), list(x = c(1, 2), y = 2)),
    list(list(x = 1, y = 2), structure(list(x = 1, y = 2), class = "rec")),
    list(list(x = 1, y = 2), list(x = factor("a"), y = 2)),
    list(list(x = 1, x = 2)),
    list(list(1, 2)),
    list(stats::setNames(list(1, 2), c("x", NA))),
    list(stats::setNames(list(1, 2), c("x", ""))),
    list(list(x = list(1))),
    list(list(x = NULL)),
    list(list()),
    list(list(x = 1), 5),
    list(a = list(x = 1)),
    list(list(x = structure(1, units = "cm")))
  )
  for (run in runs) {
    frame <- maidr:::record_run_frame_cpp(run)
    if (maidr:::is_record_run(run)) {
      expected <- maidr:::records_as_frames(list(run))[[1]]
      expect_identical(frame, expected)
      expect_s3_class(frame, "data.frame")
    } else {
      expect_null(frame)
    }
  }
  # A pairlist record is left to the R version.
  expect_identical(maidr:::record_run_frame_cpp(list(pairlist(x = 1))), NA)
})

test_that("the C++ selector passes change a payload as the R ones did", {
  records <- lapply(1:50, function(i) list(x = i, y = i / 3))
  payloads <- list(
    walk_payload(records),
    walk_payload(records, selectors = list()),
    walk_payload(records, selectors = "#only"),
    walk_payload(records, selectors = list("#a", "")),
    walk_payload(records, selectors = list("#a", NA_character_)),
    walk_payload(records, selectors = list(list("#nested"))),
    walk_payload(records, selectors = list(a = "#named")),
    walk_payload(records, selectors = c("#a", "#b"), type = "heat"),
    walk_payload(records, selectors = list(list("#r1c1", "#r1c2")), type = "heat"),
    walk_payload(records, selectors = list("#a"), type = NA_character_),
    walk_payload(records, selectors = list("#a"), type = c("bar", "line")),
    walk_payload(records, selectors = I(list("#a", "#b")), type = "bar"),
    walk_payload(records, selectors = list("#é", "#☃"), type = "pie"),
    list(selectors = list(), nested = list(selectors = list(), keep = 1)),
    list(type = "bar", selectors = list("#x"), selectors = list("#y")),
    list(selectors = NULL, a = 1),
    structure(list(selectors = list(), x = 1), class = "odd"),
    list(frame = data.frame(selectors = 1:2), selectors = character(0)),
    list(),
    "leaf",
    NULL
  )
  drop <- maidr:::drop_empty_selectors
  flat <- maidr:::flatten_single_selectors
  for (payload in payloads) {
    dropped <- maidr:::drop_empty_selectors_cpp(payload, drop)
    expect_identical(dropped, drop(payload))
    expect_identical(
      maidr:::flatten_single_selectors_cpp(
        dropped, maidr:::SINGLE_SELECTOR_LAYER_TYPES, flat, maidr:::join_selector_list
      ),
      flat(dropped)
    )
  }
})

# The per-tile scan `heat_fill_scores()` replaced.
ref_heat_scores <- function(score_matrix, source, x_col, y_col, fill_col,
                            x_values, y_values, built_x, built_y) {
  x_mapping <- stats::setNames(x_values, seq_along(x_values))
  y_mapping <- stats::setNames(y_values, seq_along(y_values))
  for (i in seq_along(built_x)) {
    x_val <- x_mapping[as.character(built_x[i])]
    y_val <- y_mapping[as.character(built_y[i])]
    score_val <- source[[fill_col]][
      source[[x_col]] == x_val & source[[y_col]] == y_val
    ]
    if (length(score_val) > 0) {
      row_idx <- which(y_values == y_val)
      col_idx <- which(x_values == x_val)
      score_matrix[row_idx, col_idx] <- score_val[1]
    }
  }
  score_matrix
}

# The scan also changed the matrix's storage type on an assignment to no
# cell at all; the processor reads the matrix through as.numeric(), which
# is what is compared.
heat_case <- function(source, x_values, y_values, built_x, built_y) {
  empty <- matrix(NA, nrow = length(y_values), ncol = length(x_values))
  as_read <- function(m) suppressWarnings(structure(as.numeric(m), dim = dim(m)))
  expect_identical(
    as_read(maidr:::heat_fill_scores(
      empty, source, "x", "y", "z", x_values, y_values, built_x, built_y
    )),
    as_read(ref_heat_scores(empty, source, "x", "y", "z", x_values, y_values, built_x, built_y))
  )
}

test_that("the heatmap cell lookup fills what the per-tile scan filled", {
  set.seed(7)
  for (trial in 1:40) {
    nx <- sample(1:6, 1)
    ny <- sample(1:6, 1)
    n <- sample(0:40, 1)
    kind <- trial %% 4
    xl <- if (kind == 1) as.numeric(seq_len(nx)) * 1.5 else paste0("x", seq_len(nx))
    yl <- if (kind == 1) as.numeric(seq_len(ny)) else paste0("y", seq_len(ny))
    src_x <- sample(c(xl, NA, if (kind == 1) 99 else "stray"), n, TRUE)
    src_y <- sample(c(yl, NA), n, TRUE)
    source <- data.frame(x = src_x, y = src_y, z = round(runif(n), 3))
    if (kind == 2) {
      source$x <- factor(source$x, levels = xl)
      source$y <- factor(source$y, levels = yl)
    }
    if (kind == 3) source$z <- as.character(source$z)
    x_values <- if (kind == 1) unique(source$x) else xl
    y_values <- if (kind == 1) unique(source$y) else yl
    if (!length(x_values) || !length(y_values)) next
    built_x <- sample(c(seq_along(x_values), 0, NA, 2.5), 25, TRUE)
    built_y <- sample(c(seq_along(y_values), 0, NA), 25, TRUE)
    heat_case(source, x_values, y_values, built_x, built_y)
  }
})

test_that("the heatmap cell lookup handles factor fills and uncodable axes", {
  source <- data.frame(
    x = c("a", "b", "a", NA), y = c("p", "p", "q", "q"),
    z = factor(c("lo", "hi", "hi", "lo"))
  )
  heat_case(source, c("a", "b"), c("p", "q"), c(1, 2, 1, 2), c(1, 1, 2, 2))

  dates <- data.frame(
    x = as.Date("2024-01-01") + c(0, 1, 0, 1), y = c(1, 1, 2, 2), z = 1:4
  )
  heat_case(dates, unique(dates$x), unique(dates$y), c(1, 2, 1, 2), c(1, 1, 2, 2))

  missing_fill <- data.frame(x = c("a", "b"), y = c("p", "p"))
  heat_case(missing_fill, c("a", "b"), "p", c(1, 2), c(1, 1))
})
