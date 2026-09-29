# Drawn time coordinates as the frontend reads a time

maidr.js reads a time as milliseconds since 1970: its `date` axis format
is `new Date(value)`, and its own chart adapters carry a time axis that
way. Announced as drawn, a date would be the count of days since 1970 –
`"19723"` where the axis says January 2024.

## Usage

``` r
lattice_time_milliseconds(values, limits)
```

## Arguments

- values:

  Numeric values as lattice drew them

- limits:

  The packet's limits on the axis

## Value

The values in milliseconds on a time axis, unchanged otherwise.
