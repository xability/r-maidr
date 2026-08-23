# Whether a Base R `type` argument draws spikes

`type = "h"` draws a vertical line from the baseline to each value –
"histogram-like" in
[`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md)'s own
wording – and joins nothing to anything. Read as a `lollipop` layer,
which the core builds on `BarTrace`: one value per position, with no
claim about the space between two of them.

## Usage

``` r
is_spike_plot_type(plot_type)
```

## Arguments

- plot_type:

  The `type` argument recorded from the plot call (may be NULL when the
  caller did not pass one).

## Value

`TRUE` when `plot_type` is `"h"`, otherwise `FALSE`.

## Details

Case-sensitive, like the step test beside it:
[`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) has no
`"H"`.
