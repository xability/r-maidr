# find_original_function() must not walk out onto the search path (issue #111).
#
# A namespace environment's parent chain ends at the search path, so
# `get(name, envir = asNamespace("graphics"))` with R's default
# `inherits = TRUE` keeps looking past graphics and into whatever is attached
# -- including `package:maidr`. Any name graphics does not own therefore
# resolved to maidr's OWN recording wrapper, which was then stored as the
# "original" and handed to the replay as the function to call.
#
# chartSeries hit this in the field: maidr's quantmod hook runs while quantmod
# is loaded but not yet ATTACHED, so `package:maidr` was ahead of it on the
# path and maidr's own stub was recorded as quantmod's original.

test_that("the namespace search stops at the namespaces it names", {
  # A name no plotting namespace owns, bound where the old inherited lookup
  # would have found it. This is the whole defect in four lines.
  name <- "maidr_test_not_a_plotting_function"
  assign(name, function(...) "from the search path", envir = globalenv())
  on.exit(rm(list = name, envir = globalenv()), add = TRUE)

  testthat::expect_null(maidr:::find_original_function(name))
})

test_that("find_original_function never answers with one of maidr's own", {
  maidr_env <- asNamespace("maidr")

  # Every name maidr both exports and wraps is a candidate for the search
  # path finding maidr's copy before the owning namespace's.
  wrapped <- names(maidr:::.maidr_patching_env$.saved_graphics_fns)
  testthat::expect_gt(length(wrapped), 0)

  for (name in wrapped) {
    original <- maidr:::find_original_function(name)
    if (is.null(original)) {
      next
    }
    testthat::expect_false(
      identical(environment(original), maidr_env),
      info = name
    )
  }
})

test_that("every wrapped function still resolves to a real namespace", {
  # The other half: narrowing the lookup must not lose anything. `plot` is
  # the one that proves `base` is in the chain -- it moved out of `graphics`
  # in R 4.0, so an inherited lookup was what found it before.
  for (name in names(maidr:::.maidr_patching_env$.saved_graphics_fns)) {
    testthat::expect_false(
      is.null(maidr:::find_original_function(name)),
      info = name
    )
  }

  plot_original <- maidr:::find_original_function("plot")
  testthat::expect_true(
    identical(plot_original, get("plot", envir = asNamespace("base")))
  )
})

test_that("a saved original is still preferred over any namespace", {
  # The first branch is what prevents double-wrapping, and narrowing the
  # namespace probes below it must not disturb that ordering.
  sentinel <- function(...) "sentinel"
  # `:::` cannot appear on the left of an assignment, so hold the environment.
  patching <- maidr:::.maidr_patching_env
  saved <- patching$.saved_graphics_fns[["barplot"]]
  patching$.saved_graphics_fns[["barplot"]] <- sentinel
  on.exit(patching$.saved_graphics_fns[["barplot"]] <- saved, add = TRUE)

  testthat::expect_identical(maidr:::find_original_function("barplot"), sentinel)
})
