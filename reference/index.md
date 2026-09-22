# Package index

## Main functions

Primary user-facing functions for creating accessible plots

- [`show()`](https://r.maidr.ai/reference/show.md) : Display Interactive
  MAIDR Plot
- [`save_html()`](https://r.maidr.ai/reference/save_html.md) : Save
  Interactive Plot as HTML File

## Declaring what a layer means

Functions an author adds to a plot to say what a layer is, where the
picture alone cannot say it

- [`maidr_gantt()`](https://r.maidr.ai/reference/maidr_gantt.md) :
  Declare that a rectangle layer draws a schedule
- [`maidr_roc()`](https://r.maidr.ai/reference/maidr_roc.md) : Declare
  that a path layer draws a ROC curve

## Turning interception on and off

Interception is on after library(maidr): printing a ggplot2 object opens
the viewer and Base R calls are recorded until show(). An R Markdown or
Quarto document calls maidr_on() in a setup chunk for the knitr hooks;
the options turn parts of it off.

- [`maidr_on()`](https://r.maidr.ai/reference/maidr_on.md) : Enable
  MAIDR Plot Interception
- [`maidr_off()`](https://r.maidr.ai/reference/maidr_off.md) : Disable
  MAIDR Plot Interception
- [`maidr-options`](https://r.maidr.ai/reference/maidr-options.md) :
  MAIDR Package Options

## What attaching maidr masks

The Base R plotting functions and methods::show(), each replaced on the
search path by a wrapper that records the call and passes through to the
original

- [`barplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  [`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  [`hist()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  [`boxplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  [`image()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  [`heatmap()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  [`contour()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  [`matplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  [`curve()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  [`dotchart()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  [`stripchart()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  [`stem()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  [`pie()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  [`mosaicplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  [`assocplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  [`pairs()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  [`coplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  [`persp()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  [`sunflowerplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  [`fourfoldplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  [`spineplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  [`cdplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  [`qqnorm()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  [`qqplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  [`qqline()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  [`filled.contour()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  [`acf()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  [`pacf()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  [`ccf()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  [`cpgram()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  [`spectrum()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  [`monthplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  [`termplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  [`lag.plot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  [`biplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  [`interaction.plot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  [`bxp()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  [`stars()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  [`vioplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  [`wordcloud()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  [`chartSeries()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  [`lines()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  [`points()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  [`text()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  [`mtext()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  [`abline()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  [`segments()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  [`arrows()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  [`polygon()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  [`rect()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  [`symbols()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  [`legend()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  [`axis()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  [`title()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  [`grid()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  [`par()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  [`layout()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  [`split(`*`<screen>`*`)`](https://r.maidr.ai/reference/base-r-wrappers.md)
  : Functions maidr masks on attach

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
- [`maidr_download_dotpad_sdk()`](https://r.maidr.ai/reference/maidr_download_dotpad_sdk.md)
  : Download the DotPad SDK for use offline
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
  : Recursively extract leaf ggplots in patchwork addition order

- [`find_children_by_type()`](https://r.maidr.ai/reference/find_children_by_type.md)
  : Find children matching a type pattern

- [`find_graphics_plot_grob()`](https://r.maidr.ai/reference/find_graphics_plot_grob.md)
  : Find grob by element type pattern

- [`find_patchwork_panels()`](https://r.maidr.ai/reference/find_patchwork_panels.md)
  :

  Discover panels via gtable layout rows named `^panel-<num>` or
  `^panel-<row>-<col>` Returns a data.frame with panel_index, name, t,
  l, row, col

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

- [`process_faceted_plot_data()`](https://r.maidr.ai/reference/process_faceted_plot_data.md)
  : Process a faceted plot and return organized subplot data

- [`process_patchwork_panel()`](https://r.maidr.ai/reference/process_patchwork_panel.md)
  : Process a single patchwork panel

- [`process_patchwork_plot_data()`](https://r.maidr.ai/reference/process_patchwork_plot_data.md)
  : Process a patchwork plot and return organized subplot data
