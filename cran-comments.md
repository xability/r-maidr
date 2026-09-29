## Resubmission

This resubmits 0.5.0. The pretest archived the submission of 2026-09-21:
on r-devel-windows-x86_64 the check took 16 minutes, 13 of them in the
tests, and Uwe Ligges asked us to reduce the test timings. In this version:

* The 48 slowest test files skip on CRAN (a `skip_on_cran()` wrapper called
  at the top of each). They are regression suites that render charts end to
  end, and the tests of the experimental plot types; our CI still runs them
  on every platform. On CRAN the unit tests of each layer processor and of
  the public API still run.
* Charts are exported to SVG with 'svglite' instead of 'gridSVG', 3 to 7
  times faster.

On win-builder R-release, which runs on the same machines as R-devel, the
tests now take 184 s (previously 13 minutes) and the whole check 431 s.

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
* `maidr_htmlwidget()` makes 'plotly', 'highcharter' and 'echarts4r' widgets
  accessible by attaching the MAIDR JavaScript adapter for the library that
  draws them. The adapters are bundled beside maidr.js.
* Fixes for horizontal bars, faceted plots and 'patchwork' compositions,
  transformed scales, dodged bars, Base R formula interfaces and multi-panel
  layouts, and for non-ASCII labels under a C locale. Details are in NEWS.md.
* The bundled MAIDR JavaScript is updated from 3.72.1 to 4.11.0.
* A document that loads maidr.js from the CDN (with `use_cdn = TRUE`, or a
  widget, knitr or Shiny chart when the machine is online) names the latest
  published version. The package asks jsDelivr's data API, then the npm
  registry, once per R session and within 3 seconds in all; offline or
  blocked, the document names the bundled version and nothing fails.
  `show()` and `save_html()` use the bundled files by default. The tests
  replace the function that makes the request, so no check waits on the
  network.
* Optional support for a DotPad tactile display in offline documents.
  `maidr_download_dotpad_sdk()` fetches the SDK once, only when the user
  calls it, into `tools::R_user_dir("maidr", "cache")` (or a directory the
  user names). This is the only example wrapped in \dontrun, because running
  it downloads 14 MB and writes into the user's cache directory; every other
  example runs, or uses \donttest as agreed in the 0.1.1 review. The tests
  mock the download, so no check touches the network or the user's home.
* SVG export moves from 'gridSVG' to 'svglite': 'gridSVG' leaves Imports
  and 'svglite' (>= 2.1.1) joins it.
* The package now requires R >= 4.0.0 (previously 3.5.0). New Suggests:
  'hexbin', 'vioplot', 'wordcloud', 'sm', 'gridGraphics', 'pROC',
  'yardstick', 'scales', 'tibble', 'pkgload', 'plotly', 'highcharter',
  'echarts4r'.

## Bundled third-party components

The bundled MAIDR web assets in 'inst/htmlwidgets/lib/maidr-*/' are, like
this package, under GPL (>= 3). They embed React, KaTeX and other
components under MIT licenses, which are compatible with it; all are
documented in 'inst/COPYRIGHTS'. The KaTeX web-font data is stripped from
the bundled stylesheet to keep the installed size small.

## R CMD check results

0 errors | 0 warnings | 1 note

The only NOTE is the expected one from 'checking CRAN incoming feasibility':
"New maintainer: JooYoung Seo; Old maintainer(s): Niranjan Kalaiselvan",
explained above.

The installed size is about 7.3 MB (R 3.0 MB, help 1.9 MB, htmlwidgets
1.9 MB). The 'htmlwidgets' part is the bundled MAIDR engine that makes the
charts navigable, already stripped of its embedded web fonts; 'R' and 'help'
are the layer processors and their documentation for the many plot types
this release adds. The source tarball is 1.9 MB.

## Test environments

* local: Windows 11, R 4.6.1: 0 errors | 0 warnings | 1 note
* win-builder, R-release (R 4.6.1): 0 errors | 0 warnings | 1 note
* mac-builder (macOS 26.6, arm64), R 4.6.1 Patched: 0 errors | 0 warnings | 0 notes
* GitHub Actions, R-release on macOS, Windows and Ubuntu, and R-oldrel on
  Ubuntu: 0 errors | 0 warnings | 0 notes

## Downstream dependencies

There are no reverse dependencies for this package.
