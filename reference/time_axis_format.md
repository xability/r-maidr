# The format a time axis's numbers are drawn with

A histogram over dates or times carries its axis's own numbers: R's
`Date` counts days since 1970-01-01, `POSIXct` seconds since then, and
`hms` seconds since midnight. Read as numbers, a bin of a histogram of
dates was "d is 20,457.5 through 20,464.5". The format draws each number
as the date, date-time or clock time it stands for, as an ISO date, a
date and time in the axis's time zone, or hh:mm:ss. Its `unit` says what
one of the numbers counts, so a bin's width reads as a span of time, "1
week", in a maidr.js that reads it (xability/maidr#1695); an older one
ignores it.

## Usage

``` r
time_axis_format(kind, tz = "UTC")
```

## Arguments

- kind:

  `"date"`, `"datetime"` or `"time"`

- tz:

  The IANA time zone a date-time is drawn in
  ([`time_zone_of()`](https://r.maidr.ai/reference/time_zone_of.md))

## Value

An AxisFormat holding a `function` and a `unit`, or NULL for any other
kind
