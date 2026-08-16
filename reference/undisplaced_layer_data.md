# The positions a layer's points would have without its jitter

Rebuilds `plot` with the one layer's position adjustment replaced by
[`position_identity()`](https://ggplot2.tidyverse.org/reference/position_identity.html)
and returns that layer's built data.

## Usage

``` r
undisplaced_layer_data(plot, layer_index)
```

## Arguments

- plot:

  The ggplot2 object.

- layer_index:

  Index of the layer to undisplace.

## Value

A data frame of the layer's undisplaced built data, or `NULL` when the
rebuild fails or does not line up row for row with the original.

## Details

The replacement is a fresh `ggproto` child rather than an assignment to
the layer's own `position` field. ggplot2 `Layer` objects are `ggproto`
and have **reference** semantics, so `plot$layers[[i]]$position <- ...`
would alter the caller's plot – the object they still hold and may draw
again. A child shadows the field instead, leaving the parent untouched;
asserted in the tests rather than left as a claim.
