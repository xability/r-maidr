# Positions to category names for one axis of one panel

Positions to category names for one axis of one panel

## Usage

``` r
discrete_axis_labels(built, axis = "x", panel_id = NULL)
```

## Arguments

- built:

  The built ggplot2 object

- axis:

  `"x"` or `"y"`

- panel_id:

  The panel to read, defaulting to the first

## Value

A named character vector keyed by position (as character), or `NULL`
when the axis is continuous. Empty names are dropped, so a scale with a
blank label yields the number rather than a blank announcement.
