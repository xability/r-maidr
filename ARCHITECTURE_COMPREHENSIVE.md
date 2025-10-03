# Maidr Architecture (Comprehensive)

## Overview

Maidr converts ggplot2 (and patchwork) plots into interactive HTML with a
standard JSON payload embedded in the root SVG (maidr-data). The system:
- Detects plot topology (single, faceted, patchwork)
- Reuses per-geom processors for data extraction and selector generation
- Scopes selector discovery to the correct panel subtree so CSS IDs match the
  final exported SVG

This document explains the full flow module-by-module starting from maidr.R.

## Execution Flow

1) User calls an exported entrypoint (e.g., `create_maidr_html()` in `maidr.R`).
2) We instantiate `PlotOrchestrator` with the plot.
3) Orchestrator detects: patchwork → facet → single.
4) For facets and patchwork, we delegate to dedicated processors that build a
   2D `subplots` grid and call per-layer processors with panel context.
5) Layer processors extract data and generate SVG selectors from the composed
   gtable’s panel subtree.
6) We write an HTML document with the SVG and `maidr-data` JSON.

## Entry Module: `maidr/R/maidr.R`

- Public API for creating and displaying maidr HTML.
- Creates `PlotOrchestrator$new(plot)` and calls `generate_maidr_data()`.
- Emits HTML that includes the SVG, JS/CSS deps, and the JSON payload
  (`maidr-data`).

Key point: Does not perform selector extraction; delegates to the orchestrator
and downstream processors.

## Core Coordinator: `maidr/R/plot_orchestrator.R`

Responsibilities:
- Hold the input plot and minimal layout (title/axes) metadata
- Detect plot type
- Delegate to the appropriate processor
- Assemble the final `maidr-data` structure

Important methods:
- `initialize(plot)`
  - If `is_patchwork_plot()` → `process_patchwork_plot()`
  - Else if `is_faceted_plot()` → `process_faceted_plot()`
  - Else → single-plot path (`detect_layers()` → `create_layer_processors()` →
    `process_layers()`).
- `process_faceted_plot()`
  - Builds `gt <- ggplotGrob(plot)` (the same gtable exported to SVG)
  - `facet_processor <- FacetProcessor$new(plot, layout, gt)`
  - `facet_processor$process()` returns 2D `subplots` grid
  - Stores to `private$.combined_data`
- `process_patchwork_plot()`
  - Builds composed gtable via `patchwork::patchworkGrob(plot)`
  - `pp <- PatchworkProcessor$new(plot, layout, gt)`
  - `pp$process()` returns 2D `subplots` grid
  - Stores to `private$.combined_data`
- `generate_maidr_data()`
  - For patchwork and facets, returns `list(id, subplots = combined_data)`
  - For single plots, wraps layers inside a 1x1 `subplots` grid

## Facet Orchestration: `maidr/R/facet_processor.R`

Purpose: Convert a faceted ggplot into a 2D `subplots` grid, reusing the same
layer processors as single plots, but for each panel.

Key stages:
- `initialize(plot, layout, built, gt)`
  - Stores plot, layout, ensures `built <- ggplot_build(plot)` and
    `gt <- ggplotGrob(plot)` (composed gtable that becomes the final SVG)
  - Computes `scale_mapping` from `built` for axis label mapping when needed
- `process()`
  - `panels <- extract_panels()` to collect `(PANEL id, ROW, COL, data,
    facet_groups, gtable_panel_name)`
  - For each panel: `process_panel(panel)` → subplot (`layers` list)
  - `organize_into_grid(subplots, panels)` arranges results by `ROW`, `COL`
- `extract_panels()`
  - Reads `panel_layout <- built$layout$layout`
  - Finds real panel entries from `gt$layout$name` matching `^panel-`
  - For each panel in `panel_layout`:
    - `expected_panel_name = panel-ROW-COL`
    - Find the actual DOM panel name by prefix match against `gt$layout$name`
      (handles suffixes like `.10-7-10-7`)
    - Store `gtable_panel_name` (the exact DOM panel name)
- `process_panel(panel)`
  - For each layer in the original plot: map geom → appropriate layer processor
  - Build `panel_ctx`:
    - `panel_name` (exact matched gtable panel name)
    - `row`, `col`, `panel_id`, `layer_index`
  - Call `processor$process(plot, layout, built, gt, scale_mapping,
    grob_id = NULL, panel_id, panel_ctx)`
  - Combine results into a subplot with `id`, `layers`, `axes`, `title`

Design rule: Facet orchestration does not compute per-geom `grob_id`. It computes
`panel_ctx` and relies on the layer processor to resolve selectors from that
panel’s subtree.

## Patchwork Orchestration: `maidr/R/patchwork_processor.R`

Purpose: Support multipanel layouts built with patchwork, producing the same 2D
`subplots` grid shape as facets.

Key stages:
- `initialize(plot, layout, gt)`
  - Passed the composed gtable from the orchestrator
- `extract_leaf_plots(node)`
  - Recurse only through true `patchwork` nodes; treat each ggplot node as a leaf
    (do not follow `patchwork_link`)
- `find_panels_from_layout()`
  - Scan `gt$layout` for rows named `^panel-\d+(-\d+)?$`
  - Derive visual `row`, `col` via:
    - Parsing `panel-R-C` if present, otherwise
    - Ranking unique `t` (top) and `l` (left) coordinates
