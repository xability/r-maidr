# Facet Processing Utilities

Utility functions for processing faceted ggplot2 plots. These functions
handle panel extraction, processing, and grid organization for faceted
plots in a unified way.

## Usage

``` r
process_faceted_plot_data(plot, layout, built, gtable)
```

## Arguments

- plot:

  The faceted ggplot2 object

- layout:

  Layout information

- built:

  Built plot data

- gtable:

  Gtable object

## Value

List with organized subplot data in 2D grid format
