#!/usr/bin/env Rscript
#' Update Bundled MAIDR Assets
#'
#' Thin wrapper around `.github/scripts/fetch-maidr-bundle.sh`, which is the
#' single source of truth for resolving, downloading, verifying, and
#' installing the bundled MAIDR JavaScript and CSS files. The same script is
#' used by the scheduled refresh workflow (`update-maidr-bundle.yml`), so the
#' download + integrity-check logic cannot drift between CI and local use.
#'
#' The shell script verifies the npm tarball against the integrity hash
#' published in the npm registry metadata, installs the assets into
#' `inst/htmlwidgets/lib/maidr-<version>/`, removes stale bundle
#' directories, and updates the version references in
#' `R/html_dependencies.R` and `inst/htmlwidgets/maidr.yaml`.
#'
#' Requires: bash, curl, jq, openssl, tar (available on macOS/Linux and on
#' Windows via Git Bash).
#'
#' Usage:
#'   Rscript tools/update-maidr-assets.R           # Uses latest version
#'   Rscript tools/update-maidr-assets.R 3.50.0    # Uses specific version
#'
#' After running this script, you must:
#' 1. Run R CMD check to verify everything works
#' 2. Commit the changes

args <- commandArgs(trailingOnly = TRUE)

pkg_root <- rprojroot::find_package_root_file()
script <- file.path(pkg_root, ".github", "scripts", "fetch-maidr-bundle.sh")
if (!file.exists(script)) {
  stop("Shared fetch script not found: ", script)
}

# The script must run from the package root and prints the installed version
# as its final stdout line; everything else goes to stderr.
old_wd <- setwd(pkg_root)
on.exit(setwd(old_wd), add = TRUE)
status <- system2("bash", c(shQuote(script), shQuote(args)))
if (status != 0) {
  stop("fetch-maidr-bundle.sh failed with exit status ", status)
}

cat("\n")
cat("Next steps:\n")
cat("1. Run R CMD check:\n")
cat("   devtools::check()\n")
cat("\n")
cat("2. Commit the changes:\n")
cat('   git add -A && git commit -m "chore: update MAIDR bundle"\n')