- `process()`
  - Order panels row-major; build grid of size `max(row) x max(col)`
  - Extract leaf ggplots in visual order
  - For each panel `(row, col)`:
    - Choose `leaf_plot` if available, else fallback to full plot
    - For each layer in `leaf_plot`, map geom → processor
    - Build `panel_ctx` with the exact `panel_name` from `gt$layout$name`, plus `row`,
      `col`, `panel_index`, `layer_index`
    - Call processor as in facets; place the resulting subplot at
      `grid[[row]][[col]]`

Design rule: Patchwork reuses the same layer processors and the same
panel-scoped selector resolution pattern as facets. All selector IDs are taken
from the composed gtable, so they match the final SVG.

## Processor Interface: `maidr/R/layer_processor.R`

R6 base class that defines the common interface implemented by concrete
processors.

Important methods:
- `process(plot, layout, built = NULL, gt = NULL, scale_mapping = NULL,
  grob_id = NULL, panel_ctx = NULL)`
  - Returns `list(data = ..., selectors = ..., [axes], [type])`
- `extract_data(plot, built = NULL, scale_mapping = NULL)`
  - Returns structured data for the layer
- `generate_selectors(plot, gt = NULL, grob_id = NULL, panel_ctx = NULL)`
  - Returns CSS selectors matching the exported SVG
- `needs_reordering()` / `reorder_layer_data(data, plot)`
  - Optional conveniences for ordering stability
- `get_layer_index()`
  - Exposes layer index carried in `layer_info`

## Concrete Processors (selected)

All concrete processors follow the same pattern: extract data from the
`built$data` for their layer index, then generate selectors under the panel
subtree named by `panel_ctx$panel_name`.

- `maidr/R/bar_layer_processor.R`
  - Data: extracts bar heights; respects `panel_id` when present
  - Selectors (panel-scoped):
    - Find panel grob by prefix: `grepl(paste0("^", panel_name, "\\b"), gt$layout$name)`
    - Recursively collect child names matching `geom_rect.rect`
    - Emit CSS `#geom_rect\\.rect\\.<id>\\.1 rect`

- `maidr/R/line_layer_processor.R`
  - Data: handles single-line and multi-line (grouped) layers
  - Selectors (panel-scoped):
    - Find `GRID.polyline.<id>` containers under the panel subtree
    - Emit CSS `#GRID\\.polyline\\.<id>\\.1\\.1` (basic targeting per series)

- `maidr/R/point_layer_processor.R`
  - Data: extracts points; includes color if mapped
  - Selectors (panel-scoped):
    - Find `geom_point.points.<id>` containers
    - Emit CSS `g#geom_point\\.points\\.<id>\\.1 > use`

Other processors (`dodged_bar`, `stacked_bar`, `histogram`, `smooth`, etc.) follow the
same structure and reuse the same panel-scoped approach.

## Selector Generation Policy (Uniform)

- Orchestration (facet/patchwork) identifies the correct panel and passes
  `panel_ctx$panel_name` into each layer processor.
- Layer processors:
  - Locate the panel subtree by prefix matching `panel_ctx$panel_name` in
    `gt$layout$name`
  - Search for geom-specific grobs inside that subtree
  - Build fully-escaped CSS selectors that match the final SVG IDs

This avoids brittle per-geom `grob_id` plumbing at the orchestration level and
keeps facets and patchwork uniform.

## JSON Structure (`maidr-data`)

Standard shape embedded in the root SVG:

```json
{
  "id": "maidr-plot-<timestamp>",
  "subplots": [
    [ { "id": "maidr-subplot-...", "layers": [ { "id": "...", "type": "bar|line|point|...", "title": "...", "axes": {"x": "...", "y": "..."}, "data": [...], "selectors": ["#..."] } ] } ],
    ...
  ]
}
```

- `subplots` is always a 2D array (facets, patchwork; single treated as 1x1)
- Each layer contains its own `data` and `selectors`

## Robustness Details

- Facet panel mapping: UI DOM order can differ from data order; we rely on
  prefix matching `panel-ROW-COL` to the gtable’s `layout$name` to retrieve the
  exact DOM panel and avoid order assumptions.
- Patchwork panel mapping: derive `row`/`col` by parsing `panel-R-C` or ranking layout
  coordinates `t` (top) and `l` (left) when names are numeric only.
- Panel-scoped selector resolution guarantees selectors align with the final
  exported SVG.

## Testing and Examples

- `maidr/examples/all_plot_types_example.R` runs comprehensive examples:
  - Single-geom plots, multi-layer overlays, facets, patchwork 2x2
- Generated HTML saved under `maidr/output/` for manual inspection
- Lints checked on modified files to ensure code style/consistency

## Extensibility Guidelines

- To add a new geom:
  - Implement a new `LayerProcessor` subclass
  - Map the geom class to the processor in orchestrator (single) and facet/
    patchwork processors (which already switch on layer geom)
  - Implement `extract_data()` and `generate_selectors()`
  - Follow the panel-scoped selector policy using `panel_ctx$panel_name`

- To support a new multi-panel layout mechanism:
  - Create a new <X>Processor modeled on `FacetProcessor`/`PatchworkProcessor`
  - Identify panels from the composed gtable and compute `row`, `col`
  - Pass `panel_ctx` (with `panel_name`) into per-layer processors

## Summary

- `maidr.R` kicks off processing by instantiating the `PlotOrchestrator`.
- The orchestrator detects plot type and delegates:
  - `FacetProcessor` finds panels using `ggplot_build` plus gtable prefix match
  - `PatchworkProcessor` finds panels directly from gtable layout
- Both pass `panel_ctx` to layer processors, which resolve selectors within the
  correct panel subtree and return data + CSS selectors.
- `maidr-data` is a consistent 2D grid of subplots with layers, ready for
  interactive consumption.
