# Convert a Panel Slot Number to a (row, column) Grid Position

Convert a Panel Slot Number to a (row, column) Grid Position

## Usage

``` r
panel_slot_position(slot, panel_config)
```

## Arguments

- slot:

  Panel slot number (1-based)

- panel_config:

  Panel configuration from detect_panel_configuration()

## Value

Integer vector c(row, col), or NULL if the slot has no cell
