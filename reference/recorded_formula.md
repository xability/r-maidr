# The formula a recorded call carries, resolved

The formula is the `formula` argument, the `x` argument, or the first
positional one, whichever is found first. On the NSE path it arrives as
the unevaluated call to `~`, or – `fmla <- y ~ x; plot(fmla, ...)` – as
the name it was bound to, and either is resolved in the snapshot the
call was recorded with. Only a name or a `~` call is evaluated: an
arbitrary expression in the data slot (`plot(rnorm(10))`) is not a
formula and is not run again to find out.

## Usage

``` r
recorded_formula(args, call_env = NULL)
```

## Arguments

- args:

  Recorded argument list

- call_env:

  The environment snapshot a deferred call was recorded with, or NULL
  when every argument is a plain value.

## Value

The formula object, or NULL when the call carries none
