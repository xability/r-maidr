# Where `plot()` of a `survfit` object cuts a curve that runs past `xmax`

At the first time beyond it, which is moved back to it.

## Usage

``` r
survfit_cut(time, xmax)
```

## Arguments

- time:

  The curve's times

- xmax:

  Where the plot cuts, or NULL

## Value

List of the kept `time` and the index `n` of the cut, or NULL
