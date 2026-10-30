# The selector naming the outline drawn over each stacked bar

A bar layer whose bars are stacks of rects (see
`Ggplot2BarLayerProcessor$stack_rows()`) is highlighted through one
invisible rect per bar, which
[`outline_bar_stacks()`](https://r.maidr.ai/reference/outline_bar_stacks.md)
draws beside the stack's rects as a grob named `<rect grob>.bars`. Its
rects are the bars, in the order they are read, so this selector matches
one element per bar.

## Usage

``` r
bar_stack_selector(grob_name)
```

## Arguments

- grob_name:

  The name of the rect grob the stacks are drawn in.

## Value

A CSS selector string.
