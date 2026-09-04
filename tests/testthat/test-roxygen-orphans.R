# Roxygen blocks that document something other than what they sit on
#
# roxygen2 attaches a comment block to the next object, and it does so
# silently in three ways this package has been bitten by:
#
# 1. Two blocks with only blank lines between them are ONE block. The first
#    is merged into the second, its title becomes the page title, and the
#    second block's title is scattered into `\keyword{}` entries, one word
#    each. A helper inserted above a landmark without a line of code between
#    them takes the landmark's page with it (#152, and twice more since).
# 2. An R6 method block that opens with untagged text instead of
#    `@description` glues that sentence onto the previous method's Returns
#    or the last `@param` of the method before it (#109, #116).
# 3. A file-level block that is not terminated by `NULL` and carries no
#    `@name` documents whatever object comes next (#116).
#
# `tools::checkRd()` and `R CMD check` cannot see any of it -- the Rd is
# valid, it just describes the wrong thing. roxygen2 itself warns on some
# of it ("@keywords must be only 1 line long" when the merged block ends in
# a keyword, "Skipping; no name and/or title" for the class), and
# `tools/document.R` and the `docs-drift` CI job fail on any such warning.
# The rest is silent: a block merged into one ending in `@return` or
# `@param`, and the method prose glued onto the previous section. The
# checks here are on the SOURCE, because `man/` is regenerated.

r_sources <- function() {
  list.files(
    testthat::test_path("..", "..", "R"),
    pattern = "\\.R$",
    full.names = TRUE
  )
}

# `R CMD check` runs the tests against an *installed* package, where `R/` holds
# the lazy-load database rather than the sources -- so there is nothing to read
# and this says so instead of failing. It runs on `devtools::test()`,
# `testthat::test_local()` and the `test-local` CI job, which is the loop the
# mistake is made in.
skip_without_sources <- function() {
  testthat::skip_if(
    length(r_sources()) == 0L,
    "R/ sources are not shipped with an installed package"
  )
}

is_roxygen_line <- function(lines) grepl("^\\s*#'", lines)

# The first line of every contiguous run of roxygen lines.
block_starts <- function(is_roxygen) {
  which(is_roxygen & !c(FALSE, is_roxygen[-length(is_roxygen)]))
}

# A `@description` after the first one in the same block: roxygen takes one
# per object, so a second means two blocks were merged.
orphaned_blocks <- function(path) {
  lines <- readLines(path, warn = FALSE)
  is_roxygen <- is_roxygen_line(lines)
  if (!any(is_roxygen)) {
    return(integer(0))
  }

  starts <- which(grepl("^\\s*#'\\s*@description", lines))
  offenders <- integer(0)
  for (start in starts) {
    top <- start
    while (top > 1L && is_roxygen[top - 1L]) {
      top <- top - 1L
    }
    # `seq.int` counts backwards when the ends cross, so an empty range has
    # to be excluded rather than iterated -- otherwise every block reports
    # its own first description as a duplicate of itself.
    if (top >= start) {
      next
    }
    earlier <- which(
      grepl("^\\s*#'\\s*@description", lines[seq.int(top, start - 1L)])
    )
    if (length(earlier) > 0L) {
      offenders <- c(offenders, start)
    }
  }
  offenders
}

# A block followed, across blank lines only, by another block or by the end
# of the file. Measured with roxygen2 8.1.0: the two are read as one, the
# first block's title wins, and the second block's title is scattered into
# `\keyword{}` entries. Returns the first line of each block left stranded.
adjacent_blocks <- function(path) {
  lines <- readLines(path, warn = FALSE)
  is_roxygen <- is_roxygen_line(lines)
  is_blank <- grepl("^\\s*$", lines)
  n <- length(lines)
  offenders <- integer(0)
  for (start in block_starts(is_roxygen)) {
    after <- start
    while (after <= n && is_roxygen[after]) {
      after <- after + 1L
    }
    while (after <= n && is_blank[after]) {
      after <- after + 1L
    }
    if (after > n || is_roxygen[after]) {
      offenders <- c(offenders, start)
    }
  }
  offenders
}

