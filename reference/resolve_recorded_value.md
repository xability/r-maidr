# A recorded argument as a value

A recorded argument as a value

## Usage

``` r
resolve_recorded_value(value, call_env = NULL)
```

## Arguments

- value:

  A recorded argument, a plain value or an expression

- call_env:

  The snapshot to evaluate an expression in, or NULL

## Value

The value, or NULL when an expression has nowhere to be evaluated or
fails there
