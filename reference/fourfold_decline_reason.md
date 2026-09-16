# Which measured refusal a `fourfoldplot()` call runs into, if any

Returns NULL when the call is read, and otherwise the reason
[`warn_fourfoldplot_declined()`](https://r.maidr.ai/reference/warn_fourfoldplot_declined.md)
explains. Kept beside
[`is_two_way_table()`](https://r.maidr.ai/reference/is_two_way_table.md)
and called from the processor as well as from dispatch, so the two
cannot disagree about which calls are readable.

## Usage

``` r
fourfold_decline_reason(args)
```

## Arguments

- args:

  The arguments recorded from the
  [`fourfoldplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  call.

## Value

NULL when the counts are readable, otherwise `"std"`, `"strata"` or
`"table"`.

## Details

The three gates, in the order they are asked:

1.  **`std`.** Only `"ind.max"` and `"all.max"` are read. Measured on
    `c(tab) = 10, 40, 90, 160`, `std = "ind.max"` draws radii
    `0.25, 0.50, 0.75, 1.00` and `r^2 * max(count)` recovers
    `10, 40, 90, 160` exactly, so the wedge AREA is the count. Under the
    default `"margins"` the same table draws
    `0.632456, 0.774597, 0.774597, 0.632456` – `r1 == r4`, `r2 == r3`,
    four radii carrying one number.

2.  **Shape.** Exactly two dimensions, both of extent 2. Written as
    `length(dims) == 2L && all(dims == 2L)` and NOT as
    `identical(dims, c(2L, 2L))`, because
    [`dim()`](https://rdrr.io/r/base/dim.html) may carry the dimension
    names and [`identical()`](https://rdrr.io/r/base/identical.html)
    compares them – so the exact-comparison spelling can decline a table
    for a reason that has nothing to do with what the chart draws.
    Measured, `dim(as.table(ftable(tb)))` is
    `c(Treatment = 2L, Outcome = 2L)` on R 4.3.3 and unnamed on R 4.6.1,
    so which tables that spelling would have dropped varies by R
    version. The spelling used here does not vary, which is the point of
    it: whether the names survive is not a fact about the chart.

3.  **Values.** [`is.numeric()`](https://rdrr.io/r/base/numeric.html)
    rather than [`as.numeric()`](https://rdrr.io/r/base/numeric.html):
    measured, a logical 2x2 prints `TRUE`/`FALSE` on the page as its
    count labels while
    [`as.numeric()`](https://rdrr.io/r/base/numeric.html) would have
    announced `1`/`0` under `z = "Count"`. Finite, non-negative and
    summing above zero, because the all-zero table makes `stdize()`
    return `NaN` four times and grid emits ZERO polygon grobs for it –
    measured, `npoly = 0`.

    `all(counts >= 0)` is load-bearing, not defensive, and the obvious
    reading of it is wrong. An `NA` count does stop
    [`fourfoldplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
    under every `std`, with "missing value where TRUE/FALSE needed", so
    it never arrives. A NEGATIVE count stops only under the DEFAULT
    `std = "margins"`, with that same message. Measured on
    `c(-1, 2, 3, 4)`, `std = "ind.max"` and `std = "all.max"` both
    return normally with a "NaNs produced" warning and `npoly = 0` – and
    those are exactly the two values that get past gate 1. So a negative
    count reaches this gate whenever it is drawable at all, its counts
    are finite and sum to 8, and this clause is the one that declines
    it. `test-base-r-fourfoldplot.R` pins both halves.

A 2x2xk array fails gate 2 twice over, and is asked about first only so
the advisory can say "strata" rather than "not a 2x2 table":
[`recorded_two_way_table()`](https://r.maidr.ai/reference/recorded_two_way_table.md)
returns NULL for any input with three dimensions anyway. That includes
`2x2x1`, which draws exactly what the matrix spelling draws – a
conservative, measured loss.
