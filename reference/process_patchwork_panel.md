# Process a single patchwork panel

Process a single patchwork panel

## Usage

``` r
process_patchwork_panel(
  leaf_plot,
  panel_name,
  panel_index,
  row,
  col,
  layout,
  gtable,
  n_original_layers = NULL
)
```

## Arguments

- leaf_plot:

  The leaf ggplot object

- panel_name:

  Panel name from gtable

- panel_index:

  Panel index

- row:

  Panel row

- col:

  Panel column

- layout:

  Layout information

- gtable:

  Gtable object

- n_original_layers:

  Number of layers the user actually wrote. Defaults to every layer of
  `leaf_plot`; pass the un-augmented count so injected geoms (violin's
  boxplot) do not emit a maidr layer of their own.

## Value

Processed panel data
