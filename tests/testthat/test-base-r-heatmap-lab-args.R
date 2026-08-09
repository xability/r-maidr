# heatmap()'s own labRow= / labCol= arguments (issue #106).
#
# stats::heatmap resolves each axis in a single expression: it takes the
# caller's own labRow subscripted by rowInd when there is one, falling back to
# the reordered matrix's rownames and then to the original indices in drawn
# order. The caller's labels come FIRST and beat dimnames, and they carry the
# same ordering as the data. Issue 99 implemented the second and third arms of
# that fallback; the first was missing, so an explicit labRow= drew one set of
# strings on the axis and announced another.
#
# The announced y order is the REVERSE of the drawn one throughout: heatmap()
# puts reordered row 1 at the bottom of the image, and the payload's row 0 is
# the top. That convention is unchanged here and is what `rev()` below undoes
# before comparing against the drawn labels.

lab_matrix <- function() {
  matrix(
    c(1, 9, 2, 8, 3, 7, 4, 6, 5, 2, 2, 9, 7, 1, 4),
    nrow = 5, byrow = TRUE
  )
}

lab_rows <- c("alpha", "beta", "gamma", "delta", "epsilon")
lab_cols <- c("one", "two", "three")

# The ordering heatmap() itself picks for this matrix, taken from the function
# rather than hard-coded, so the expectations stay tied to what R does.
lab_ordering <- function(...) {
  file <- tempfile(fileext = ".pdf")
  grDevices::pdf(file)
  on.exit({
    grDevices::dev.off()
    unlink(file)
  }, add = TRUE)
  stats::heatmap(...)
}

# Render a recorded Base R heatmap and return its emitted labels alongside
# every string the export actually drew.
lab_render <- function(draw) {
  maidr:::clear_all_device_storage()
  file <- tempfile(fileext = ".html")
  on.exit({
    unlink(file)
    maidr:::clear_all_device_storage()
  }, add = TRUE)

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

  layer <- jsonlite::fromJSON(
    json,
    simplifyVector = FALSE
  )$subplots[[1]][[1]]$layers[[1]]

  document <- xml2::read_html(file)

  list(
    x = unlist(layer$data$x),
    y = unlist(layer$data$y),
    glyphs = trimws(
      xml2::xml_text(xml2::xml_find_all(document, "//*[local-name()='text']"))
    )
  )
}

skip_if_no_lab_render <- function() {
  testthat::skip_if_not_installed("xml2")
  testthat::skip_if_not_installed("jsonlite")
}

test_that("an explicit labRow / labCol is announced, in the drawn order", {
  skip_if_no_lab_render()

  m <- lab_matrix()
  ordering <- lab_ordering(m)
  drawn_rows <- lab_rows[ordering$rowInd]
  drawn_cols <- lab_cols[ordering$colInd]

  rendered <- lab_render(function() {
    heatmap(m, labRow = lab_rows, labCol = lab_cols)
  })

  # Before the fix these came back as the bare indices "2 5 4 3 1" / "2 1 3"
  # while the axis showed the caller's words.
  testthat::expect_equal(rev(rendered$y), drawn_rows)
  testthat::expect_equal(rendered$x, drawn_cols)

  # And those are the strings the export really drew, not just the ones
  # stats::heatmap says it would.
  testthat::expect_true(all(c(drawn_rows, drawn_cols) %in% rendered$glyphs))
})

test_that("labRow beats the matrix's own dimnames, the way heatmap() does", {
  skip_if_no_lab_render()

  m <- lab_matrix()
  dimnames(m) <- list(lab_rows, lab_cols)
  ordering <- lab_ordering(m)

  rendered <- lab_render(function() heatmap(m, labRow = toupper(lab_rows)))

  # `labRow[rowInd]` is the first arm of the expression, so dimnames never
  # get a look in on that axis. The column axis has no labCol, so it keeps
  # its dimnames - which is the other half of the same precedence rule.
  testthat::expect_equal(rev(rendered$y), toupper(lab_rows)[ordering$rowInd])
  testthat::expect_equal(rendered$x, lab_cols[ordering$colInd])
  testthat::expect_true(all(toupper(lab_rows) %in% rendered$glyphs))
})

