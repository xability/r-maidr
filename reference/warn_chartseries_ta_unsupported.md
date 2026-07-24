# Emit a one-time warning when quantmod::chartSeries() is called with a non-NULL \`TA\` argument (e.g. \`TA = "addVo()"\`).

The gridSVG export pipeline used to convert chartSeries' multi-panel
base graphics output into an accessible HTML SVG mis-handles the volume
sub-panel, producing rects with negative y coordinates that overlap the
date-label band. Because gridSVG is unmaintained, maidr falls back to
native (non-accessible) rendering for these calls and surfaces a
one-time advisory pointing users to the ggplot2 + tidyquant + patchwork
alternative which renders correctly via maidr's ggplot2 path.

## Usage

``` r
warn_chartseries_ta_unsupported()
```

## Value

Invisibly NULL.
