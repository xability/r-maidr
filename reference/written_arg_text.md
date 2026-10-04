# The text of each recorded argument a chart names a title after

Many Base R charts title themselves after how an argument was written:
`hist(mtcars$mpg)` writes "mtcars\$mpg" under its x axis and "Histogram
of mtcars\$mpg" above it, from `deparse1(substitute(x))`. The recorded
call keeps the argument's value, and a replay of the value hands
[`substitute()`](https://rdrr.io/r/base/substitute.html) the numbers
themselves, so maidr's chart was titled with the data printed end to
end.

## Usage

``` r
written_arg_text(function_name, target, args, written)
```

## Arguments

- function_name:

  Name of the recorded function

- target:

  The definition the call dispatched to, from
  [`dispatched_definition()`](https://r.maidr.ai/reference/dispatched_definition.md)

- args:

  Recorded argument list of evaluated values, as
  [`match_recorded_args()`](https://r.maidr.ai/reference/match_recorded_args.md)
  names it

- written:

  The expressions the arguments were written as, in the same order:
  `as.list(substitute(list(...)))[-1L]` in the wrapper

## Value

Character vector with one entry per argument: the text to replay it
under, or NA to replay its value. Named, when any entry has text, by the
formal each argument was matched to, which
[`written_arg()`](https://r.maidr.ai/reference/written_arg.md) reads.

## Details

What is kept here is the text, for the arguments the dispatched function
reads with [`substitute()`](https://rdrr.io/r/base/substitute.html) and
for no other:
[`replay_plot_call()`](https://r.maidr.ai/reference/replay_plot_call.md)
passes the value under a name spelled that way, and an argument a
function evaluates as an expression elsewhere –
[`monthplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) does so
with its `...` – keeps being passed as the value it was.
