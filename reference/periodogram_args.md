# The arguments a periodogram call was made with

Both entry points take the series as their first formal with nothing
ahead of it, and a recorded call keeps evaluated arguments, so the
series is the value itself. A call whose series is not numeric is
declined rather than coerced: the arguments of a call that stopped are
recorded all the same, and coercing would announce a curve computed from
`NA`s.

## Usage

``` r
periodogram_args(layer_info)
```

## Arguments

- layer_info:

  Layer information with the recorded call.

## Value

The recorded arguments, or NULL when there is no series to read
