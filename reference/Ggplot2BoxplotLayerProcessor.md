# Boxplot Layer Processor

Processes boxplot layers (geom_boxplot) to extract statistical data and
generate selectors for individual boxplot components in the SVG
structure.

## Super class

[`maidr::LayerProcessor`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/LayerProcessor.md)
-\> `Ggplot2BoxplotLayerProcessor`

## Methods

### Public methods

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

- [`maidr::LayerProcessor$apply_scale_mapping()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/LayerProcessor.html#method-apply_scale_mapping)
- [`maidr::LayerProcessor$extract_layer_axes()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/LayerProcessor.html#method-extract_layer_axes)
- [`maidr::LayerProcessor$get_last_result()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/LayerProcessor.html#method-get_last_result)
- [`maidr::LayerProcessor$get_layer_index()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/LayerProcessor.html#method-get_layer_index)
- [`maidr::LayerProcessor$initialize()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/LayerProcessor.html#method-initialize)
- [`maidr::LayerProcessor$needs_reordering()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/LayerProcessor.html#method-needs_reordering)
- [`maidr::LayerProcessor$reorder_layer_data()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/LayerProcessor.html#method-reorder_layer_data)
- [`maidr::LayerProcessor$set_last_result()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/LayerProcessor.html#method-set_last_result)

------------------------------------------------------------------------

### Method `process()`

#### Usage

    Ggplot2BoxplotLayerProcessor$process(plot, layout, built = NULL, gt = NULL)

#### Arguments

- `plot`:

  The ggplot2 object

- `layout`:

  Layout information

- `built`:

  Built plot data (optional)

- `gt`:

  Gtable object (optional)

#### Returns

List with data and selectors Extract data from boxplot layer

------------------------------------------------------------------------

### Method `extract_data()`

#### Usage

    Ggplot2BoxplotLayerProcessor$extract_data(plot, built = NULL)

#### Arguments

- `plot`:

  The ggplot2 object

- `built`:

  Built plot data (optional)

#### Returns

List with boxplot statistics for each category Generate selectors for
boxplot elements

------------------------------------------------------------------------

### Method `generate_selectors()`

#### Usage

    Ggplot2BoxplotLayerProcessor$generate_selectors(plot, gt = NULL)

#### Arguments

- `plot`:

  The ggplot2 object

- `gt`:

  Gtable object (optional)

#### Returns

List of selectors for each boxplot Determine if the boxplot is
horizontal or vertical

------------------------------------------------------------------------

### Method `determine_orientation()`

#### Usage

    Ggplot2BoxplotLayerProcessor$determine_orientation(plot)

#### Arguments

- `plot`:

  The ggplot2 object

#### Returns

"horz" or "vert" Map numeric category codes to actual category names
Uses panel_params axis labels from ggplot_build to map codes to labels

------------------------------------------------------------------------

### Method `map_categories_to_names()`

#### Usage

    Ggplot2BoxplotLayerProcessor$map_categories_to_names(boxplot_data, plot)

#### Arguments

- `boxplot_data`:

  List of boxplot statistics

- `plot`:

  The ggplot2 object

#### Returns

Updated boxplot data with proper category names Find the main panel grob

------------------------------------------------------------------------

### Method [`find_panel_grob()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/find_panel_grob.md)

#### Usage

    Ggplot2BoxplotLayerProcessor$find_panel_grob(gt)

#### Arguments

- `gt`:

  The gtable to search

#### Returns

The panel grob or NULL Find children by type pattern

------------------------------------------------------------------------

### Method [`find_children_by_type()`](http://xabilitylab.ischool.illinois.edu/r-maidr/reference/find_children_by_type.md)

#### Usage

    Ggplot2BoxplotLayerProcessor$find_children_by_type(grob, type_pattern)

#### Arguments

- `grob`:

  The grob to search

- `type_pattern`:

  Pattern to match

#### Returns

List of matching children Find the outlier container within a boxplot

------------------------------------------------------------------------

### Method `find_outlier_container()`

#### Usage

    Ggplot2BoxplotLayerProcessor$find_outlier_container(gt, boxplot_id)

#### Arguments

- `gt`:

  The gtable object

- `boxplot_id`:

  The boxplot container ID

#### Returns

The outlier container ID or NULL Find the box container within a boxplot

------------------------------------------------------------------------

### Method `find_box_container()`

#### Usage

    Ggplot2BoxplotLayerProcessor$find_box_container(gt, boxplot_id)

#### Arguments

- `gt`:

  The gtable object

- `boxplot_id`:

  The boxplot container ID

#### Returns

The box container ID or NULL Find the whisker container within a boxplot

------------------------------------------------------------------------

### Method `find_whisker_container()`

#### Usage

    Ggplot2BoxplotLayerProcessor$find_whisker_container(gt, boxplot_id)

#### Arguments

- `gt`:

  The gtable object

- `boxplot_id`:

  The boxplot container ID

#### Returns

The whisker container ID or NULL Find the median container within a
boxplot

------------------------------------------------------------------------

### Method `find_median_container()`

#### Usage

    Ggplot2BoxplotLayerProcessor$find_median_container(gt, boxplot_id)

#### Arguments

- `gt`:

  The gtable object

- `boxplot_id`:

  The boxplot container ID

#### Returns

The median container ID or NULL Find a child element by pattern within a
container

------------------------------------------------------------------------

### Method `find_child_by_pattern()`

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

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    Ggplot2BoxplotLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
