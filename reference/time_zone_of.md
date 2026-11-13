# The IANA time zone a date-time is drawn in

R draws a `POSIXct` in the zone its `tzone` names, and otherwise in the
session's. A name not in
[`OlsonNames()`](https://rdrr.io/r/base/timezones.html) is passed over,
and with none left a date-time is drawn in UTC.

## Usage

``` r
time_zone_of(tz = NULL)
```

## Arguments

- tz:

  A time zone name, or NULL or "" for the session's

## Value

One name from [`OlsonNames()`](https://rdrr.io/r/base/timezones.html),
or `"UTC"`
