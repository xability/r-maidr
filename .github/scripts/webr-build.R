#!/usr/bin/env Rscript
# Build maidr for webR into a package repository.
#
#     Rscript .github/scripts/webr-build.R <repo-dir>
#
# Run it in the container webR publishes, from the package's root. The work is
# `rwasm::add_pkg()`. `remotes = NULL` skips its look-up of the packages webR
# patches: by default it resolves every reference in a list the image carries,
# over the network, before building anything, and on a runner one of them failed
# with an error from deep in the package resolver, `nrow(out)` must equal `1`.
# maidr is not in that list and needs none of them. When something else fails,
# the stack of calls goes to the job's log, because the message alone names
# nothing of ours.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1) {
  stop("usage: webr-build.R <repo-dir>", call. = FALSE)
}

withCallingHandlers(
  rwasm::add_pkg(".", repo_dir = args[1], remotes = NULL),
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
