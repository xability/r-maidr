# Process a single facet panel

Process a single facet panel

## Usage

``` r
process_facet_panel(
  plot,
  panel_info,
  panel_data,
  facet_groups,
  gtable_panel_name,
  built,
  layout,
  gtable,
  format_config = NULL
)
```

## Arguments

- plot:

  The original plot

- panel_info:

  Panel information

- panel_data:

  Panel-specific data

- facet_groups:

  Facet group information

- gtable_panel_name:

  Gtable panel name, or NULL when no panel is drawn at the panel's
  place, which is then read without marks

- built:

  Built plot data

- layout:

  Layout information

- gtable:

  Gtable object

- format_config:

  Optional format configuration from maidr label functions

## Value

Processed panel data
