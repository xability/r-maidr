# The grobs drawn inside a chart's panels, classified

A grob counts as inside a panel when it was drawn in the panel's data
viewport, `<prefix>.panel.<column>.<row>.vp`, which is where lattice
runs the panel function – and any viewport the panel function pushes
there. Axes, ticks, the border and the strips are drawn in other
viewports.

## Usage

``` r
lattice_panel_grobs(listing, plot, adapter, prefix = LATTICE_PREFIX)
```

## Arguments

- listing:

  The grob listing of the drawn chart

- plot:

  The trellis object that was drawn

- adapter:

  The lattice adapter

- prefix:

  The grob-name prefix

## Value

A data frame with one row per grob drawn in a panel, in drawing order:
`name`, `what`, `group`, `column`, `row` and `role`.
