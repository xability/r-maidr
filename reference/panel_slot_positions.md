# Convert a Panel Slot Number to its (row, column) Grid Positions

A \`layout()\` matrix may name the same panel in several cells; R draws
that panel once, spanning all of them. Returning every matching cell (in
reading order) lets the caller advertise the panel in each cell it
actually covers, so a spanned region is not mistaken for empty space. An
\`mfrow\`/\`mfcol\` grid cannot span, so it always yields exactly one
cell.

## Usage

``` r
panel_slot_positions(slot, panel_config)
```

## Arguments

- slot:

  Panel slot number (1-based)

- panel_config:

  Panel configuration from detect_panel_configuration()

## Value

List of integer vectors c(row, col); empty list if the slot occupies no
cell
