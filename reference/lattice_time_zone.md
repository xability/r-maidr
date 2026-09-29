# The time zone a time axis is announced in

A date is a calendar day, which
[`lattice_time_milliseconds()`](https://r.maidr.ai/reference/lattice_time_milliseconds.md)
puts at midnight UTC, so it is announced in UTC. A date-time axis is
labelled by lattice in the time zone its limits carry and otherwise in
the session's own – the `TZ` environment variable when it is set, which
[`Sys.timezone()`](https://rdrr.io/r/base/timezones.html) does not
report, and the system's zone when not – and is announced in the same
one. `Intl.DateTimeFormat` throws on a zone it does not know, which
would take the announcement out rather than the zone, so only a zone in
the Olson database is passed on.

## Usage

``` r
lattice_time_zone(limits)
```

## Arguments

- limits:

  The packet's limits on the axis

## Value

An IANA time zone name.
