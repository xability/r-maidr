# Generate robust selector for any element type

Creates a robust CSS selector that works regardless of panel structure.
This is the main function that layer processors should use.

## Usage

``` r
generate_robust_selector(
  grob,
  element_type,
  svg_element,
  plot_index = NULL,
  max_elements = NULL
)
```

## Arguments

- grob:

  The grob tree to analyze

- element_type:

  The element type to search for (e.g., "rect", "lines")

- svg_element:

  The SVG element to target (e.g., "rect", "polyline")

- plot_index:

  Optional plot index for multipanel layouts

- max_elements:

  Optional limit on number of elements to target

## Value

A robust CSS selector string, or NULL if element not found
