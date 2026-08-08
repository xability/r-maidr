# Regression tests for issue #59: an NSE call recorded for later replay must
# carry the values its free variables had when the call was made.
#
# When an argument cannot be forced at record time, the wrapper stores the
# unevaluated expressions plus an environment, and the renderer re-evaluates
# them against that environment. Storing the caller's FRAME made every
# iteration of a loop replay with the LAST iteration's values, because R
# reuses one frame for the whole loop:
#
#   par(mfrow = c(1, 2))
#   for (g in c("a", "b")) plot(y ~ x, data = d, subset = grp == g)
#
# Both panels drew `grp == "b"`, with no error and no warning.

setup_clean <- function() {
  maidr:::clear_all_device_storage()
}

# Replay a recorded call the way the renderer does and report the axis limits
# it established. Those limits expose the data the call actually drew.
replayed_usr <- function(calls, function_name) {
  recorded <- Filter(function(x) identical(x$function_name, function_name), calls)
  grDevices::pdf(tempfile(fileext = ".pdf"))
  on.exit(grDevices::dev.off(), add = TRUE)

  lapply(recorded, function(entry) {
    maidr:::replay_plot_call(entry$function_name, entry$args, entry$call_env)
    graphics::par("usr")
  })
}

# Base R extends each axis by 4% of the data range on both sides, so the
# expected limits follow from the data alone -- no reference plot needed.
padded_range <- function(values) {
  limits <- range(values)
  range(limits + c(-1, 1) * 0.04 * diff(limits))
}

test_that("each loop iteration replays with its own value of the loop variable", {
  setup_clean()
  on.exit(setup_clean(), add = TRUE)

  d <- data.frame(x = 1:20, y = (1:20)^1.5, grp = rep(c("a", "b"), each = 10))
  old_par <- graphics::par(mfrow = c(1, 2))
  on.exit(graphics::par(old_par), add = TRUE)

  for (g in c("a", "b")) plot(y ~ x, data = d, subset = grp == g)

  panels <- replayed_usr(maidr:::get_device_calls(grDevices::dev.cur()), "plot")
  testthat::expect_length(panels, 2)

  # The two panels must differ at all -- they were pixel-identical before.
  testthat::expect_false(isTRUE(all.equal(panels[[1]], panels[[2]])))

  # And each must carry ITS OWN subset, computed here straight from `d`.
  for (i in seq_along(c("a", "b"))) {
    expected <- d[d$grp == c("a", "b")[i], ]
    testthat::expect_equal(panels[[i]][1:2], padded_range(expected$x))
    testthat::expect_equal(panels[[i]][3:4], padded_range(expected$y))
  }
})

test_that("a boxplot recorded in a loop keeps its own subset", {
  setup_clean()
  on.exit(setup_clean(), add = TRUE)

  d <- data.frame(y = c(1:20, 101:120), grp = rep(c("a", "b"), each = 20))
  old_par <- graphics::par(mfrow = c(1, 2))
  on.exit(graphics::par(old_par), add = TRUE)

  for (g in c("a", "b")) boxplot(y ~ grp, data = d, subset = grp == g)

  panels <- replayed_usr(maidr:::get_device_calls(grDevices::dev.cur()), "boxplot")
  testthat::expect_length(panels, 2)

  # Panel 1 spans 1..20, panel 2 spans 101..120; overlapping them would mean
  # both replayed the same subset.
  testthat::expect_lt(panels[[1]][4], panels[[2]][3])
})

test_that("curve() recorded in a loop keeps its own free variables", {
  setup_clean()
  on.exit(setup_clean(), add = TRUE)

  old_par <- graphics::par(mfrow = c(1, 2))
  on.exit(graphics::par(old_par), add = TRUE)

  # curve() goes through the always-deferred NSE wrapper, so it exercises the
  # snapshot on a path where nothing is ever forced at record time. It also
  # resolves its expression relative to the CALLER's frame, which for the
  # script in the issue is the global environment -- the very frame the loop
  # rebinds -- so the loop has to run there to reproduce the report.
  on.exit(suppressWarnings(rm("maidr_test_k", envir = globalenv())), add = TRUE)
  eval(
    quote(for (maidr_test_k in c(1, 5)) {
      curve(maidr_test_k * x^2, from = 0, to = 2)
    }),
    globalenv()
  )

  panels <- replayed_usr(maidr:::get_device_calls(grDevices::dev.cur()), "curve")
  testthat::expect_length(panels, 2)

  testthat::expect_equal(panels[[1]][3:4], padded_range(c(0, 4)))
  testthat::expect_equal(panels[[2]][3:4], padded_range(c(0, 20)))
})