# An indented block -- an R6 method's -- whose first line is prose rather
# than a tag. A top-level block opens with its title, but a method has no
# title: roxygen glues untagged text onto whatever section the previous
# method's block ended in. Returns the first line of each such block.
untitled_method_blocks <- function(path) {
  lines <- readLines(path, warn = FALSE)
  is_roxygen <- is_roxygen_line(lines)
  starts <- block_starts(is_roxygen)
  starts <- starts[grepl("^\\s+#'", lines[starts])]
  first_words <- sub("^\\s*#'\\s*", "", lines[starts])
  starts[nzchar(first_words) & !grepl("^@", first_words)]
}

report <- function(paths, finder) {
  reported <- character(0)
  for (path in paths) {
    for (hit in finder(path)) {
      reported <- c(reported, paste0(basename(path), ":", hit))
    }
  }
  reported
}

test_that("there are R sources to check", {
  skip_without_sources()

  # A path that stopped resolving would make the cases below vacuous.
  testthat::expect_gt(length(r_sources()), 20L)
})

test_that("no roxygen block carries two descriptions", {
  skip_without_sources()

  testthat::expect_equal(report(r_sources(), orphaned_blocks), character(0))
})

test_that("no roxygen block is followed by another with only blank lines between", {
  skip_without_sources()

  testthat::expect_equal(report(r_sources(), adjacent_blocks), character(0))
})

test_that("every R6 method block opens with a tag", {
  skip_without_sources()

  testthat::expect_equal(
    report(r_sources(), untitled_method_blocks), character(0)
  )
})

# The detectors, each against a temporary file rather than a real source, so
# the cases keep testing the checks after the sources are all clean.

write_case <- function(lines) {
  path <- tempfile(fileext = ".R")
  writeLines(lines, path)
  path
}

test_that("the check can see a stranded block", {
  path <- write_case(c(
    "    #' @description The first one",
    "    #' @param grob A grob",
    "    #' @return Something",
    "    #' @description The second one, stranding the first",
    "    #' @return Something else",
    "    only_one = function(x) x"
  ))
  on.exit(unlink(path), add = TRUE)

  testthat::expect_length(orphaned_blocks(path), 1L)
})

test_that("two separated blocks are not reported", {
  path <- write_case(c(
    "    #' @description The first one",
    "    #' @return Something",
    "    first = function(x) x,",
    "",
    "    #' @description The second one",
    "    #' @return Something else",
    "    second = function(x) x"
  ))
  on.exit(unlink(path), add = TRUE)

  testthat::expect_length(orphaned_blocks(path), 0L)
  testthat::expect_length(adjacent_blocks(path), 0L)
  testthat::expect_length(untitled_method_blocks(path), 0L)
})

test_that("a block separated from the next only by blank lines is reported", {
  path <- write_case(c(
    "#' First helper",
    "#' @param x A value",
    "",
    "#' Second helper",
    "#' @param y A value",
    "second <- function(y) y",
    "",
    "first <- function(x) x"
  ))
  on.exit(unlink(path), add = TRUE)

  testthat::expect_identical(adjacent_blocks(path), 1L)
})

test_that("a block at the end of a file is reported", {
  path <- write_case(c(
    "helper <- function(x) x",
    "",
    "#' Documents nothing",
    "#' @param x A value"
  ))
  on.exit(unlink(path), add = TRUE)

  testthat::expect_identical(adjacent_blocks(path), 3L)
})

test_that("a NULL-terminated file-level block is not reported", {
  path <- write_case(c(
    "#' What this file holds",
    "#'",
    "#' @keywords internal",
    "NULL",
    "",
    "#' A helper",
    "#' @param x A value",
    "helper <- function(x) x"
  ))
  on.exit(unlink(path), add = TRUE)

  testthat::expect_length(adjacent_blocks(path), 0L)
})

test_that("a method block opening with prose is reported", {
  path <- write_case(c(
    "    #' Process the layer",
    "    #' @param plot The plot",
    "    process = function(plot) plot,",
    "",
    "    #' @description Tagged, so fine",
    "    #' @param plot The plot",
    "    other = function(plot) plot"
  ))
  on.exit(unlink(path), add = TRUE)

  testthat::expect_identical(untitled_method_blocks(path), 1L)
})
