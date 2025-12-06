# Map visual panel position to DOM panel name

This function handles the mismatch between visual layout order
(row-major) and DOM element generation order (column-major) in gridSVG.

## Usage

``` r
map_visual_to_dom_panel(panel_info, gtable)
```

## Arguments

- panel_info:

  Panel information from layout

- gtable:

  Gtable object

## Value

Gtable panel name or NULL if not found

## Details

Visual layout (row-major): 1 2 3 4

DOM order (column-major): 1 3 2 4
