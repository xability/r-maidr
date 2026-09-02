# Outlier selectors follow the points grobs bxp() actually draws
#
# `bxp()` draws each box's outliers with one `points()` call, and only when
# the box has any. The selector used `2 * i` for the i-th box's points grob,
# which is right only while every earlier box has outliers; each box without
# them shifts the later grobs down by one. The segment selectors already
# applied that shift; the points selector did not, so a box drawn after an
# outlier-free one was outlined on the *next* box's outliers.

test_that("a box after an outlier-free box points at its own outliers", {
  clean <- 1:9
  spiked <- c(1:9, 40)
  spiked_more <- c(1:9, 50)

  grDevices::pdf(NULL)
  device_id <- grDevices::dev.cur()
  on.exit(grDevices::dev.off(), add = TRUE)
  clear_base_r_device(device_id)
  on.exit(clear_base_r_device(device_id), add = TRUE)

  boxplot(list(a = clean, b = spiked, c = spiked_more))

  orchestrator <- maidr:::BaseRPlotOrchestrator$new(device_id)
  layer <- orchestrator$generate_maidr_data()$subplots[[1]][[1]]$layers[[1]]
  drawn <- grid::grid.ls(orchestrator$get_gtable(), print = FALSE)$name
  points_grobs <- grep("^graphics-plot-1-points-[0-9]+$", drawn, value = TRUE)

  # Two boxes have outliers, so two points grobs are drawn besides the
  # medians': 3 and 5, not 4 and 6.
  grob_of <- function(selector) {
    as.integer(sub(".*points-([0-9]+).*", "\\1", selector))
  }
  second <- grob_of(layer$selectors[[2]]$upperOutliers[[1]])
  third <- grob_of(layer$selectors[[3]]$upperOutliers[[1]])

  testthat::expect_true(paste0("graphics-plot-1-points-", second) %in% points_grobs)
  testthat::expect_true(paste0("graphics-plot-1-points-", third) %in% points_grobs)
  testthat::expect_identical(c(second, third), c(3L, 5L))
})
