# The kind of time a lattice axis is drawn in

lattice draws a `Date` axis in days since 1970 and a `POSIXct` one in
seconds, and keeps the class on the axis' limits, which is how the two
are told apart from an axis of plain numbers.

## Usage

``` r
lattice_time_kind(limits)
```

## Arguments

- limits:

  The packet's limits on the axis

## Value

`"date"`, `"datetime"`, or `NULL` for an axis that is not a time.
