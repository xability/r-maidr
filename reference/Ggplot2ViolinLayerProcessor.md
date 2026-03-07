# Violin Layer Processor

Violin Layer Processor

Violin Layer Processor

## Details

Processes violin layers (geom_violin) to extract density curve (KDE)
data and box-summary statistics, producing two maidr layers:
\`violin_kde\` and \`violin_box\`.

The processor injects a thin \`geom_boxplot(width = 0.1)\` into the plot
before rendering so that the SVG contains visible box elements whose CSS
selectors can drive the violin_box highlight in the maidr frontend.

## Super class

[`maidr::LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md)
-\> `Ggplot2ViolinLayerProcessor`

## Methods

### Public methods

- [`Ggplot2ViolinLayerProcessor$needs_augmentation()`](#method-Ggplot2ViolinLayerProcessor-needs_augmentation)

- [`Ggplot2ViolinLayerProcessor$augment_plot()`](#method-Ggplot2ViolinLayerProcessor-augment_plot)

- [`Ggplot2ViolinLayerProcessor$process()`](#method-Ggplot2ViolinLayerProcessor-process)

- [`Ggplot2ViolinLayerProcessor$extract_box_data()`](#method-Ggplot2ViolinLayerProcessor-extract_box_data)

- [`Ggplot2ViolinLayerProcessor$extract_kde_data()`](#method-Ggplot2ViolinLayerProcessor-extract_kde_data)

- [`Ggplot2ViolinLayerProcessor$simplify_violin_kde()`](#method-Ggplot2ViolinLayerProcessor-simplify_violin_kde)

- [`Ggplot2ViolinLayerProcessor$extract_data()`](#method-Ggplot2ViolinLayerProcessor-extract_data)

- [`Ggplot2ViolinLayerProcessor$generate_selectors()`](#method-Ggplot2ViolinLayerProcessor-generate_selectors)

- [`Ggplot2ViolinLayerProcessor$generate_box_selectors()`](#method-Ggplot2ViolinLayerProcessor-generate_box_selectors)

- [`Ggplot2ViolinLayerProcessor$determine_orientation()`](#method-Ggplot2ViolinLayerProcessor-determine_orientation)

- [`Ggplot2ViolinLayerProcessor$get_effective_mapping()`](#method-Ggplot2ViolinLayerProcessor-get_effective_mapping)

- [`Ggplot2ViolinLayerProcessor$get_original_data()`](#method-Ggplot2ViolinLayerProcessor-get_original_data)

- [`Ggplot2ViolinLayerProcessor$get_category_labels()`](#method-Ggplot2ViolinLayerProcessor-get_category_labels)

- [`Ggplot2ViolinLayerProcessor$find_boxplot_layer_index()`](#method-Ggplot2ViolinLayerProcessor-find_boxplot_layer_index)

- [`Ggplot2ViolinLayerProcessor$find_panel_grob()`](#method-Ggplot2ViolinLayerProcessor-find_panel_grob)

- [`Ggplot2ViolinLayerProcessor$find_grob_ids()`](#method-Ggplot2ViolinLayerProcessor-find_grob_ids)

- [`Ggplot2ViolinLayerProcessor$find_direct_children()`](#method-Ggplot2ViolinLayerProcessor-find_direct_children)

- [`Ggplot2ViolinLayerProcessor$find_grob_by_id()`](#method-Ggplot2ViolinLayerProcessor-find_grob_by_id)

- [`Ggplot2ViolinLayerProcessor$find_desc_by_pattern()`](#method-Ggplot2ViolinLayerProcessor-find_desc_by_pattern)

- [`Ggplot2ViolinLayerProcessor$find_all_desc_by_pattern()`](#method-Ggplot2ViolinLayerProcessor-find_all_desc_by_pattern)

- [`Ggplot2ViolinLayerProcessor$clone()`](#method-Ggplot2ViolinLayerProcessor-clone)

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

### Method `needs_augmentation()`

Violin needs to inject a boxplot layer

#### Usage

    Ggplot2ViolinLayerProcessor$needs_augmentation()

------------------------------------------------------------------------

### Method `augment_plot()`

Inject geom_boxplot into the plot for visual box + selectors

#### Usage

    Ggplot2ViolinLayerProcessor$augment_plot(plot)

#### Arguments

- `plot`:

  ggplot2 object

#### Returns

Augmented ggplot2 object with boxplot layer added Process the violin
layer

Returns a list with \`multi_layer = TRUE\` and two maidr layers:
violin_box (with BoxSelector objects) and violin_kde.

------------------------------------------------------------------------

### Method `process()`

#### Usage

    Ggplot2ViolinLayerProcessor$process(plot, layout, built = NULL, gt = NULL)

#### Arguments

- `plot`:

  The ggplot2 object (already augmented with boxplot)

- `layout`:

  Layout information

- `built`:

  Built plot data (optional)

- `gt`:

  Gtable object (optional)

#### Returns

List with multi_layer flag and layers Extract box-summary statistics per
violin group

Computes min, Q1, median, Q3, max from the original data (since
geom_violin only stores the KDE curve, not quartiles).

------------------------------------------------------------------------

### Method `extract_box_data()`

#### Usage

    Ggplot2ViolinLayerProcessor$extract_box_data(plot, built)

#### Arguments

- `plot`:

  The ggplot2 object

- `built`:

  Built plot data

#### Returns

List of BoxPoint objects (one per violin) Extract KDE density-curve data
per violin group

Uses ggplot2's built violin data (violinwidth, x, y, width columns) to
compute left/right violin edges, applies RDP simplification to ~30
points per violin, and includes the \`width\` field needed by the maidr
frontend. The \`svg_x\`/\`svg_y\` coordinates are injected later by
\`create_enhanced_svg()\` after the grid device is drawn.

------------------------------------------------------------------------

### Method `extract_kde_data()`

#### Usage

    Ggplot2ViolinLayerProcessor$extract_kde_data(plot, built, max_kde_points = 30L)

#### Arguments

- `plot`:

  The ggplot2 object

- `built`:

  Built plot data

- `max_kde_points`:

  Maximum number of output points per violin (default 30)

#### Returns

List of lists (ViolinKdePoint\[\]\[\]) Simplify a single violin's KDE
curve using RDP

Uses ggplot2's built violin data columns (y, violinwidth, x, width) to
compute the left/right edges, then applies RDP simplification.

------------------------------------------------------------------------

### Method `simplify_violin_kde()`

#### Usage

    Ggplot2ViolinLayerProcessor$simplify_violin_kde(
      rows,
      cat_label,
      is_horizontal,
      max_points = 30L
    )

#### Arguments

- `rows`:

  data.frame of built violin data for one group

- `cat_label`:

  Character label for this violin category

- `is_horizontal`:

  Logical, TRUE for horizontal violins

- `max_points`:

  Maximum number of output points

#### Returns

List of ViolinKdePoint dicts with data_left_x/data_right_x/data_y Not
used directly - required by base class interface Generate CSS selectors
for violin polygons (for violin_kde layer)

------------------------------------------------------------------------

### Method `extract_data()`

#### Usage

    Ggplot2ViolinLayerProcessor$extract_data(
      plot,
      built = NULL,
      scale_mapping = NULL
    )

------------------------------------------------------------------------

### Method `generate_selectors()`

#### Usage

    Ggplot2ViolinLayerProcessor$generate_selectors(
      plot,
      gt = NULL,
      grob_id = NULL,
      panel_ctx = NULL
    )

#### Arguments

- `plot`:

  The ggplot2 object

- `gt`:

  Gtable object

- `grob_id`:

  Grob ID (for faceted plots)

- `panel_ctx`:

  Panel context (for faceted plots)

#### Returns

List of CSS selector strings (one per violin) Generate BoxSelector
objects for the injected boxplot grobs

Walks the gtable to find geom_boxplot grobs and produces a BoxSelector
list (one per violin) with CSS selectors for min, iq, q2, max,
lowerOutliers, upperOutliers.

------------------------------------------------------------------------

### Method `generate_box_selectors()`

#### Usage

    Ggplot2ViolinLayerProcessor$generate_box_selectors(plot, gt, built)

#### Arguments

- `plot`:

  The ggplot2 object (augmented with boxplot)

- `gt`:

  Gtable object

- `built`:

  Built plot data

#### Returns

List of BoxSelector objects Determine orientation from built data Get
the effective mapping (layer mapping merged with plot mapping) Get
original data used by this layer Get category labels from panel params
Find the boxplot layer index in the augmented plot Find the main panel
grob Recursively find all grob IDs matching a pattern Find direct
children of a named parent matching a pattern Find a grob by its name
(recursive) Find the first descendant matching a pattern under a named
parent Find all descendants matching a pattern under a named parent

------------------------------------------------------------------------

### Method `determine_orientation()`

#### Usage

    Ggplot2ViolinLayerProcessor$determine_orientation(built)

------------------------------------------------------------------------

### Method `get_effective_mapping()`

#### Usage

    Ggplot2ViolinLayerProcessor$get_effective_mapping(plot)

------------------------------------------------------------------------

### Method `get_original_data()`

#### Usage

    Ggplot2ViolinLayerProcessor$get_original_data(plot)

------------------------------------------------------------------------

### Method `get_category_labels()`

#### Usage

    Ggplot2ViolinLayerProcessor$get_category_labels(panel_params, is_horizontal)

------------------------------------------------------------------------

### Method `find_boxplot_layer_index()`

#### Usage

    Ggplot2ViolinLayerProcessor$find_boxplot_layer_index(plot)

------------------------------------------------------------------------

### Method [`find_panel_grob()`](https://r.maidr.ai/reference/find_panel_grob.md)

#### Usage

    Ggplot2ViolinLayerProcessor$find_panel_grob(gt)

------------------------------------------------------------------------

### Method `find_grob_ids()`

#### Usage

    Ggplot2ViolinLayerProcessor$find_grob_ids(grob, pattern)

------------------------------------------------------------------------

### Method `find_direct_children()`

#### Usage

    Ggplot2ViolinLayerProcessor$find_direct_children(grob, parent_id, pattern)

------------------------------------------------------------------------

### Method `find_grob_by_id()`

#### Usage

    Ggplot2ViolinLayerProcessor$find_grob_by_id(grob, target_id)

------------------------------------------------------------------------

### Method `find_desc_by_pattern()`

#### Usage

    Ggplot2ViolinLayerProcessor$find_desc_by_pattern(grob, parent_id, pattern)

------------------------------------------------------------------------

### Method `find_all_desc_by_pattern()`

#### Usage

    Ggplot2ViolinLayerProcessor$find_all_desc_by_pattern(grob, parent_id, pattern)

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    Ggplot2ViolinLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
