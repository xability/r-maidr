# Say why a fourfoldplot() call is falling back to a picture

The generic "Plot contains unsupported elements" the fallback already
emits is true and uninformative: it does not tell an author that the
same chart with `std = "ind.max"` would have been read. This says which
of the three measured refusals applied.

## Usage

``` r
warn_fourfoldplot_declined(reason)
```

## Arguments

- reason:

  One of `"std"`, `"strata"` or `"table"`.

## Value

Invisibly NULL.

## Details

The three reasons, all measured on R 4.3.3:

- `"std"` – the caller's `std` resolved to `"margins"`, which is
  [`graphics::fourfoldplot`](https://rdrr.io/r/graphics/fourfoldplot.html)'s
  own default. Under it the four radii are `sqrt(c(u, 1 - u, 1 - u, u))`
  with `u = sqrt(or) / (1 + sqrt(or))`: one number, the odds ratio,
  drawn four times. Measured, a table and the same table times three
  give bit-identical radii, so counts announced there would name numbers
  the chart did not draw.

- `"strata"` – a 2x2xk array.
  [`fourfoldplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  draws k panels into one figure region with repeated
  [`plot.window()`](https://rdrr.io/r/graphics/plot.window.html) calls
  rather than `par(mfrow)`, so measured on `UCBAdmissions` all 78
  polygon grobs are named `graphics-plot-1-*` and no helper here slices
  them per panel. The MESSAGE names the third dimension rather than the
  k panels, because "k panels share one region" is false for the one
  array shape that has no strata to confuse: measured,
  `array(c(10, 40, 90, 160), c(2, 2, 1))` under `ind.max` draws a single
  panel of exactly 13 polygon grobs – the count `wedge_names()` accepts
  – and is declined anyway, because
  [`recorded_two_way_table()`](https://r.maidr.ai/reference/recorded_two_way_table.md)
  refuses three dimensions. Telling that author about panels they do not
  have would send them looking for the wrong thing; the matrix spelling
  is the fix and the message says so.

- `"table"` – a two-way argument that is not a 2x2 table of finite
  non-negative numbers summing above zero. Measured, the all-zero table
  draws ZERO polygon grobs, and a logical matrix prints `TRUE`/`FALSE`
  on the page while
  [`as.numeric()`](https://rdrr.io/r/base/numeric.html) would announce
  `1`/`0`.

Once per reason per session, not once per plot: `detect_layer_type()` is
called up to five times for one accepted layer
(`base_r_plot_orchestrator.R` lines 145, 163, 195, 499, 653) and once
per declined one, so an unguarded warning would repeat. The cost is that
an author who draws two default-`std` charts hears the explanation once
– the same trade
[`warn_chartseries_ta_unsupported()`](https://r.maidr.ai/reference/warn_chartseries_ta_unsupported.md)
makes above.

The message deliberately avoids the substring "unsupported elements":
`tests/testthat/test-base-r-unrecorded-calls.R` greps for exactly that
to decide whether the *fallback* warning arrived, and a second warning
carrying it would make that assertion pass for the wrong reason.
