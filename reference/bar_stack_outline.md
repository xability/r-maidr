# One rect per stacked bar, spanning the rects it is drawn as

One rect per stacked bar, spanning the rects it is drawn as

## Usage

``` r
bar_stack_outline(rect, bars)
```

## Arguments

- rect:

  A rect grob.

- bars:

  A list of the positions of each bar's rects in `rect`.

## Value

A rect grob named `<name>.bars`, or NULL when `rect` cannot be measured
without a viewport.
