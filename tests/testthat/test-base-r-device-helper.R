# The shared base R device idiom has to leave nothing behind (#241).
#
# The recorded calls outlive the device that made them -- `dev.off()` closes
# the device and drops none of its storage -- and R reuses device numbers.
# So a helper that clears on the way *in* and not on the way out hands its
# chart to the next caller that draws **without opening a device of its
# own**, and that caller reads it as its own.
#
# It happened: `test-base-r-spike-plot-type.R` sorts immediately before
# `test-base-r-step-layer-processor.R`, which reads `dev.cur()` directly,
# and the step file read the spike file's last control chart -- three
# failures in a file whose author had touched nothing.
#
# Asserted here directly rather than left to file order. Order is what
# *triggers* the leak, and it is decided by alphabet: a test that relied on
# a collision would pass or fail according to which files happen to exist,
# and would stop testing anything the moment a name sorted between them.

test_that("the shared idiom leaves no recorded calls behind", {
  # The regression guard. Before the fix this device still held the chart.
  layers <- base_r_layers(function() plot(1:5, c(2, 4, 1, 5, 3)))
  testthat::expect_length(layers, 1)

  grDevices::pdf(NULL)
  device_id <- grDevices::dev.cur()
  on.exit(
    {
      clear_base_r_device(device_id)
      grDevices::dev.off()
    },
    add = TRUE
  )

  testthat::expect_false(maidr:::has_device_calls(device_id))
})

test_that("the shared idiom clears what a previous caller left", {
  # The other half. Both guards are needed: clearing only on exit would
  # still read whatever a caller *outside* this idiom had left on the
  # device, and clearing only on entry is the defect above.
  grDevices::pdf(NULL)
  stray <- grDevices::dev.cur()
  plot(1:20, (1:20)^2)
  grDevices::dev.off()

  layers <- base_r_layers(function() barplot(c(a = 1, b = 2)))

  testthat::expect_equal(vapply(layers, function(l) l$type, ""), "bar")
  testthat::expect_equal(length(layers[[1]]$data), 2)
  testthat::expect_false(maidr:::has_device_calls(stray))
})

test_that("the idiom still reads the chart it drew", {
  # The control. A helper that cleared everything and read nothing would
  # pass both tests above.
  testthat::expect_equal(
    base_r_layer_types(function() plot(1:5, c(2, 4, 1, 5, 3))),
    "point"
  )
  testthat::expect_equal(
    base_r_layer_types(function() barplot(c(a = 1, b = 2))),
    "bar"
  )
  testthat::expect_length(
    base_r_layer_types(function() plot(1:5, 1:5, type = "n")),
    0
  )
})
