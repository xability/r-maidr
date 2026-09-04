#!/usr/bin/env Rscript
# Regenerate man/ and NAMESPACE with the roxygen2 release that generated
# what is committed, and fail on any roxygen2 warning.
#
# roxygen2 changes its output between minors, and `man/` is checked against
# the sources in CI with the version recorded in DESCRIPTION
# (`Config/roxygen2/version`, which roxygen2 8 writes itself). Regenerating
# with another version rewrites pages that nothing in the branch touched --
# 47 of them the last time it happened (#143) -- so this refuses to run
# with any other version and says which one to install.
#
# roxygen2's warnings are how it reports a block it could not attach the
# way the author meant: a block merged into the next one ("@keywords must
# be only 1 line long"), a class left without a page ("Skipping; no name
# and/or title"), a method with no block or a missing @param. The pages
# it writes in those cases are valid Rd describing the wrong thing, which
# nothing downstream can see, so the warnings are the check -- and there
# were 391 of them before #296, which is why none stood out. The count is
# now zero and this keeps it there: the `docs-drift` CI job runs this
# script, and one warning fails it.
#
#     Rscript tools/document.R

description <- read.dcf("DESCRIPTION")
pinned <- if ("Config/roxygen2/version" %in% colnames(description)) {
  trimws(description[1, "Config/roxygen2/version"])
} else {
  ""
}
if (!nzchar(pinned)) {
  stop(
    "DESCRIPTION has no Config/roxygen2/version field; ",
    "regenerate once with roxygen2 >= 8 so the pin is recorded."
  )
}

install_hint <- sprintf('    pak::pkg_install("roxygen2@%s")', pinned)

if (!requireNamespace("roxygen2", quietly = TRUE)) {
  stop("roxygen2 ", pinned, " is not installed. Install it with:\n", install_hint)
}

installed <- as.character(utils::packageVersion("roxygen2"))
if (installed != pinned) {
  stop(
    "roxygen2 ", installed, " is installed but man/ is generated with ", pinned,
    ".\nRegenerating with another version rewrites pages this change did not touch.\n",
    "Install the pinned release with:\n", install_hint
  )
}

# roxygen2 reports through cli, whose alerts are `message` conditions; with
# unicode off the ones that matter start with "x ".
options(cli.unicode = FALSE, cli.num_colors = 1)
faults <- character(0)
withCallingHandlers(
  roxygen2::roxygenise(),
  message = function(m) {
    text <- conditionMessage(m)
    if (grepl("^x ", text)) {
      faults <<- c(faults, trimws(text))
    }
  }
)

if (length(faults) > 0) {
  cat(
    "\n", length(faults), " roxygen2 warning(s) above. Each one is a page that",
    " describes something other than what its author meant, or a method",
    " left out of its class's page. Fix the comment it names; see",
    " tests/testthat/test-roxygen-orphans.R for the layouts that cause them.\n",
    sep = ""
  )
  quit(status = 1)
}
