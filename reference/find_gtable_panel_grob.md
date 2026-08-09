# Resolve the panel grob a layer belongs to

Without a panel context this keeps the single-plot behaviour: the cell
literally named "panel". With one, the panel is addressed by
`panel_ctx$panel_index` into
[`collect_gtable_panels()`](https://r.maidr.ai/reference/collect_gtable_panels.md),
whose order matches
[`find_patchwork_panels()`](https://r.maidr.ai/reference/find_patchwork_panels.md).
Name matching is only a fallback because patchwork reuses panel names
across nesting levels.

## Usage

``` r
find_gtable_panel_grob(gt, panel_ctx = NULL)
```

## Arguments

- gt:

  Gtable object

- panel_ctx:

  Panel context (panel_index, panel_name, ...), or NULL

## Value

The panel gTree, or NULL when it cannot be resolved