test_that("a deferred call records an environment, an ordinary call does not", {
  setup_clean()
  on.exit(setup_clean(), add = TRUE)

  d <- data.frame(x = 1:20, y = (1:20)^1.5, grp = rep(c("a", "b"), each = 10))
  keep <- "a"
  plot(y ~ x, data = d, subset = grp == keep)
  plot(d$x, d$y)

  calls <- Filter(
    function(x) identical(x$function_name, "plot"),
    maidr:::get_device_calls(grDevices::dev.cur())
  )
  testthat::expect_length(calls, 2)

  # `subset = grp == keep` cannot be forced in the wrapper's frame, so the
  # expressions and an environment are recorded.
  testthat::expect_true(is.environment(calls[[1]]$call_env))
  testthat::expect_true(all(vapply(calls[[1]]$args, is.language, logical(1))))

  # A call whose arguments are plain values keeps the value fast path, which
  # never needs an environment and so cannot be affected by this bug.
  testthat::expect_null(calls[[2]]$call_env)
})

test_that("snapshot_call_env freezes only the names the expressions reference", {
  caller <- new.env(parent = emptyenv())
  assign("wanted", 1, envir = caller)
  assign("untouched", "original", envir = caller)

  snapshot <- maidr:::snapshot_call_env(list(quote(wanted + 1)), caller)

  testthat::expect_identical(parent.env(snapshot), caller)
  testthat::expect_true(exists("wanted", envir = snapshot, inherits = FALSE))
  testthat::expect_false(exists("untouched", envir = snapshot, inherits = FALSE))

  # Rebinding in the caller must not reach the snapshotted name ...
  assign("wanted", 999, envir = caller)
  testthat::expect_equal(get("wanted", envir = snapshot), 1)

  # ... while everything else still resolves through the caller's frame.
  assign("untouched", "changed", envir = caller)
  testthat::expect_equal(get("untouched", envir = snapshot), "changed")
})

test_that("snapshot_call_env reaches names bound in enclosing scopes", {
  outer <- new.env(parent = emptyenv())
  assign("g", "a", envir = outer)
  inner <- new.env(parent = outer)

  snapshot <- maidr:::snapshot_call_env(list(quote(grp == g)), inner)

  assign("g", "b", envir = outer)
  testthat::expect_equal(get("g", envir = snapshot), "a")
})

test_that("snapshot_call_env leaves active bindings to the caller", {
  caller <- new.env(parent = emptyenv())
  reads <- 0
  makeActiveBinding("live", function() {
    reads <<- reads + 1
    reads
  }, caller)

  snapshot <- maidr:::snapshot_call_env(list(quote(live > 0)), caller)

  # Reading an active binding is a side effect, and re-reading it later is
  # the point of declaring it active, so it must not be copied or forced.
  testthat::expect_equal(reads, 0)
  testthat::expect_false(exists("live", envir = snapshot, inherits = FALSE))
  testthat::expect_true(exists("live", envir = snapshot))
})

test_that("snapshot_call_env skips names that are bound nowhere", {
  caller <- new.env(parent = emptyenv())

  snapshot <- maidr:::snapshot_call_env(
    list(quote(y ~ x), quote(nothing_here)),
    caller
  )

  testthat::expect_length(ls(snapshot, all.names = TRUE), 0)
})

test_that("snapshot_call_env ignores dots and plain values", {
  caller <- new.env(parent = emptyenv())
  assign("real", 7, envir = caller)

  snapshot <- maidr:::snapshot_call_env(list(3.5, "text", quote(f(real, ...))), caller)

  # `f` is a call head, not a variable, and `...` is not a binding to copy.
  testthat::expect_equal(ls(snapshot, all.names = TRUE), "real")
})
