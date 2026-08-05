# Log Plot Call to Device Storage

Records a plot call in the device-specific storage.

## Usage

``` r
log_plot_call_to_device(
  function_name,
  call_expr,
  args,
  device_id = grDevices::dev.cur(),
  call_env = NULL
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

## Value

NULL (invisible)
