# README's stability split has to cover every supported layer type
#
# "Supported plot types" divides what the two adapters read into tables that
# predate the coverage roadmap and an "Experimental Plot Types" section that
# does not. The split is a promise: the first set has been exercised by real
# readers, the second is prototypes that may change in a patch release.
#
# A type in neither set inherits whichever promise the reader assumes, which
# is the failure this guards. Thirty-one types were added across the two
# factories in a few weeks; at that rate a new one reaching a factory and not
# the README is the expected outcome, not an unlikely one.
#
# The stable side is checked as a *baseline*, not scraped: those tables name
# charts ("Bar charts", "Density/Smooth") rather than layer types, so there is
# no type string in them to read. The baseline is the diff source the README
# names -- each factory's `get_supported_types()` at `8de0e98`, the last
# commit before #137 was filed -- written out here so the check does not need
# a git history to run against.

#' Layer types each factory claimed before the coverage roadmap
STABLE <- list(
  ggplot2 = c(
    "bar", "box", "candlestick", "dodged_bar", "heat", "hist", "line", "pie",
    "point", "smooth", "stacked_bar", "step", "unknown", "violin"
  ),
  base_r = c(
    "bar", "box", "candlestick", "contour", "dodged_bar", "heat", "hist",
    "line", "pie", "point", "smooth", "stacked_bar", "step", "unknown"
  )
)

#' The README's lines, or `character(0)` where it is not reachable
readme_lines <- function() {
  path <- testthat::test_path("..", "..", "README.md")
  if (!file.exists(path)) {
    return(character(0))
  }
  readLines(path, warn = FALSE)
}

# `R CMD check` copies the tests into `<pkg>.Rcheck/tests/` and runs them
# there, so `../..` is the check directory rather than the package root and
# the README is not beside it -- the same shape as
# `skip_without_sources()` in test-roxygen-orphans.R, and for the same
# reason. This says so instead of failing. It runs on `devtools::test()` and
# `testthat::test_local()`, which is the loop a type is added in.
skip_without_readme <- function() {
  testthat::skip_if(
    length(readme_lines()) == 0L,
    "README.md is not beside the tests under R CMD check"
  )
}

#' The layer types named in one `####` sub-table of the experimental section
experimental_in_readme <- function(heading) {
  skip_without_readme()
  readme <- paste(readme_lines(), collapse = "\n")

  marker <- paste0("\n#### ", heading, "\n")
  testthat::expect_true(
    grepl(marker, readme, fixed = TRUE),
    label = paste0("README has a '#### ", heading, "' table")
  )

  after <- strsplit(readme, marker, fixed = TRUE)[[1]][[2]]
  body <- strsplit(after, "\n#", fixed = TRUE)[[1]][[1]]

  # A row is `| \`type\` | drawn by |`; the first cell is the layer type.
  rows <- regmatches(body, gregexpr("\n\\| `[a-z_0-9]+` \\|", body))[[1]]
  unique(gsub("^\n\\| `|` \\|$", "", rows))
}


test_that("every ggplot2 layer type is classified as stable or experimental", {
  supported <- Ggplot2ProcessorFactory$new()$get_supported_types()
  classified <- c(STABLE$ggplot2, experimental_in_readme("ggplot2"))

  testthat::expect_setequal(classified, supported)
})


test_that("every base R layer type is classified as stable or experimental", {
  supported <- BaseRProcessorFactory$new()$get_supported_types()
  classified <- c(STABLE$base_r, experimental_in_readme("Base R"))

  testthat::expect_setequal(classified, supported)
})


test_that("no layer type is called both stable and experimental", {
  # Each list reads as complete on its own, so an overlap makes both wrong.
  testthat::expect_length(
    intersect(STABLE$ggplot2, experimental_in_readme("ggplot2")), 0
  )
  testthat::expect_length(
    intersect(STABLE$base_r, experimental_in_readme("Base R")), 0
  )
})


test_that("the boundary is where the README says it is", {
  # `violin` is a ggplot2 type from before the roadmap and `area` the first
  # added after, so this pair is where an off-by-one in the boundary shows.
  testthat::expect_true("violin" %in% STABLE$ggplot2)
  testthat::expect_true("area" %in% experimental_in_readme("ggplot2"))

  # Base R's own last-before and first-after.
  testthat::expect_true("candlestick" %in% STABLE$base_r)
  testthat::expect_true("radar" %in% experimental_in_readme("Base R"))
})


test_that("the README says what the experimental set does not promise", {
  # The tables alone would read as a changelog. What makes the section usable
  # is the claim attached to it, so the claim is pinned too -- softening the
  # wording without revisiting the split fails here. Whitespace is normalised
  # because these phrases wrap across lines and a reflow should not be what
  # breaks this test.
  skip_without_readme()
  # The warning is a GitHub alert, so its lines carry a "> " prefix that would
  # otherwise land in the middle of a phrase once the lines are joined.
  prose <- gsub(
    "\\s+", " ",
    paste(sub("^> ?", "", readme_lines()), collapse = " ")
  )

  testthat::expect_true(grepl(
    "These are prototypes. Treat them as prototypes.", prose, fixed = TRUE
  ))
  testthat::expect_true(grepl(
    "has been through a user study", prose, fixed = TRUE
  ))
  testthat::expect_true(grepl(
    "without a deprecation period", prose, fixed = TRUE
  ))
})
