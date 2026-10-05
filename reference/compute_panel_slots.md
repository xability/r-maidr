# Compute Panel Slot for Each Plot Group

Maps plot groups to panel slots (1-based) for a multi-panel
configuration: the panel R drew each group's plot in, as its call was
recorded – the cell R put it in, so a plot `par(mfg = )` sent out of
turn is in that panel. A plot drawn after `par(new = TRUE)`, or in a
region `par(fig = )` gave it, shares the panel of the plot before it,
and a panel [`plot.new()`](https://rdrr.io/r/graphics/frame.html) or
[`frame()`](https://rdrr.io/r/graphics/frame.html) passed over is left
empty. Groups recorded without their panel, by code that records calls
itself, take one each in drawing order:

- Groups drawn BEFORE the layout call are not part of the grid (the next
  high-level plot starts a fresh page), so they get NA.

- When more groups than panels were drawn, R flows onto a new page; only
  the final (visible) page is exported, so groups on earlier pages get
  NA.

## Usage

``` r
compute_panel_slots(plot_groups, panel_config)
```

## Arguments

- plot_groups:

  List of plot groups from group_device_calls()

- panel_config:

  Panel configuration from detect_panel_configuration()

## Value

Integer vector (one entry per group): panel slot or NA
