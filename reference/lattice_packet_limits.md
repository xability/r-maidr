# The limits of one packet's axis

`x.limits` and `y.limits` hold one range for the whole chart, or, when
an axis' `relation` is `"free"` or `"sliced"`, one per packet.

## Usage

``` r
lattice_packet_limits(limits, packet)
```

## Arguments

- limits:

  The `x.limits` or `y.limits` field

- packet:

  The packet

## Value

The packet's limits: a numeric range, or character levels.
