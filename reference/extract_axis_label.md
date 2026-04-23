# Extract a label from a possibly-wrapped axis value

Accepts a bare string, an AxisConfig list with a `label` field, or NULL.
Returns a character scalar.

## Usage

``` r
extract_axis_label(value, default = "")
```

## Arguments

- value:

  Raw axis input

- default:

  Default label when no value is present

## Value

Character scalar label
