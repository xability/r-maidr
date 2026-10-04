# Call a function on recorded values, passed under the names they were written as

`deparse1(substitute(x))` of a symbol is the symbol's name, whatever
characters it holds, so binding the recorded value of `hist(mtcars$mpg)`
to a symbol named "mtcars\$mpg" and passing that symbol gives
[`hist()`](https://r.maidr.ai/reference/base-r-wrappers.md) the value
that was recorded and the title it gave the user's call. Nothing the
user wrote is evaluated again: a loop variable, or `rnorm(10)`, is read
as the value it had when the chart was drawn.

## Usage

``` r
call_with_written_args(fn, args, arg_text)
```

## Arguments

- fn:

  The function to call

- args:

  Recorded argument list, as
  [`replay_plot_call()`](https://r.maidr.ai/reference/replay_plot_call.md)
  passes it

- arg_text:

  The text each argument was written as, or NA; one entry per recorded
  argument, which maidr's own `.maidr_` entries only ever follow; or
  NULL

## Value

What `fn` returns

## Details

Two arguments written alike but holding different values, as in
`plot(rnorm(5), rnorm(5))`, cannot share a name in one environment. The
later one is bound in an environment of its own, and reaches `fn`
through the `...` of a function that environment encloses: `...` hands
an argument on as it was written, so
[`substitute()`](https://rdrr.io/r/base/substitute.html) gives
"rnorm(5)" for both axes and each draws its own values. Only such an
argument goes that way, since a function that rebuilds its call with
[`match.call()`](https://rdrr.io/r/base/match.call.html) sees it as
`..1`; and only one passed by name, since the `...` comes after every
other argument. An unnamed one is passed as its value.
