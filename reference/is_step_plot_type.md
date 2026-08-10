# Does a Base R `type` argument request a stairstep?

[`graphics::plot()`](https://rdrr.io/r/graphics/plot.default.html) and
[`graphics::lines()`](https://rdrr.io/r/graphics/lines.html) draw
stairsteps for `type = "s"` (horizontal segment first) and `type = "S"`
(vertical segment first). The comparison is case-sensitive because those
two letters mean different things.

## Usage

``` r
is_step_plot_type(plot_type)
```

## Arguments

- plot_type:

  The `type` argument recorded from the plot call (may be NULL when the
  caller did not pass one).

## Value

`TRUE` when `plot_type` is `"s"` or `"S"`, otherwise `FALSE`.
