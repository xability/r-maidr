# Compute Panel Slot for Each Plot Group

Maps plot groups to panel slots (1-based, in drawing order) for a
multi-panel configuration:

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
