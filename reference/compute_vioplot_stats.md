# Compute one violin's statistics the way vioplot does

Compute one violin's statistics the way vioplot does

## Usage

``` r
compute_vioplot_stats(data, h = NULL, range = .maidr_vioplot_default_range)
```

## Arguments

- data:

  Numeric vector for one violin.

- h:

  Bandwidth, when the caller passed one. `NULL` lets `sm.density`
  choose, which is vioplot's default.

- range:

  Whisker reach in interquartile ranges, as vioplot's `range`.

## Value

A list with `min`, `q1`, `median`, `q3`, `max`, `positions`, `density`
and `bandwidth`, or `NULL` when there is nothing to describe.
