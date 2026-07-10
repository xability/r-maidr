## Submission

This is an update of the CRAN package 'maidr', from 0.3.0 to 0.4.0.

## Major changes in this version

* Added accessible candlestick (OHLC) chart support for both 'ggplot2' (via
  'tidyquant::geom_candlestick()', with optional 'geom_ma()' moving-average
  overlays and a 'patchwork' volume sub-panel) and Base R (via
  'quantmod::chartSeries()', OHLC-only).
* Updated the bundled MAIDR JavaScript/CSS assets to v3.69.0.
* Reduced the installed package size to under 5 MB: the embedded KaTeX
  web-font data in the bundled 'maidr.css' is stripped (KaTeX math glyphs
  fall back to system fonts; there is no effect on the accessibility output).
* Added an '.onUnload' that removes the 'quantmod' package-load hook installed
  in '.onLoad', so the package unloads cleanly.

## Bundled third-party components

The bundled MAIDR web assets in 'inst/htmlwidgets/lib/maidr-*/' embed React,
KaTeX, D3, and Tone.js, all under permissive MIT / ISC licenses compatible
with this package's GPL (>= 3) license. These are documented in
'inst/COPYRIGHTS'.

## R CMD check results

Local: macOS, R 4.5.1, `R CMD check --as-cran`:

    0 errors | 0 warnings | 1 note

The single local NOTE ("checking HTML version of manual ... 'tidy' doesn't
look like recent enough HTML Tidy") reflects an outdated local HTML Tidy tool
and does not occur on CRAN's check infrastructure.

The win-builder CRAN-incoming-feasibility check flags one possibly misspelled
word in DESCRIPTION: "OHLC". This is a standard financial abbreviation
(Open-High-Low-Close) used to describe candlestick charts, and is not a
misspelling.

## Test environments

* local: macOS, R 4.5.1
* win-builder (R-devel and R-release): <add results before submitting>
* mac-builder (R-release): <add results before submitting>

## Downstream dependencies

There are no reverse dependencies for this package.
