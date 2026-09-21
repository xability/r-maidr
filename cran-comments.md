## Submission

This is an update of the CRAN package 'maidr', from 0.4.0 to 0.5.0.

## Maintainer change

The maintainer changes from Niranjan Kalaiselvan <nk46@illinois.edu> to
JooYoung Seo <jseo1005@illinois.edu>, the package's copyright holder and an
author since its first release. The outgoing maintainer confirmed the
transfer in writing to CRAN-submissions@R-project.org on 2026-07-11
(subject "maidr - maintainer change to JooYoung Seo"), and Uwe Ligges
acknowledged it the same day.

## Major changes in this version

* Many more plot types are read as interactive, navigable charts. For
  'ggplot2': pie, step, 100% stacked bar, area, error bar, ribbon, contour,
  gantt, hex, raster, dotplot, polygon, rug and ROC curve layers. For Base R:
  pie(), step plots, 100% stacked barplot(), vioplot(), contour(), curve(),
  lollipop and dotchart(), mosaicplot(), spineplot(), cdplot(), assocplot(),
  fourfoldplot(), stripchart(), qqnorm()/qqplot()/qqline(), bxp(), pairs(),
  acf()/pacf()/ccf(), interaction.plot(), monthplot(), lag.plot(), stars(),
  termplot(), spectrum(), cpgram(), biplot() and word clouds.
* Fixes for horizontal bars, faceted plots and 'patchwork' compositions,
  transformed scales, dodged bars, Base R formula interfaces and multi-panel
  layouts, and for non-ASCII labels under a C locale. Details are in NEWS.md.
* The bundled MAIDR JavaScript is updated from 3.72.1 to 4.9.0.
* Optional support for a DotPad tactile display in offline documents.
  `maidr_download_dotpad_sdk()` fetches the SDK once, only when the user
  calls it, into `tools::R_user_dir("maidr", "cache")` (or a directory the
  user names). This is the only example wrapped in \dontrun, because running
  it downloads 14 MB and writes into the user's cache directory; every other
  example runs, or uses \donttest as agreed in the 0.1.1 review. The tests
  mock the download, so no check touches the network or the user's home.
* The package now requires R >= 4.0.0 (previously 3.5.0). New Suggests:
  'hexbin', 'vioplot', 'wordcloud', 'sm', 'gridGraphics', 'pROC',
  'yardstick', 'scales', 'tibble', 'pkgload'.

## Bundled third-party components

The bundled MAIDR web assets in 'inst/htmlwidgets/lib/maidr-*/' embed React
and KaTeX, under permissive MIT licenses compatible with this package's
GPL (>= 3) license. They are documented in 'inst/COPYRIGHTS'. The KaTeX
web-font data is stripped from the bundled stylesheet to keep the installed
size small.

## R CMD check results

0 errors | 0 warnings | 1 note

The only NOTE is the expected one from 'checking CRAN incoming feasibility':
"New maintainer: JooYoung Seo; Old maintainer(s): Niranjan Kalaiselvan",
explained above.

The installed size is about 7 MB (R 3 MB, help 1.7 MB, htmlwidgets 1.7 MB).
The 'htmlwidgets' part is the bundled MAIDR engine that makes the charts
navigable, already stripped of its embedded web fonts; 'R' and 'help' are
the layer processors and their documentation for the many plot types this
release adds. The source tarball is 1.6 MB.

## Test environments

* local: Windows 11, R 4.6.1: 0 errors | 0 warnings | 1 note
* win-builder, R-devel (r90574): 0 errors | 0 warnings | 1 note
* win-builder, R-release (R 4.6.1): 0 errors | 0 warnings | 1 note
* mac-builder (macOS 26.6, arm64), R 4.6.1 Patched: 0 errors | 0 warnings | 0 notes

## Downstream dependencies

There are no reverse dependencies for this package.
