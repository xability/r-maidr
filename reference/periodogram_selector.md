# The grob a periodogram's curve was drawn as, in its own panel

gridGraphics numbers panels in draw order, so under `par(mfrow = )` the
second chart's curve is `graphics-plot-2-lines-1`. The panel index is
the one the orchestrator assigned the layer; a layer without one is the
first panel.

## Usage

``` r
periodogram_selector(layer_info, grob)
```

## Arguments

- layer_info:

  Layer information carrying `group_index` or `index`

- grob:

  The grob name gridGraphics wrote: `"lines"` or `"step"`

## Value

A CSS selector for the curve's `g` element
