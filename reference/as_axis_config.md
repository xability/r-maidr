# Normalize a single axis value into AxisConfig shape

Accepts legacy or partial inputs (bare string label, already-wrapped
list, or NULL) and returns either NULL (when nothing to emit) or a named
list conforming to the AxisConfig schema.

## Usage

``` r
as_axis_config(value)
```

## Arguments

- value:

  Raw axis input (string, list, or NULL)

## Value

A named list (AxisConfig) or NULL
