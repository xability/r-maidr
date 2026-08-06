# Patchwork Processing Utilities

Utility functions for processing patchwork multipanel compositions.
These functions handle panel discovery, leaf extraction, and processing
for patchwork plots in a unified way.

## Usage

``` r
process_patchwork_plot_data(plot, layout, gtable, original_plot = NULL)
```

## Arguments

- plot:

  The patchwork plot object, with leaves already augmented

- layout:

  Layout information

- gtable:

  Gtable object

- original_plot:

  The un-augmented composition. Supplied so each leaf is processed for
  the layers the user wrote rather than for the extra geoms a processor
  injected to render its selectors.

## Value

List with organized subplot data in 2D grid format
