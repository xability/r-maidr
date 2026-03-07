## New submission

This is a minor release (0.2.0) adding violin plot support.

### Key changes

* Added violin plot support for 'ggplot2' (`geom_violin()`), including both
  vertical and horizontal orientations, with box-summary and KDE density layers.
* Added RDP curve simplification and SVG coordinate injection for violin KDE.
* Renamed option `maidr.enabled` to `maidr.auto_show` for clarity.
* Added violin plot examples to documentation and vignettes.

## R CMD check results

0 errors | 0 warnings | 0 notes

## Test environments

* local macOS Sequoia 15.5, R 4.5.1
* win-builder (R-devel, R-release)

## Downstream dependencies

There are no reverse dependencies for this package.
