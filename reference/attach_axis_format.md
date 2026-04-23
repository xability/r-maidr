# Attach a format object to a specific axis

Mutates a single axis's `format` field. Creates the axis slot (with
`label = default_label`) if it does not exist. No-ops when `format_obj`
is NULL.

## Usage

``` r
attach_axis_format(axes, which, format_obj, default_label = "")
```

## Arguments

- axes:

  Canonical axes list

- which:

  Axis key: one of `"x"`, `"y"`, `"z"`

- format_obj:

  AxisFormat list (or NULL)

- default_label:

  Label to use if the axis slot is being created

## Value

The mutated axes list
