# Find grob by element type pattern

Searches recursively through a grob tree to find a grob whose name
matches the pattern: graphics-plot--\<element_type\>-

## Usage

``` r
find_graphics_plot_grob(grob, element_type, plot_index = NULL)
```

## Arguments

- grob:

  The grob tree to search (typically from ggplotify::as.grob())

- element_type:

  The element type to search for (e.g., "rect", "lines", "points")

- plot_index:

  Optional plot index to match (for multipanel layouts)

## Value

The name of the first matching grob, or NULL if not found
