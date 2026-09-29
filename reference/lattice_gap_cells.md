# The empty layout cells that are kept as empty subplots

The frontend's subplot rows are left-packed: the k-th subplot of a row
is the k-th cell from the left, and Up and Down keep that k. A cell
lattice left empty at the end of its row can be left out; one with a
panel to its right in its row cannot, or that panel would be counted a
column to the left, and Up and Down would land on the panel beside the
one lattice drew above or below. Such a cell is kept, as a subplot with
no layers. A column no panel is drawn in is left out of every row, as a
row no panel is drawn in is.

## Usage

``` r
lattice_gap_cells(packets)
```

## Arguments

- packets:

  The packet matrix, `[row, column]`, 0 for an empty cell

## Value

A logical matrix the shape of `packets`, `TRUE` for an empty cell kept
as an empty subplot.
