# Issue #320. Attaching maidr masks the show generic from methods, and
# maidr's own show took any non-NULL argument for a plot: it asked the
# registry which system could handle it, got nothing for an S4 object or a
# vector, and died with "argument is of length zero". Anyone who showed an
# S4 object with maidr attached lost the print they had before. Such an
# object is now handed to the methods generic.

methods::setClass("MaidrTestThing", representation(v = "numeric"))

test_that("show() hands an S4 object to methods::show()", {
  thing <- methods::new("MaidrTestThing", v = 1)

  testthat::expect_output(
    maidr::show(thing),
    'An object of class "MaidrTestThing"',
    fixed = TRUE
  )
})

test_that("show() prints a vector as methods::show() does", {
  testthat::expect_output(maidr::show(1:3), "[1] 1 2 3", fixed = TRUE)
})

test_that("show() returns methods::show()'s invisible NULL for such objects", {
  utils::capture.output(result <- withVisible(maidr::show(1:3)))

  testthat::expect_null(result$value)
  testthat::expect_false(result$visible)
})

test_that("a recorded Base R chart does not capture an S4 object", {
  # The Base R adapter claims by device state, so with a chart recorded a
  # registry lookup would have said "Base R" for the S4 object and rendered
  # the chart instead of printing the object.
  clear_base_r_state()
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  barplot(c(1, 2, 3))

  thing <- methods::new("MaidrTestThing", v = 2)
  testthat::expect_output(
    maidr::show(thing),
    'An object of class "MaidrTestThing"',
    fixed = TRUE
  )

  clear_base_r_state()
})
