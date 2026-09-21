# The bundle refresh runs seconds after maidr's `npm publish`, inside the
# window where the registry still answers 404 for the new version. One
# failed `curl` there left `main` on the previous bundle until the daily
# backstop (maidr 4.9.0, 2026-09-21), so the script waits the lag out. These
# cases run it against a registry that never answers -- a closed local port
# -- from a copy of the package root, with the delay set to zero.

fetch_script <- function() {
  # tests/testthat is the working directory under R CMD check and devtools,
  # the package root under a plain `testthat::test_file()`; an installed
  # copy of the package carries no script at all and skips.
  candidates <- c(
    file.path("..", "..", ".github", "scripts", "fetch-maidr-bundle.sh"),
    file.path(".github", "scripts", "fetch-maidr-bundle.sh")
  )
  found <- candidates[file.exists(candidates)]
  testthat::skip_if(length(found) == 0, "the fetch script is only in a checkout")
  normalizePath(found[[1]])
}

package_root_copy <- function() {
  root <- tempfile("maidr-root-")
  dir.create(file.path(root, "inst", "htmlwidgets", "lib"), recursive = TRUE)
  writeLines("Package: maidr", file.path(root, "DESCRIPTION"))
  root
}

run_fetch <- function(version, attempts) {
  for (tool in c("bash", "curl", "jq")) {
    testthat::skip_if(Sys.which(tool) == "", paste("needs", tool))
  }
  script <- fetch_script()
  root <- package_root_copy()
  on.exit(unlink(root, recursive = TRUE), add = TRUE)

  old_dir <- setwd(root)
  on.exit(setwd(old_dir), add = TRUE)
  old_env <- Sys.getenv(
    c("MAIDR_NPM_REGISTRY", "MAIDR_FETCH_MAX_ATTEMPTS", "MAIDR_FETCH_RETRY_DELAY"),
    unset = NA
  )
  on.exit({
    for (name in names(old_env)) {
      if (is.na(old_env[[name]])) {
        Sys.unsetenv(name)
      } else {
        do.call(Sys.setenv, as.list(old_env[name]))
      }
    }
  }, add = TRUE)
  Sys.setenv(
    # Port 9 is discard; nothing listens on it, so every request is refused.
    MAIDR_NPM_REGISTRY = "http://127.0.0.1:9/maidr",
    MAIDR_FETCH_MAX_ATTEMPTS = as.character(attempts),
    MAIDR_FETCH_RETRY_DELAY = "0"
  )

  stderr_file <- tempfile("fetch-stderr-")
  on.exit(unlink(stderr_file), add = TRUE)
  status <- system2("bash", c(script, version), stdout = FALSE, stderr = stderr_file)
  list(
    status = status,
    stderr = readLines(stderr_file, warn = FALSE),
    installed = list.files(file.path(root, "inst", "htmlwidgets", "lib"))
  )
}

test_that("a version the registry does not know yet is retried, then given up on", {
  result <- run_fetch("4.9.0", attempts = 3)

  testthat::expect_equal(result$status, 1L)
  testthat::expect_true(any(grepl(
    "not on the registry yet (attempt 1 of 3)", result$stderr, fixed = TRUE
  )))
  testthat::expect_true(any(grepl(
    "not on the registry yet (attempt 2 of 3)", result$stderr, fixed = TRUE
  )))
  testthat::expect_true(any(grepl(
    "not on the registry after 3 attempts; giving up", result$stderr, fixed = TRUE
  )))
  # Nothing installed on the way out.
  testthat::expect_length(result$installed, 0)
})

test_that("the retry count is honoured exactly", {
  result <- run_fetch("4.9.0", attempts = 1)

  testthat::expect_equal(result$status, 1L)
  testthat::expect_false(any(grepl("not on the registry yet", result$stderr, fixed = TRUE)))
  testthat::expect_true(any(grepl(
    "not on the registry after 1 attempts; giving up", result$stderr, fixed = TRUE
  )))
})
