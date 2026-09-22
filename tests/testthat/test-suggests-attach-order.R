# Issue #320. Attaching vioplot or wordcloud after maidr puts the package
# ahead of `package:maidr` on the search path, so a bare `vioplot()` or
# `wordcloud()` binds to the package's own function, maidr's recording
# wrapper is never entered, and show() answers "No Base R plots detected"
# to someone who did draw a chart -- the same failure quantmod had (#97),
# which got an attach-time warning and a named error while these two got
# nothing. Measured with maidr 0.5.0 and vioplot attached after it. The
# machinery is now shared by all three packages; test-quantmod-attach-order.R
# keeps pinning quantmod through the names it always had.
#
# As there, the masking itself is search-path order fixed at library() time,
# which a running testthat process cannot re-create; a stand-in frame of the
# package's name attached ahead of maidr reproduces the state the diagnostics
# key off.

with_masking_by <- function(package, code) {
  testthat::skip_if_not("package:maidr" %in% search())
  frame <- paste0("package:", package)
  testthat::skip_if(frame %in% search())

  attach(list(), name = frame, warn.conflicts = FALSE)
  on.exit(detach(frame, character.only = TRUE), add = TRUE)

  testthat::expect_true(maidr:::package_masks_maidr(package))
  force(code)
}

startup_messages <- function(expr) {
  paste(
    utils::capture.output(force(expr), type = "message"),
    collapse = "\n"
  )
}

attach_hook_for <- function(package) {
  get(paste0(".maidr_", package, "_attach_hook"), envir = asNamespace("maidr"))
}

test_that("the wrapped Suggests packages are the three whose calls are recorded", {
  testthat::expect_identical(
    maidr:::WRAPPED_SUGGESTS,
    c(quantmod = "chartSeries", vioplot = "vioplot", wordcloud = "wordcloud")
  )
})

for (package in c("vioplot", "wordcloud")) {
  fn <- maidr:::WRAPPED_SUGGESTS[[package]]

  test_that(paste0(package, " does not mask maidr when it is not attached"), {
    testthat::skip_if(paste0("package:", package) %in% search())

    testthat::expect_false(maidr:::package_masks_maidr(package))
    testthat::expect_false(package %in% maidr:::packages_masking_maidr())
  })

  test_that(paste0(package, " attached ahead of maidr is reported as masking"), {
    with_masking_by(package, {
      testthat::expect_true(package %in% maidr:::packages_masking_maidr())
    })
  })

  test_that(paste0("the 'no plots' message names ", package, " when it masks"), {
    with_masking_by(package, {
      msg <- maidr:::no_base_r_plots_message()

      testthat::expect_match(msg, "No Base R plots detected")
      testthat::expect_match(msg, paste0("'", package, "' is attached ahead of 'maidr'"))
      testthat::expect_match(msg, paste0("maidr::", fn, "()"), fixed = TRUE)
    })
  })

  test_that(paste0("show() surfaces the ", package, " masking advice"), {
    clear_base_r_state()

    with_masking_by(package, {
      testthat::expect_error(
        maidr::show(plot = NULL),
        paste0("'", package, "' is attached ahead of 'maidr'")
      )
    })
  })

  test_that(paste0("the ", package, " attach hook reports masking"), {
    previous <- options(maidr.startup_message = TRUE)
    on.exit(options(previous), add = TRUE)

    with_masking_by(package, {
      msg <- startup_messages(attach_hook_for(package)())

      testthat::expect_match(msg, paste0("'", package, "' is attached ahead of 'maidr'"))
      testthat::expect_match(msg, paste0("maidr::", fn, "()"), fixed = TRUE)
    })
  })

  test_that(paste0("the ", package, " attach hook is silent without masking"), {
    testthat::skip_if(paste0("package:", package) %in% search())
    previous <- options(maidr.startup_message = TRUE)
    on.exit(options(previous), add = TRUE)

    testthat::expect_identical(startup_messages(attach_hook_for(package)()), "")
  })

  test_that(paste0("the ", package, " attach hook honours maidr.startup_message"), {
    previous <- options(maidr.startup_message = FALSE)
    on.exit(options(previous), add = TRUE)

    with_masking_by(package, {
      testthat::expect_identical(startup_messages(attach_hook_for(package)()), "")
    })
  })

  test_that(paste0(".onLoad registers the ", package, " attach hook and .onUnload removes it"), {
    event <- packageEvent(package, "attach")
    before <- getHook(event)
    on.exit(setHook(event, before, action = "replace"), add = TRUE)

    setHook(event, list(), action = "replace")
    maidr:::.onLoad("lib", "maidr")

    hook <- attach_hook_for(package)
    installed <- vapply(getHook(event), identical, logical(1), hook)
    testthat::expect_true(any(installed))

    maidr:::.onUnload("lib")
    remaining <- vapply(getHook(event), identical, logical(1), hook)
    testthat::expect_false(any(remaining))
  })
}

test_that(".onAttach names every package attached ahead of maidr", {
  previous <- options(maidr.startup_message = TRUE)
  on.exit(options(previous), add = TRUE)

  with_masking_by("vioplot", {
    msg <- startup_messages(maidr:::.onAttach("lib", "maidr"))

    testthat::expect_match(msg, "maidr .* loaded")
    testthat::expect_match(msg, "'vioplot' is attached ahead of 'maidr'")
  })
})
