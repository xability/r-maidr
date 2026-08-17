# Boxplot Layer Processor

Processes boxplot layers (geom_boxplot) to extract statistical data and
generate selectors for individual boxplot components in the SVG
structure.

## Super class

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
`Ggplot2BoxplotLayerProcessor`

## Methods

### Public methods

- [`Ggplot2BoxplotLayerProcessor$get_built()`](#method-Ggplot2BoxplotLayerProcessor-get_built)

- [`Ggplot2BoxplotLayerProcessor$process()`](#method-Ggplot2BoxplotLayerProcessor-process)

- [`Ggplot2BoxplotLayerProcessor$extract_data()`](#method-Ggplot2BoxplotLayerProcessor-extract_data)

- [`Ggplot2BoxplotLayerProcessor$generate_selectors()`](#method-Ggplot2BoxplotLayerProcessor-generate_selectors)

- [`Ggplot2BoxplotLayerProcessor$determine_orientation()`](#method-Ggplot2BoxplotLayerProcessor-determine_orientation)

- [`Ggplot2BoxplotLayerProcessor$map_categories_to_names()`](#method-Ggplot2BoxplotLayerProcessor-map_categories_to_names)

- [`Ggplot2BoxplotLayerProcessor$find_panel_grob()`](#method-Ggplot2BoxplotLayerProcessor-find_panel_grob)

- [`Ggplot2BoxplotLayerProcessor$find_children_by_type()`](#method-Ggplot2BoxplotLayerProcessor-find_children_by_type)

- [`Ggplot2BoxplotLayerProcessor$find_outlier_container()`](#method-Ggplot2BoxplotLayerProcessor-find_outlier_container)

- [`Ggplot2BoxplotLayerProcessor$find_box_container()`](#method-Ggplot2BoxplotLayerProcessor-find_box_container)

- [`Ggplot2BoxplotLayerProcessor$find_whisker_container()`](#method-Ggplot2BoxplotLayerProcessor-find_whisker_container)

- [`Ggplot2BoxplotLayerProcessor$find_median_container()`](#method-Ggplot2BoxplotLayerProcessor-find_median_container)

- [`Ggplot2BoxplotLayerProcessor$find_child_by_pattern()`](#method-Ggplot2BoxplotLayerProcessor-find_child_by_pattern)

- [`Ggplot2BoxplotLayerProcessor$clone()`](#method-Ggplot2BoxplotLayerProcessor-clone)

Inherited methods

- [`LayerProcessor$augment_plot()`](https://r.maidr.ai/reference/LayerProcessor.html#method-augment_plot)
- [`LayerProcessor$extract_layer_axes()`](https://r.maidr.ai/reference/LayerProcessor.html#method-extract_layer_axes)
- [`LayerProcessor$find_layer_grob_tree()`](https://r.maidr.ai/reference/LayerProcessor.html#method-find_layer_grob_tree)
- [`LayerProcessor$get_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_last_result)
- [`LayerProcessor$get_layer_built_data()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_layer_built_data)
- [`LayerProcessor$get_layer_index()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_layer_index)
- [`LayerProcessor$get_own_layer()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_own_layer)
- [`LayerProcessor$initialize()`](https://r.maidr.ai/reference/LayerProcessor.html#method-initialize)
- [`LayerProcessor$is_flipped_layer()`](https://r.maidr.ai/reference/LayerProcessor.html#method-is_flipped_layer)
- [`LayerProcessor$needs_augmentation()`](https://r.maidr.ai/reference/LayerProcessor.html#method-needs_augmentation)
- [`LayerProcessor$needs_reordering()`](https://r.maidr.ai/reference/LayerProcessor.html#method-needs_reordering)
- [`LayerProcessor$reorder_layer_data()`](https://r.maidr.ai/reference/LayerProcessor.html#method-reorder_layer_data)
- [`LayerProcessor$set_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-set_last_result)
- [`LayerProcessor$swap_point_axes()`](https://r.maidr.ai/reference/LayerProcessor.html#method-swap_point_axes)
- [`LayerProcessor$unflip_columns()`](https://r.maidr.ai/reference/LayerProcessor.html#method-unflip_columns)
- [`LayerProcessor$unflip_panel_params()`](https://r.maidr.ai/reference/LayerProcessor.html#method-unflip_panel_params)

------------------------------------------------------------------------

### `Ggplot2BoxplotLayerProcessor$get_built()`

Get (and cache) the built plot data

ggplot_build() is expensive; extract_data, generate_selectors,
determine_orientation, and map_categories_to_names all need it, so build
at most once per processor instance.

#### Usage

    Ggplot2BoxplotLayerProcessor$get_built(plot, built = NULL)

#### Arguments

- `plot`:

  The ggplot2 object

- `built`:

  Optionally a pre-built plot to adopt

#### Returns

Built plot data

------------------------------------------------------------------------

### `Ggplot2BoxplotLayerProcessor$process()`

Process the boxplot layer

#### Usage

    Ggplot2BoxplotLayerProcessor$process(
      plot,
      layout,
      built = NULL,
      gt = NULL,
      grob_id = NULL,
      panel_id = NULL,
      panel_ctx = NULL
    )

#### Arguments

- `plot`:

  The ggplot2 object

- `layout`:

  Layout information

- `built`:

  Built plot data (optional)

- `gt`:

  Gtable object (optional)

- `grob_id`:

  Grob ID for faceted plots (optional)

- `panel_id`:

  Panel ID for faceted plots (optional)

- `panel_ctx`:

  Panel context for panel-scoped selectors (optional)

#### Returns

List with data and selectors

------------------------------------------------------------------------

### `Ggplot2BoxplotLayerProcessor$extract_data()`

Extract data from boxplot layer

#### Usage

    Ggplot2BoxplotLayerProcessor$extract_data(plot, built = NULL, panel_id = NULL)

#### Arguments

- `plot`:

  The ggplot2 object

- `built`:

  Built plot data (optional)

- `panel_id`:

  Optional facet panel to restrict extraction to

#### Returns

List with boxplot statistics for each category

------------------------------------------------------------------------

### `Ggplot2BoxplotLayerProcessor$generate_selectors()`

Generate selectors for boxplot elements

#### Usage

    Ggplot2BoxplotLayerProcessor$generate_selectors(
      plot,
      gt = NULL,
      panel_ctx = NULL,
      panel_id = NULL
    )

#### Arguments

- `plot`:

  The ggplot2 object

- `gt`:

  Gtable object (optional)

- `panel_ctx`:

  Panel context for panel-scoped selection (optional)

- `panel_id`:

  Optional facet panel to restrict outlier counts to

#### Returns

List of selectors for each boxplot

------------------------------------------------------------------------

### `Ggplot2BoxplotLayerProcessor$determine_orientation()`

Determine if the boxplot is horizontal or vertical

#### Usage

    Ggplot2BoxplotLayerProcessor$determine_orientation(plot)

#### Arguments

- `plot`:

  The ggplot2 object

#### Returns

"horz" or "vert"

------------------------------------------------------------------------

### `Ggplot2BoxplotLayerProcessor$map_categories_to_names()`

Map numeric category codes to actual category names Uses panel_params
axis labels from ggplot_build to map codes to labels

#### Usage

    Ggplot2BoxplotLayerProcessor$map_categories_to_names(
      boxplot_data,
      plot,
      panel_id = NULL
    )

#### Arguments

- `boxplot_data`:

  List of boxplot statistics

- `plot`:

  The ggplot2 object

- `panel_id`:

  Optional facet panel whose scale supplies the labels

#### Returns

Updated boxplot data with proper category names

------------------------------------------------------------------------

### `Ggplot2BoxplotLayerProcessor$find_panel_grob()`

Find the panel grob this layer draws into

#### Usage

    Ggplot2BoxplotLayerProcessor$find_panel_grob(gt, panel_ctx = NULL)

#### Arguments

- `gt`:

  The gtable to search

- `panel_ctx`:

  Panel context for patchwork leaves and facets; NULL for a single plot,
  where the panel is the cell literally named "panel"

#### Returns

The panel grob or NULL

------------------------------------------------------------------------

### `Ggplot2BoxplotLayerProcessor$find_children_by_type()`

Find children by type pattern

#### Usage

    Ggplot2BoxplotLayerProcessor$find_children_by_type(grob, type_pattern)

#### Arguments

- `grob`:

  The grob to search

- `type_pattern`:

  Pattern to match

#### Returns

List of matching children

------------------------------------------------------------------------

### `Ggplot2BoxplotLayerProcessor$find_outlier_container()`

Find the outlier container within a boxplot

#### Usage

    Ggplot2BoxplotLayerProcessor$find_outlier_container(gt, boxplot_id)

#### Arguments

- `gt`:

  The gtable object

- `boxplot_id`:

  The boxplot container ID

#### Returns

The outlier container ID or NULL

------------------------------------------------------------------------

### `Ggplot2BoxplotLayerProcessor$find_box_container()`

Find the box container within a boxplot

#### Usage

    Ggplot2BoxplotLayerProcessor$find_box_container(gt, boxplot_id)

#### Arguments

- `gt`:

  The gtable object

- `boxplot_id`:

  The boxplot container ID

#### Returns

The box container ID or NULL

------------------------------------------------------------------------

### `Ggplot2BoxplotLayerProcessor$find_whisker_container()`

Find the whisker container within a boxplot

#### Usage

    Ggplot2BoxplotLayerProcessor$find_whisker_container(gt, boxplot_id)

#### Arguments

- `gt`:

  The gtable object

- `boxplot_id`:

  The boxplot container ID

#### Returns

The whisker container ID or NULL

------------------------------------------------------------------------

### `Ggplot2BoxplotLayerProcessor$find_median_container()`

Find the median container within a boxplot

#### Usage

    Ggplot2BoxplotLayerProcessor$find_median_container(gt, boxplot_id)

#### Arguments

- `gt`:

  The gtable object

- `boxplot_id`:

  The boxplot container ID

#### Returns

The median container ID or NULL

------------------------------------------------------------------------

### `Ggplot2BoxplotLayerProcessor$find_child_by_pattern()`

Find a child element by pattern within a container

#### Usage

    Ggplot2BoxplotLayerProcessor$find_child_by_pattern(gt, container_id, pattern)

#### Arguments

- `gt`:

  The gtable object

- `container_id`:

  The container ID to search within

- `pattern`:

  Pattern to match

#### Returns

The matching child ID or NULL

------------------------------------------------------------------------

### `Ggplot2BoxplotLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    Ggplot2BoxplotLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
