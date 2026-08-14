# Hexbin Layer Processor

Processes hexagonal binning layers (`geom_hex`, `stat_binhex`).

A hexbin is the standard answer to an overplotted scatter: bin the
points into hexagons and encode the count as fill. Read as a lattice of
counted cells that is a heatmap, and the navigation, braille and pitch
all transfer – but the rows are staggered, so it is a layer type of its
own rather than a heatmap with different cells. See
[`hexbin_lattice()`](https://r.maidr.ai/reference/hexbin_lattice.md) for
what that costs.

## Super class

[`LayerProcessor`](https://r.maidr.ai/reference/LayerProcessor.md) -\>
`Ggplot2HexbinLayerProcessor`

## Methods

### Public methods

- [`Ggplot2HexbinLayerProcessor$process()`](#method-Ggplot2HexbinLayerProcessor-process)

- [`Ggplot2HexbinLayerProcessor$extract_data()`](#method-Ggplot2HexbinLayerProcessor-extract_data)

- [`Ggplot2HexbinLayerProcessor$extract_axes()`](#method-Ggplot2HexbinLayerProcessor-extract_axes)

- [`Ggplot2HexbinLayerProcessor$generate_selectors()`](#method-Ggplot2HexbinLayerProcessor-generate_selectors)

- [`Ggplot2HexbinLayerProcessor$find_hex_polygon_name()`](#method-Ggplot2HexbinLayerProcessor-find_hex_polygon_name)

- [`Ggplot2HexbinLayerProcessor$clone()`](#method-Ggplot2HexbinLayerProcessor-clone)

Inherited methods

- [`LayerProcessor$apply_scale_mapping()`](https://r.maidr.ai/reference/LayerProcessor.html#method-apply_scale_mapping)
- [`LayerProcessor$augment_plot()`](https://r.maidr.ai/reference/LayerProcessor.html#method-augment_plot)
- [`LayerProcessor$extract_layer_axes()`](https://r.maidr.ai/reference/LayerProcessor.html#method-extract_layer_axes)
- [`LayerProcessor$find_layer_grob_tree()`](https://r.maidr.ai/reference/LayerProcessor.html#method-find_layer_grob_tree)
- [`LayerProcessor$get_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_last_result)
- [`LayerProcessor$get_layer_built_data()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_layer_built_data)
- [`LayerProcessor$get_layer_index()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_layer_index)
- [`LayerProcessor$get_own_layer()`](https://r.maidr.ai/reference/LayerProcessor.html#method-get_own_layer)
- [`LayerProcessor$initialize()`](https://r.maidr.ai/reference/LayerProcessor.html#method-initialize)
- [`LayerProcessor$needs_augmentation()`](https://r.maidr.ai/reference/LayerProcessor.html#method-needs_augmentation)
- [`LayerProcessor$needs_reordering()`](https://r.maidr.ai/reference/LayerProcessor.html#method-needs_reordering)
- [`LayerProcessor$reorder_layer_data()`](https://r.maidr.ai/reference/LayerProcessor.html#method-reorder_layer_data)
- [`LayerProcessor$set_last_result()`](https://r.maidr.ai/reference/LayerProcessor.html#method-set_last_result)

------------------------------------------------------------------------

### `Ggplot2HexbinLayerProcessor$process()`

Process the hexbin layer

#### Usage

    Ggplot2HexbinLayerProcessor$process(
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

- `panel_ctx`:

  Panel context for patchwork leaves and facets

#### Returns

List with data, selectors and axes

------------------------------------------------------------------------

### `Ggplot2HexbinLayerProcessor$extract_data()`

Read the drawn lattice out of the built data

The built data *is* the lattice: one row per drawn hexagon, carrying its
centre and its count. Nothing is reconstructed from the source columns,
which are the raw observations and say nothing about where the stat
placed the bins.

#### Usage

    Ggplot2HexbinLayerProcessor$extract_data(plot, built = NULL, panel_id = NULL)

#### Arguments

- `plot`:

  The ggplot2 object

- `built`:

  Built plot data (optional)

- `panel_id`:

  Panel ID for faceted plots (optional)

#### Returns

The list
[`hexbin_lattice()`](https://r.maidr.ai/reference/hexbin_lattice.md)
returns

------------------------------------------------------------------------

### `Ggplot2HexbinLayerProcessor$extract_axes()`

Name the three axes

The colour axis is the count of points that fell in the bin, which is
what
[`stat_binhex()`](https://ggplot2.tidyverse.org/reference/geom_hex.html)
computes and what the fill encodes. Named here rather than read from the
legend title, which says "count" for the default and would say
`after_stat(density)` for a chart that is still counting into the same
cells.

x and y go through
[`positional_axis_label()`](https://r.maidr.ai/reference/positional_axis_label.md),
which is the package's shared
"[`labs()`](https://ggplot2.tidyverse.org/reference/labs.html) override,
then the layer's own mapping, then the plot's" chain, falling back to
the aesthetic name rather than to nothing.

#### Usage

    Ggplot2HexbinLayerProcessor$extract_axes(plot, built = NULL)

#### Arguments

- `plot`:

  The ggplot2 object

- `built`:

  Built plot data (optional)

#### Returns

An axes payload with x, y and z

------------------------------------------------------------------------

### `Ggplot2HexbinLayerProcessor$generate_selectors()`

Address each drawn hexagon by its own element

gridSVG exports the layer's single multi-polygon grob as one `<polygon>`
per hexagon, in built-data order, each carrying an id of the form
`<grob>.1.<n>`. So a bin is addressed by the built row it came from, and
the emitted list follows the regrouping rather than the document.

The frontend withdraws highlighting outright unless the resolved element
count matches the bin count exactly, so a partial list is worse than
none – an empty list is returned when the grob cannot be found rather
than a guess at its name.

#### Usage

    Ggplot2HexbinLayerProcessor$generate_selectors(
      gt = NULL,
      plot = NULL,
      panel_ctx = NULL,
      order = integer(0)
    )

#### Arguments

- `gt`:

  Gtable object

- `plot`:

  The ggplot2 object, used to build a gtable when none is given

- `panel_ctx`:

  Panel context for patchwork leaves and facets

- `order`:

  The built-data row behind each bin, in emission order

#### Returns

A list of CSS selectors, one per bin

------------------------------------------------------------------------

### `Ggplot2HexbinLayerProcessor$find_hex_polygon_name()`

Find the name of the grob holding the hexagons

`GeomHex` draws every hexagon in one `polygonGrob`, so there is a single
name to find rather than one per bin. Searched depth-first because the
layer's grobs sit inside a gTree of their own – and the caller passes
that tree rather than the panel, so a first match is this layer's rather
than some other hexbin's.

#### Usage

    Ggplot2HexbinLayerProcessor$find_hex_polygon_name(grob)

#### Arguments

- `grob`:

  The layer's grob tree to search

#### Returns

The grob name, or NULL when the layer drew nothing

------------------------------------------------------------------------

### `Ggplot2HexbinLayerProcessor$clone()`

The objects of this class are cloneable with this method.

#### Usage

    Ggplot2HexbinLayerProcessor$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
