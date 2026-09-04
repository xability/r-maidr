#!/usr/bin/env Rscript
# Regenerate man/ and NAMESPACE with the roxygen2 release that generated
# what is committed.
#
# roxygen2 changes its output between minors, and `man/` is checked against
# the sources in CI with the version recorded in DESCRIPTION
# (`Config/roxygen2/version`, which roxygen2 8 writes itself). Regenerating
# with another version rewrites pages that nothing in the branch touched --
# 47 of them the last time it happened (#143) -- so this refuses to run
# with any other version and says which one to install.
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

roxygen2::roxygenise()
