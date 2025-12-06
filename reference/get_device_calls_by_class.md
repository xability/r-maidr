# Filter Device Calls by Classification

Retrieves plot calls of a specific classification level.

## Usage

``` r
get_device_calls_by_class(
  device_id = grDevices::dev.cur(),
  class_level = "HIGH"
)
```

## Arguments

- device_id:

  Graphics device ID

- class_level:

  Classification level: "HIGH", "LOW", "LAYOUT"

## Value

List of filtered plot call entries