test_that("an unclustered heatmap takes the labels as written", {
  skip_if_no_lab_render()

  m <- lab_matrix()
  rendered <- lab_render(function() {
    heatmap(m, Rowv = NA, Colv = NA, labRow = lab_rows, labCol = lab_cols)
  })

  # `Rowv = NA` makes rowInd the identity, so no permutation is applied and
  # the labels read in the caller's own order.
  testthat::expect_equal(rev(rendered$y), lab_rows)
  testthat::expect_equal(rendered$x, lab_cols)
})

test_that("a heatmap with no labRow is unchanged", {
  skip_if_no_lab_render()

  m <- lab_matrix()
  ordering <- lab_ordering(m)

  # Issue 99's two arms, pinned here so the new first arm cannot displace
  # them: an unnamed matrix keeps the original indices in drawn order, and a
  # named one keeps its dimnames.
  unnamed <- lab_render(function() heatmap(m))
  testthat::expect_equal(rev(unnamed$y), as.character(ordering$rowInd))
  testthat::expect_equal(unnamed$x, as.character(ordering$colInd))

  named <- lab_matrix()
  dimnames(named) <- list(lab_rows, lab_cols)
  named_ordering <- lab_ordering(named)
  rendered <- lab_render(function() heatmap(named))
  testthat::expect_equal(rev(rendered$y), lab_rows[named_ordering$rowInd])
  testthat::expect_equal(rendered$x, lab_cols[named_ordering$colInd])
})

test_that("image() is untouched by the labRow arm", {
  skip_if_no_lab_render()

  # image() has no labRow/labCol and never reorders, so the arm must not fire
  # for it - it is guarded on the function name, not on the arguments.
  rendered <- lab_render(function() image(lab_matrix()))
  testthat::expect_equal(rendered$x, as.character(seq_len(5)))
  testthat::expect_equal(rendered$y, as.character(rev(seq_len(3))))
})

test_that("heatmap_caller_labels mirrors heatmap()'s own subscript", {
  # No labels for this axis: the caller said nothing, so the dimnames arm
  # below it has to run. Returning character(0) here would silence it.
  testthat::expect_null(maidr:::heatmap_caller_labels(NULL, c(2L, 1L)))
  testthat::expect_null(maidr:::heatmap_caller_labels(NULL, NULL))

  testthat::expect_equal(
    maidr:::heatmap_caller_labels(c("a", "b", "c"), c(3L, 1L, 2L)),
    c("c", "a", "b")
  )

  # No ordering recovered: the caller passes the identity rather than NULL,
  # because heatmap() applies a subscript either way. That is also what holds
  # the result to one label per row when the caller supplies the wrong number
  # (raised in review of this PR).
  testthat::expect_equal(
    maidr:::heatmap_caller_labels(c("a", "b"), seq_len(2)),
    c("a", "b")
  )
  testthat::expect_length(
    maidr:::heatmap_caller_labels(c("a", "b", "c", "d"), seq_len(2)), 2
  )

  # A short vector yields NA for the positions it cannot fill, which is
  # exactly what heatmap() hands to axis() and grid draws as "NA".
  testthat::expect_equal(
    maidr:::heatmap_caller_labels(c("a", "b"), c(1L, 3L, 2L)),
    c("a", NA, "b")
  )
  testthat::expect_length(
    maidr:::heatmap_caller_labels(c("a", "b"), seq_len(4)), 4
  )

  # Non-character labels are coerced, because axis() renders them the same.
  testthat::expect_equal(
    maidr:::heatmap_caller_labels(c(10, 20), c(2L, 1L)),
    c("20", "10")
  )
})
