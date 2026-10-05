# Resolve the definition R dispatched a recorded call to

`hist` is the motivating case from \#98: the generic is `hist(x, ...)`,
so matching against it leaves a positional `breaks` inside the dots. The
method carries the formals that matter, and it is picked as
[`UseMethod()`](https://rdrr.io/r/base/UseMethod.html) picked it when
the call ran: by the class of the argument matched to the generic's
first formal, or, when no argument is, of the first argument written.

## Usage

``` r
dispatched_definition(function_name, definition, args)
```

## Arguments

- function_name:

  Name of the recorded function

- definition:

  The original (unwrapped) function that was called

- args:

  Recorded argument list of evaluated values

## Value

A function to match against, or NULL when none can be resolved
