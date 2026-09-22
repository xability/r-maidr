# Issue #312. The README, the getting-started vignette and the examples hub
# each carried their own keyboard table, and they had drifted from one
# another and from the MAIDR core's controls reference: the vignette listed
# Enter/Space as "Activate controls" and Escape as "Exit modes", neither of
# which the core binds (Space repeats the current sound), and the hub left
# out Up/Down, layer switching, label mode, high contrast and the help
# shortcut.
#
# The three pages cannot share a child document -- one is plain Markdown,
# one an Rmd vignette, one a Quarto article -- so the table is repeated,
# between `<!-- maidr-keys:start -->` and `<!-- maidr-keys:end -->` markers
# that every renderer drops, and this pins the three copies identical. A
# change to one that is not made to the others fails here rather than
# shipping as a fourth version of the keys.

key_table_pages <- c(
  README = testthat::test_path("..", "..", "README.md"),
  getting_started = testthat::test_path("..", "..", "vignettes", "getting-started.Rmd"),
  examples_hub = testthat::test_path("..", "..", "vignettes", "articles", "examples.qmd")
)

# `R CMD check` runs the tests from `<pkg>.Rcheck/tests/`, where `../..` is
# not the package root; the same shape as `skip_without_readme()` in
# test-plot-type-stability.R, and for the same reason.
skip_without_pages <- function() {
  testthat::skip_if_not(
    all(file.exists(key_table_pages)),
    "the documentation sources are not beside the tests under R CMD check"
  )
}

#' The lines between the key-table markers of one page
key_table_of <- function(path) {
  lines <- readLines(path, warn = FALSE)
  start <- which(lines == "<!-- maidr-keys:start -->")
  end <- which(lines == "<!-- maidr-keys:end -->")
  testthat::expect_length(start, 1L)
  testthat::expect_length(end, 1L)
  lines[seq(start + 1L, end - 1L)]
}

test_that("every page carries the same keyboard table", {
  skip_without_pages()

  tables <- lapply(key_table_pages, key_table_of)
  for (page in names(tables)[-1]) {
    testthat::expect_identical(
      tables[[page]], tables[["README"]],
      label = paste0("key table on ", page),
      expected.label = "key table in the README"
    )
  }
})

test_that("the table carries the keys the hub left out, and links to the rest", {
  skip_without_pages()

  table <- paste(key_table_of(key_table_pages[["README"]]), collapse = "\n")

  for (key in c("Up / Down", "Page Up / Page Down", "**L**", "**C**", "Ctrl + /")) {
    testthat::expect_match(table, key, fixed = TRUE, label = key)
  }
  testthat::expect_match(table, "https://maidr.ai/docs/CONTROLS.html", fixed = TRUE)
})

test_that("the table binds Space and Escape the way the core does", {
  skip_without_pages()

  table <- key_table_of(key_table_pages[["README"]])

  space <- grep("**Space**", table, fixed = TRUE, value = TRUE)
  testthat::expect_length(space, 1L)
  testthat::expect_match(space, "Repeat the current sound", fixed = TRUE)
  testthat::expect_false(any(grepl("Escape", table, fixed = TRUE)))
  testthat::expect_false(any(grepl("Enter", table, fixed = TRUE)))
})
