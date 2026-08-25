# `gridSVG::grid.export()` warns "number of items to replace is not a
# multiple of replacement length" on any rect grob drawn with a negative
# height or width, and a plot that warns falls back to a picture (#266).
#
# Measured on a bare `rectGrob()` with nothing else to it: four rects with
# positive heights export silently, and the same four with two heights
# negated warn. So this is an upstream gridSVG defect rather than anything
# about a particular chart -- but `assocplot()` reaches it by construction,
# drawing every tile from a baseline with a signed height.

test_that("a rect drawn with a negative height is restated positively", {
  grob <- grid::rectGrob(
    x = c(0.2, 0.4), y = 0.5, width = 0.1,
    height = grid::unit(c(0.3, -0.2), "npc"),
    just = c("left", "bottom")
  )

  repaired <- normalise_negative_rects(grob)

  expect_equal(as.numeric(repaired$height), c(0.3, 0.2))
  # The same rectangle: the one that hung below 0.5 now starts at 0.3.
  expect_equal(as.numeric(repaired$y), c(0.5, 0.3))
})

test_that("a rect already drawn positively is left exactly as it was", {
  grob <- grid::rectGrob(
    x = 0.2, y = 0.5, width = 0.1, height = grid::unit(0.3, "npc"),
    just = c("left", "bottom")
  )

  repaired <- normalise_negative_rects(grob)

  expect_equal(as.numeric(repaired$y), 0.5)
  expect_equal(as.numeric(repaired$height), 0.3)
})

test_that("a negative width is restated the same way", {
  grob <- grid::rectGrob(
    x = grid::unit(c(0.5, 0.8), "npc"), y = 0.5,
    width = grid::unit(c(0.1, -0.2), "npc"), height = 0.1,
    just = c("left", "bottom")
  )

  repaired <- normalise_negative_rects(grob)

  expect_equal(as.numeric(repaired$width), c(0.1, 0.2))
  expect_equal(as.numeric(repaired$x), c(0.5, 0.6))
})

test_that("a rect anchored anywhere but the low edge is left alone", {
  # Moving the anchor of a centred rect would move the rectangle rather than
  # restate it, so those keep their negative extent -- warning and all --
  # rather than being silently redrawn somewhere else.
  grob <- grid::rectGrob(
    x = 0.5, y = 0.5, width = 0.1, height = grid::unit(-0.2, "npc"),
    just = "centre"
  )

  repaired <- normalise_negative_rects(grob)

  expect_equal(as.numeric(repaired$height), -0.2)
  expect_equal(as.numeric(repaired$y), 0.5)
})

test_that("rects nested in a tree are reached", {
  tree <- grid::gTree(children = grid::gList(
    grid::rectGrob(
      x = 0.2, y = 0.5, width = 0.1, height = grid::unit(-0.2, "npc"),
      just = c("left", "bottom"), name = "inner"
    )
  ))

  repaired <- normalise_negative_rects(tree)

  inner <- grid::getGrob(repaired, "inner")
  expect_equal(as.numeric(inner$height), 0.2)
  expect_equal(as.numeric(inner$y), 0.3)
})

test_that("exporting a rect with negative heights no longer warns", {
  skip_on_cran()
  grob <- grid::rectGrob(
    x = 1:4 / 5, y = 0.5, width = 0.1,
    height = grid::unit(c(0.1, -0.2, 0.3, -0.4), "npc"),
    just = c("left", "bottom"),
    gp = grid::gpar(fill = c("red", "red", "black", "black"))
  )
  file <- withr::local_tempfile(fileext = ".svg")

  warnings <- character()
  withCallingHandlers({
    grDevices::pdf(NULL)
    grid::grid.newpage()
    grid::grid.draw(normalise_negative_rects(grob))
    suppressMessages(gridSVG::grid.export(file, res = 96))
    grDevices::dev.off()
  }, warning = function(w) {
    warnings <<- c(warnings, conditionMessage(w))
    invokeRestart("muffleWarning")
  })

  expect_equal(warnings, character())
})
