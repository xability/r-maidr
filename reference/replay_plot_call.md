# Replay a recorded plot call with the original (unwrapped) function

Strips maidr-internal arguments and re-executes the call. When the
recorded args contain unevaluated expressions (from non-standard
evaluation, e.g. `curve(sin(x))` or `plot(y ~ x, subset = g == 1)`), the
call is rebuilt and evaluated in the environment captured at record time
so those expressions resolve exactly as they did originally.

## Usage

``` r
replay_plot_call(
  function_name,
  args,
  call_env = NULL,
  arg_text = NULL,
  rng_state = NULL
)
```

## Arguments

- function_name:

  Name of the recorded function

- args:

  Recorded argument list (values and/or expressions)

- call_env:

  Environment captured when NSE arguments could not be forced at record
  time, or NULL when all args are plain values

- arg_text:

  The text each argument was written as, NA where its value is replayed
  as it is, from
  [`written_arg_text()`](https://r.maidr.ai/reference/written_arg_text.md);
  or NULL

- rng_state:

  The `.Random.seed` the call started from, which the replay draws from
  and then puts the session's own state back (see
  `with_random_state()`); or NULL to draw from the session's state

## Value

The result of the replayed call (invisibly)

## Details

Such a call's titles are recorded as the values R drew (see
`with_drawn_titles()`), and drawn as those values: evaluated again, a
title's code would run what it does again, and could give another value.
An expression vector among them is handed over quoted, as
[`call_with_written_args()`](https://r.maidr.ai/reference/call_with_written_args.md)
hands it.

Otherwise the recorded values are drawn, each argument `arg_text` names
passed under a symbol spelled as it was written (see
[`call_with_written_args()`](https://r.maidr.ai/reference/call_with_written_args.md)),
so a title R derives from that text comes out as it did in the user's
own call.
