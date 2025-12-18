# Point Layer Processor

Processes scatter plot layers (geom_point) to extract point data and
generate selectors for individual points in the SVG structure.

## Super class

[`maidr::LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md)
-\> `Ggplot2PointLayerProcessor`

## Methods

### Public methods

- [`Ggplot2PointLayerProcessor$process()`](#method-Ggplot2PointLayerProcessor-process)

- [`Ggplot2PointLayerProcessor$extract_axes_labels()`](#method-Ggplot2PointLayerProcessor-extract_axes_labels)

- [`Ggplot2PointLayerProcessor$extract_data()`](#method-Ggplot2PointLayerProcessor-extract_data)

- [`Ggplot2PointLayerProcessor$generate_selectors()`](#method-Ggplot2PointLayerProcessor-generate_selectors)

- [`Ggplot2PointLayerProcessor$find_panel_grob()`](#method-Ggplot2PointLayerProcessor-find_panel_grob)

- [`Ggplot2PointLayerProcessor$find_children_by_type()`](#method-Ggplot2PointLayerProcessor-find_children_by_type)

- [`Ggplot2PointLayerProcessor$clone()`](#method-Ggplot2PointLayerProcessor-clone)

Inherited methods

- [`maidr::LayerProcessor$apply_scale_mapping()`](https://r.maidr.ai/reference/LayerProcessor.html#method-apply_scale_mapping)
- [`maidr::LayerProcessor$extract_layer_axes()`](https://r.maidr.ai/reference/LayerProcessor.html#method-extract_layer_axes)
- [`maidr::LayerProcessor$get_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_last_result)
- [`maidr::LayerProcessor$get_layer_index()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_layer_index)
- [`maidr::LayerProcessor$initialize()`](https://r.maidr.ai/reference/LayerProcessor.html#method-initialize)
- [`maidr::LayerProcessor$needs_reordering()`](https://r.maidr.ai/reference/LayerProcessor.html#method-needs_reordering)
- [`maidr::LayerProcessor$reorder_layer_data()`](https://r.maidr.ai/reference/LayerProcessor.html#method-reorder_layer_data)
- [`maidr::LayerProcessor$set_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-set_last_result)

------------------------------------------------------------------------

### Method `process()`

#### Usage

    Ggplot2PointLayerProcessor$process(
      plot,
      layout,
      built = NULL,
      gt = NULL,
      scale_mapping = NULL,
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

- `scale_mapping`:

  Scale mapping for faceted plots (optional)

- `grob_id`:

  Grob ID for faceted plots (optional)

- `panel_id`:

  Panel ID for faceted plots (optional)

#### Returns

List with data and selectors Extract axis labels from the plot

------------------------------------------------------------------------

### Method `extract_axes_labels()`

#### Usage

    Ggplot2PointLayerProcessor$extract_axes_labels(plot, built = NULL)

#### Arguments

- `plot`:

  The ggplot2 object

- `built`:

  Built plot data (optional)

#### Returns

List with x and y axis labels Extract data from point layer

------------------------------------------------------------------------

### Method `extract_data()`

#### Usage

    Ggplot2PointLayerProcessor$extract_data(
      plot,
      built = NULL,
      scale_mapping = NULL,
      panel_id = NULL
    )

#### Arguments

- `plot`:

  The ggplot2 object

- `built`:

  Built plot data (optional)

- `scale_mapping`:

  Scale mapping for faceted plots (optional)

- `panel_id`:

  Panel ID for faceted plots (optional)

#### Returns

List with points array and color information Generate selectors for
point elements

------------------------------------------------------------------------

### Method `generate_selectors()`

#### Usage

    Ggplot2PointLayerProcessor$generate_selectors(
      plot,
      gt = NULL,
      grob_id = NULL,
      panel_ctx = NULL
    )

#### Arguments

- `plot`:

  The ggplot2 object

- `gt`:

  Gtable object (optional)

- `grob_id`:

  Grob ID for faceted plots (optional)

#### Returns

List of selectors Find the main panel grob

------------------------------------------------------------------------

### Method [`find_panel_grob()`](https://r.maidr.ai/reference/find_panel_grob.md)

#### Usage

    Ggplot2PointLayerProcessor$find_panel_grob(gt)

#### Arguments

- `gt`:

  The gtable to search

#### Returns

The panel grob or NULL Find children by type pattern

------------------------------------------------------------------------

### Method [`find_children_by_type()`](https://r.maidr.ai/reference/find_children_by_type.md)

#### Usage

    Ggplot2PointLayerProcessor$find_children_by_type(grob, type_pattern)

#### Arguments

- `grob`:

  The grob to search

- `type_pattern`:

  Pattern to match

#### Returns

List of matching children

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    Ggplot2PointLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
