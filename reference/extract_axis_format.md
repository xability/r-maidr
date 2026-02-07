# Extract Format Configuration for a Single Axis

Extracts formatting configuration by inspecting the closure environment
of scales label functions (e.g., scales::label_dollar,
scales::label_percent).

## Usage

``` r
extract_axis_format(built, axis = "x")
```

## Arguments

- built:

  A built ggplot2 object

- axis:

  Either "x" or "y"

## Value

Format configuration list or NULL
