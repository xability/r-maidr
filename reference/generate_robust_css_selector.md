# Generate robust CSS selector from grob name

Creates a CSS selector that targets SVG elements by their ID pattern,
without relying on panel structure or hardcoded values.

## Usage

``` r
generate_robust_css_selector(grob_name, svg_element)
```

## Arguments

- grob_name:

  The name of the grob (e.g., "graphics-plot-1-rect-1")

- svg_element:

  The SVG element type to target (e.g., "rect", "polyline")

## Value

A robust CSS selector string, or NULL if grob_name is invalid
