#!/usr/bin/env Rscript
#' Update Bundled MAIDR Assets
#'
#' This script downloads the latest (or specified) version of MAIDR JavaScript
#' and CSS files from npm/CDN and updates the local bundled copies.
#'
#' Usage:
#'   Rscript tools/update-maidr-assets.R           # Uses latest version
#'   Rscript tools/update-maidr-assets.R 3.50.0    # Uses specific version
#'
#' After running this script, you must:
#' 1. Update MAIDR_VERSION in R/html_dependencies.R
#' 2. Update version in inst/htmlwidgets/maidr.yaml
#' 3. Run R CMD check to verify everything works
#' 4. Commit the changes

# Parse command line arguments
args <- commandArgs(trailingOnly = TRUE)

# Get version to download
get_latest_version <- function() {
  url <- "https://registry.npmjs.org/maidr/latest"
  tryCatch({
    response <- jsonlite::fromJSON(url)
    response$version

  }, error = function(e) {
    stop("Failed to fetch latest version from npm: ", e$message)
  })
}

version <- if (length(args) > 0) args[1] else get_latest_version()
cat("Updating MAIDR assets to version:", version, "\n\n")

# Define paths
pkg_root <- rprojroot::find_package_root_file()
lib_dir <- file.path(pkg_root, "inst", "htmlwidgets", "lib", paste0("maidr-", version))
old_lib_dirs <- list.dirs(
  file.path(pkg_root, "inst", "htmlwidgets", "lib"),
  full.names = TRUE,
  recursive = FALSE
)
old_lib_dirs <- old_lib_dirs[grepl("^maidr-", basename(old_lib_dirs))]

# CDN base URL
cdn_base <- sprintf("https://cdn.jsdelivr.net/npm/maidr@%s/dist", version)

# Files to download
files <- c(
  "maidr.js",
  "maidr.css"
)

# Create new directory
if (!dir.exists(lib_dir)) {
  dir.create(lib_dir, recursive = TRUE)
  cat("Created directory:", lib_dir, "\n")
}

# Download files
cat("\nDownloading files from CDN...\n")
for (file in files) {
  url <- paste0(cdn_base, "/", file)
  dest <- file.path(lib_dir, file)

  cat("  Downloading", file, "...")
  tryCatch({
    download.file(url, dest, mode = "wb", quiet = TRUE)
    file_size <- file.info(dest)$size
    cat(" OK (", format(file_size, big.mark = ","), " bytes)\n", sep = "")
  }, error = function(e) {
    cat(" FAILED\n")
    warning("Failed to download ", file, ": ", e$message)
  })
}

# Verify downloads
cat("\nVerifying downloads...\n")
all_ok <- TRUE
for (file in files) {
  dest <- file.path(lib_dir, file)
  if (file.exists(dest) && file.info(dest)$size > 100) {
    cat("  ", file, ": OK\n")
  } else {
    cat("  ", file, ": MISSING or EMPTY\n")
    all_ok <- FALSE
  }
}

if (!all_ok) {
  stop("Some files failed to download. Please check and retry.")
}

# Remove old version directories
if (length(old_lib_dirs) > 0) {
  cat("\nRemoving old version directories...\n")
  for (old_dir in old_lib_dirs) {
    if (old_dir != lib_dir) {
      cat("  Removing:", basename(old_dir), "\n")
      unlink(old_dir, recursive = TRUE)
    }
  }
}

# Print next steps
cat("\n")
cat("========================================\n")
cat("SUCCESS! MAIDR assets updated to version", version, "\n")
cat("========================================\n")
cat("\n")
cat("Next steps:\n")
cat("1. Update MAIDR_VERSION in R/html_dependencies.R:\n")
cat("   MAIDR_VERSION <- \"", version, "\"\n", sep = "")
cat("\n")
cat("2. Update version and path in inst/htmlwidgets/maidr.yaml:\n")
cat("   version: ", version, "\n", sep = "")
cat("   src: htmlwidgets/lib/maidr-", version, "\n", sep = "")
cat("\n")
cat("3. Run R CMD check:\n")
cat("   devtools::check()\n")
cat("\n")
cat("4. Commit the changes:\n")
cat("   git add -A && git commit -m \"chore: update MAIDR to ", version, "\"\n", sep = "")
cat("\n")
