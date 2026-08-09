# Replay a recorded plot call with the original (unwrapped) function

Strips maidr-internal arguments and re-executes the call. When the
recorded args contain unevaluated expressions (from non-standard
evaluation, e.g. `curve(sin(x))` or `plot(y ~ x, subset = g == 1)`), the
call is rebuilt and evaluated in the environment captured at record time
so those expressions resolve exactly as they did originally.

## Usage

``` r
replay_plot_call(function_name, args, call_env = NULL)
```

## Arguments

- function_name:

  Name of the recorded function

- args:

  Recorded argument list (values and/or expressions)

- call_env:

  Environment captured when NSE arguments could not be forced at record
  time, or NULL when all args are plain values

## Value

The result of the replayed call (invisibly)
