# Log Plot Call to Device Storage

Records a plot call in the device-specific storage.

## Usage

``` r
log_plot_call_to_device(
  function_name,
  call_expr,
  args,
  device_id = grDevices::dev.cur(),
  call_env = NULL,
  arg_text = NULL,
  rng_state = .maidr_call_start$rng_state
)
```

## Arguments

- function_name:

  Name of the plotting function

- call_expr:

  The call expression

- args:

  List of function arguments

- device_id:

  Graphics device ID

- call_env:

  Optional environment for replaying unevaluated (NSE) arguments
  recorded in `args`

- arg_text:

  Optional text each argument in `args` was written as, from
  [`written_arg_text()`](https://r.maidr.ai/reference/written_arg_text.md),
  which the replay titles the chart after

- rng_state:

  The `.Random.seed` the call started from, which the replay draws from,
  so a chart that draws random numbers comes out as the reader was shown
  it; by default the state the recording wrapper noted before it drew
  ([`ensure_maidr_device()`](https://r.maidr.ai/reference/ensure_maidr_device.md))

## Value

NULL (invisible)
