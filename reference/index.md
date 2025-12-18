# Package index

## Main functions

Primary user-facing functions for creating accessible plots

- [`show()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/show.md)
  : Display Interactive MAIDR Plot
- [`save_html()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/save_html.md)
  : Save Interactive Plot as HTML File

## RMarkdown integration

Functions for enabling accessible plots in RMarkdown documents

- [`maidr_on()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/maidr_on.md)
  : Enable MAIDR Rendering in RMarkdown
- [`maidr_off()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/maidr_off.md)
  : Disable MAIDR Rendering in RMarkdown

## Shiny integration

Functions for using maidr in Shiny applications

- [`render_maidr()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/render_maidr.md)
  : Render MAIDR Plot in Shiny Server
- [`maidr_output()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/maidr_output.md)
  : MAIDR Output Container for Shiny UI

## Configuration and utilities

Functions for configuring MAIDR behavior and running examples

- [`maidr_set_fallback()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/maidr_set_fallback.md)
  : Configure MAIDR Fallback Behavior
- [`maidr_get_fallback()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/maidr_get_fallback.md)
  : Get Current MAIDR Fallback Settings
- [`run_example()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/run_example.md)
  : Run MAIDR Example Plots

## Internal utilities

Internal functions for package developers

- [`combine_facet_layer_data()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/combine_facet_layer_data.md)
  : Combine data from multiple layers in facet processing
- [`combine_facet_layer_selectors()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/combine_facet_layer_selectors.md)
  : Combine selectors from multiple layers in facet processing
- [`extract_leaf_plot_layout()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/extract_leaf_plot_layout.md)
  : Extract layout from a single leaf ggplot
- [`extract_patchwork_leaves()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/extract_patchwork_leaves.md)
  : Recursively extract leaf ggplots in visual order
- [`find_children_by_type()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/find_children_by_type.md)
  : Find children matching a type pattern
- [`find_graphics_plot_grob()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/find_graphics_plot_grob.md)
  : Utility functions for robust selector generation in Base R plots
- [`find_panel_grob()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/find_panel_grob.md)
  : Find the panel grob in a grob tree
- [`find_patchwork_panels()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/find_patchwork_panels.md)
  : Discover panels via gtable layout rows named '^panel-\<num\>' or
  '^panel-\<row\>-\<col\>' Returns a data.frame with panel_index, name,
  t, l, row, col
- [`generate_robust_css_selector()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/generate_robust_css_selector.md)
  : Generate robust CSS selector from grob name
- [`generate_robust_selector()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/generate_robust_selector.md)
  : Generate robust selector for any element type
- [`get_facet_groups()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/get_facet_groups.md)
  : Get facet group information for a panel
- [`map_visual_to_dom_panel()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/map_visual_to_dom_panel.md)
  : Map visual panel position to DOM panel name
- [`organize_facet_grid()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/organize_facet_grid.md)
  : Organize subplots into 2D grid structure
- [`process_facet_panel()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/process_facet_panel.md)
  : Process a single facet panel
- [`process_patchwork_panel()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/process_patchwork_panel.md)
  : Process a single patchwork panel
