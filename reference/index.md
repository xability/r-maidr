# Package index

## Main functions

Primary user-facing functions for creating accessible plots

- [`show()`](https://r.maidr.ai/reference/show.md) : Display Interactive
  MAIDR Plot
- [`save_html()`](https://r.maidr.ai/reference/save_html.md) : Save
  Interactive Plot as HTML File

## RMarkdown integration

Functions for enabling accessible plots in RMarkdown documents

- [`maidr_on()`](https://r.maidr.ai/reference/maidr_on.md) : Enable
  MAIDR Rendering in RMarkdown
- [`maidr_off()`](https://r.maidr.ai/reference/maidr_off.md) : Disable
  MAIDR Rendering in RMarkdown

## Shiny integration

Functions for using maidr in Shiny applications

- [`render_maidr()`](https://r.maidr.ai/reference/render_maidr.md) :
  Render MAIDR Plot in Shiny Server
- [`maidr_output()`](https://r.maidr.ai/reference/maidr_output.md) :
  MAIDR Output Container for Shiny UI

## Configuration and utilities

Functions for configuring MAIDR behavior and running examples

- [`maidr_set_fallback()`](https://r.maidr.ai/reference/maidr_set_fallback.md)
  : Configure MAIDR Fallback Behavior
- [`maidr_get_fallback()`](https://r.maidr.ai/reference/maidr_get_fallback.md)
  : Get Current MAIDR Fallback Settings
- [`run_example()`](https://r.maidr.ai/reference/run_example.md) : Run
  MAIDR Example Plots

## Internal utilities

Internal functions for package developers

- [`combine_facet_layer_data()`](https://r.maidr.ai/reference/combine_facet_layer_data.md)
  : Combine data from multiple layers in facet processing
- [`combine_facet_layer_selectors()`](https://r.maidr.ai/reference/combine_facet_layer_selectors.md)
  : Combine selectors from multiple layers in facet processing
- [`extract_leaf_plot_layout()`](https://r.maidr.ai/reference/extract_leaf_plot_layout.md)
  : Extract layout from a single leaf ggplot
- [`extract_patchwork_leaves()`](https://r.maidr.ai/reference/extract_patchwork_leaves.md)
  : Recursively extract leaf ggplots in visual order
- [`find_children_by_type()`](https://r.maidr.ai/reference/find_children_by_type.md)
  : Find children matching a type pattern
- [`find_graphics_plot_grob()`](https://r.maidr.ai/reference/find_graphics_plot_grob.md)
  : Utility functions for robust selector generation in Base R plots
- [`find_panel_grob()`](https://r.maidr.ai/reference/find_panel_grob.md)
  : Find the panel grob in a grob tree
- [`find_patchwork_panels()`](https://r.maidr.ai/reference/find_patchwork_panels.md)
  : Discover panels via gtable layout rows named '^panel-\<num\>' or
  '^panel-\<row\>-\<col\>' Returns a data.frame with panel_index, name,
  t, l, row, col
- [`generate_robust_css_selector()`](https://r.maidr.ai/reference/generate_robust_css_selector.md)
  : Generate robust CSS selector from grob name
- [`generate_robust_selector()`](https://r.maidr.ai/reference/generate_robust_selector.md)
  : Generate robust selector for any element type
- [`get_facet_groups()`](https://r.maidr.ai/reference/get_facet_groups.md)
  : Get facet group information for a panel
- [`map_visual_to_dom_panel()`](https://r.maidr.ai/reference/map_visual_to_dom_panel.md)
  : Map visual panel position to DOM panel name
- [`organize_facet_grid()`](https://r.maidr.ai/reference/organize_facet_grid.md)
  : Organize subplots into 2D grid structure
- [`process_facet_panel()`](https://r.maidr.ai/reference/process_facet_panel.md)
  : Process a single facet panel
- [`process_patchwork_panel()`](https://r.maidr.ai/reference/process_patchwork_panel.md)
  : Process a single patchwork panel
