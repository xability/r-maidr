#!/usr/bin/env Rscript
# Build maidr for webR into a package repository.
#
#     Rscript .github/scripts/webr-build.R <repo-dir>
#
# Run it in the container webR publishes, from the package's root. The work is
# `rwasm::add_pkg()`; what this adds is the stack of calls when that fails, in
# the job's log, because its own message -- an error from deep in the package
# resolver -- names nothing of ours.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1) {
  stop("usage: webr-build.R <repo-dir>", call. = FALSE)
}

withCallingHandlers(
  rwasm::add_pkg(".", repo_dir = args[1]),
  error = function(e) {
    message("--- the error ---")
    message(conditionMessage(e))
    message("--- the calls at the error, innermost last ---")
    calls <- vapply(
      utils::tail(sys.calls(), 40),
      function(call) substr(paste(deparse(call), collapse = " "), 1, 160),
      character(1)
    )
    message(paste(calls, collapse = "\n"))
  }
)
