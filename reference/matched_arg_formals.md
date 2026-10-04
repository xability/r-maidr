# The formal R matched each recorded argument to

Shared by
[`match_recorded_args()`](https://r.maidr.ai/reference/match_recorded_args.md),
which names the arguments by it, and
[`written_arg_text()`](https://r.maidr.ai/reference/written_arg_text.md),
which finds the arguments a chart is titled after.

## Usage

``` r
matched_arg_formals(function_name, target, args)
```

## Arguments

- function_name:

  Name of the recorded function

- target:

  The definition the call dispatched to, from
  [`dispatched_definition()`](https://r.maidr.ai/reference/dispatched_definition.md)

- args:

  Recorded argument list

## Value

Character vector with one entry per argument: the formal it was matched
to, or the name it carries inside `...` ("" when it has none). NULL when
the call cannot be matched.
