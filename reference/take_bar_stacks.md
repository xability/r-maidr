# Take the stacked bars a chart's layers declare

A layer whose bars are stacks of rects carries `.bar_stacks` – the name
of its rect grob and the positions of each bar's rects in it – for
[`outline_bar_stacks()`](https://r.maidr.ai/reference/outline_bar_stacks.md).
The field is removed here: it describes the drawing, not the data, and
must not reach the emitted JSON.

## Usage

``` r
take_bar_stacks(maidr_data)
```

## Arguments

- maidr_data:

  The maidr-data structure.

## Value

A list: `maidr_data` without the fields, and `stacks`, one entry per
layer that had one.
