# Clip chartSeries' lower-panel rects to their plot region

[`quantmod::chartSeries()`](https://rdrr.io/pkg/quantmod/man/chartSeries.html)
draws its volume panel (`addVo()`) as bars from zero, in a panel whose y
range starts near the smallest volume, and leaves R to clip them to the
plot region, as base graphics do by default. The tree
[`gridGraphics::grid.echo()`](https://rdrr.io/pkg/gridGraphics/man/grid.echo.html)
rebuilds from that drawing places those bars in `graphics-plot-<N>`,
which does not clip, rather than in the `graphics-plot-<N>-clip`
viewport it builds beside it, so every bar ran on past the panel's lower
border into the date labels.

## Usage

``` r
clip_chartseries_panel_rects(grob)
```

## Arguments

- grob:

  A grob, gTree, gList, or gtable (or NULL)

## Value

The same tree with lower-panel rects in their clipping viewport

## Details

Each rect of a panel below the first is moved into that panel's `-clip`
viewport, when the tree has one. The rect keeps its name, so its element
id, and the selectors built from it, are unchanged; only the viewport
groups around it are named after the clipping viewport, and the export
clips them as R clipped the drawing. The price panel is left alone: its
candles lie within its range.
