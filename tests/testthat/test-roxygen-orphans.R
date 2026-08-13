# No roxygen block may be immediately followed by another.
#
# Inserting a method next to a landmark without checking what the landmark is
# attached to strands the block already there: roxygen glues the two comments
# together, so the new method inherits the old one's @description, @param and
# @return, and the old method is left with a bare Usage section naming
# arguments that belong to something else.
#
# `tools::checkRd()` cannot see it -- the generated Rd is valid, it just
# documents the wrong function. It happened in #152, where
# `resolve_layer_polygon_grob(plot, roots)` was documented as taking a `grob`,
# and it took a reviewer reading the man page to notice.
#
# The check is on the SOURCE rather than on man/, because man/ is regenerated
# and this is about what the sources say.

r_sources <- function() {
  list.files(
    testthat::test_path("..", "..", "R"),
    pattern = "\\.R$",
    full.names = TRUE
  )
}

# Two roxygen blocks in a row: a line that is roxygen, then a line that starts
# one, with only blank or roxygen-blank lines between. A block ends at the
# first line that is neither, so anything else in between is code and the two
# are separate blocks.
orphaned_blocks <- function(path) {
  lines <- readLines(path, warn = FALSE)
  is_roxygen <- grepl("^\\s*#'", lines)
  if (!any(is_roxygen)) {
    return(integer(0))
  }

  # A `@description` after the first one in the same block is the signature:
  # roxygen takes one per object, so a second means two blocks were merged.
  starts <- which(grepl("^\\s*#'\\s*@description", lines))
  offenders <- integer(0)
  for (start in starts) {
    # Walk back to the top of this contiguous roxygen block.
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

test_that("there are R sources to check", {
  # A path that stopped resolving would make the case below vacuous.
  testthat::expect_gt(length(r_sources()), 20L)
})

test_that("no roxygen block carries two descriptions", {
  reported <- character(0)
  for (path in r_sources()) {
    for (line in orphaned_blocks(path)) {
      reported <- c(reported, paste0(basename(path), ":", line))
    }
  }

  testthat::expect_equal(reported, character(0))
})

test_that("the check can see a stranded block", {
  # Written to a temporary file rather than asserted against a real source,
  # so the case keeps testing the check after the sources are all clean.
  path <- tempfile(fileext = ".R")
  on.exit(unlink(path), add = TRUE)
  writeLines(
    c(
      "    #' @description The first one",
      "    #' @param grob A grob",
      "    #' @return Something",
      "    #' @description The second one, stranding the first",
      "    #' @return Something else",
      "    only_one = function(x) x"
    ),
    path
  )

  testthat::expect_length(orphaned_blocks(path), 1L)
})

test_that("two separated blocks are not reported", {
  path <- tempfile(fileext = ".R")
  on.exit(unlink(path), add = TRUE)
  writeLines(
    c(
      "    #' @description The first one",
      "    #' @return Something",
      "    first = function(x) x,",
      "",
      "    #' @description The second one",
      "    #' @return Something else",
      "    second = function(x) x"
    ),
    path
  )

  testthat::expect_length(orphaned_blocks(path), 0L)
})
