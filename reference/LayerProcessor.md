# Abstract Layer Processor Interface

Abstract Layer Processor Interface

Abstract Layer Processor Interface

## Details

This is the abstract base class for all layer processors. It defines the
interface that all layer processors must implement.

## Public fields

- `layer_info`:

  Information about the layer

- `layer_info`:

  Information about the layer

## Methods

### Public methods

- [`LayerProcessor$new()`](#method-LayerProcessor-new)

- [`LayerProcessor$process()`](#method-LayerProcessor-process)

- [`LayerProcessor$extract_data()`](#method-LayerProcessor-extract_data)

- [`LayerProcessor$generate_selectors()`](#method-LayerProcessor-generate_selectors)

- [`LayerProcessor$needs_reordering()`](#method-LayerProcessor-needs_reordering)

- [`LayerProcessor$reorder_layer_data()`](#method-LayerProcessor-reorder_layer_data)

- [`LayerProcessor$get_layer_index()`](#method-LayerProcessor-get_layer_index)

- [`LayerProcessor$set_last_result()`](#method-LayerProcessor-set_last_result)

- [`LayerProcessor$get_last_result()`](#method-LayerProcessor-get_last_result)

- [`LayerProcessor$extract_layer_axes()`](#method-LayerProcessor-extract_layer_axes)

- [`LayerProcessor$apply_scale_mapping()`](#method-LayerProcessor-apply_scale_mapping)

- [`LayerProcessor$clone()`](#method-LayerProcessor-clone)

------------------------------------------------------------------------

### Method `new()`

Initialize the layer processor

#### Usage

    LayerProcessor$new(layer_info)

#### Arguments

- `layer_info`:

  Information about the layer

------------------------------------------------------------------------

### Method `process()`

Process the layer (MUST be implemented by subclasses)

#### Usage

    LayerProcessor$process(
      plot,
      layout,
      built = NULL,
      gt = NULL,
      scale_mapping = NULL,
      grob_id = NULL,
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

- `panel_ctx`:

  Panel context for panel-scoped selector generation (optional)

#### Returns

List with data and selectors

------------------------------------------------------------------------

### Method `extract_data()`

Extract data from the layer (MUST be implemented by subclasses)

#### Usage

    LayerProcessor$extract_data(plot, built = NULL, scale_mapping = NULL)

#### Arguments

- `plot`:

  The ggplot2 object

- `built`:

  Built plot data (optional)

- `scale_mapping`:

  Scale mapping for faceted plots (optional)

#### Returns

Extracted data

------------------------------------------------------------------------

### Method `generate_selectors()`

Generate selectors for the layer (MUST be implemented by subclasses)

#### Usage

    LayerProcessor$generate_selectors(
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

- `panel_ctx`:

  Panel context for panel-scoped selector generation (optional)

#### Returns

List of selectors

------------------------------------------------------------------------

### Method `needs_reordering()`

Check if this layer needs reordering (OPTIONAL - default: FALSE)

#### Usage

    LayerProcessor$needs_reordering()

#### Returns

Logical indicating if reordering is needed

------------------------------------------------------------------------

### Method `reorder_layer_data()`

Reorder layer data (OPTIONAL - default: no-op)

#### Usage

    LayerProcessor$reorder_layer_data(data, plot)

#### Arguments

- `data`:

  data.frame effective for this layer

- `plot`:

  full ggplot object (for mappings)

#### Returns

Reordered data

------------------------------------------------------------------------

### Method `get_layer_index()`

Get layer index

#### Usage

    LayerProcessor$get_layer_index()

#### Returns

Layer index

------------------------------------------------------------------------

### Method `set_last_result()`

Store the last processed result (used by orchestrator)

#### Usage

    LayerProcessor$set_last_result(result)

#### Arguments

- `result`:

  The result to store

------------------------------------------------------------------------

### Method `get_last_result()`

Get the last processed result

#### Usage

    LayerProcessor$get_last_result()

#### Returns

The last result

------------------------------------------------------------------------

### Method `extract_layer_axes()`

Extract axes labels for this specific layer

#### Usage

    LayerProcessor$extract_layer_axes(plot, layout)

#### Arguments

- `plot`:

  The ggplot object

- `layout`:

  Global layout with fallback axes

#### Returns

List with x and y axis labels

------------------------------------------------------------------------

### Method [`apply_scale_mapping()`](https://r.maidr.ai/reference/apply_scale_mapping.md)

Apply scale mapping to numeric values

#### Usage

    LayerProcessor$apply_scale_mapping(numeric_values, scale_mapping)

#### Arguments

- `numeric_values`:

  Vector of numeric values

- `scale_mapping`:

  Scale mapping vector

#### Returns

Mapped values

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    LayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
