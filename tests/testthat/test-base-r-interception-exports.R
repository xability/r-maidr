# A HIGH-classified call that maidr does not export is never intercepted.
#
# Interception works by *shadowing*: `.onLoad` runs `wrap_function()`, which
# installs the recording wrapper into maidr's own namespace. A user's bare
# `acf(x)` resolves through the search path, so it only reaches that wrapper
# when `package:maidr` carries the name -- that is, when maidr exports it.
# Without the export the call finds `stats::acf` directly, the chart draws,
# and `save_html()` then reports that no Base R plot was found.
#
# Measured: twelve HIGH names -- acf, pacf, ccf, cpgram, spectrum, monthplot,
# termplot, lag.plot, biplot, bxp, stars, interaction.plot -- were classified
# and given layer processors but never exported, and produced zero layers
# against an installed package while their own tests passed.
#
# The tests passed because `load_all()` leaves the namespace open and runs
# each test in an environment whose parent *is* that namespace, so a bare
# call reaches the wrapper there and nowhere else. No drawing test can see
# this. A static check on the export list can, and it reads the same in both
# modes because `getNamespaceExports()` reflects NAMESPACE either way.

test_that("every chart-producing Base R call is exported by maidr", {
  high <- get_functions_by_class("HIGH")
  testthat::expect_gt(length(high), 0)

  missing <- setdiff(high, getNamespaceExports("maidr"))

  testthat::expect_equal(
    missing, character(0),
    info = paste0(
      "These HIGH-classified functions are not exported, so a bare call ",
      "reaches the original and is never recorded: ",
      paste(missing, collapse = ", "),
      ". Add a stub to R/base_r_wrapper_exports.R."
    )
  )
})


test_that("an exported wrapper still resolves to a function", {
  # A stub that fails to define anything would satisfy the check above only
  # if it were absent from NAMESPACE too, but a typo in the delegation
  # target would not show up until the call ran. Cheap to rule out here.
  for (fn in get_functions_by_class("HIGH")) {
    testthat::expect_true(
      is.function(getExportedValue("maidr", fn)),
      info = paste("not a function:", fn)
    )
  }
})
