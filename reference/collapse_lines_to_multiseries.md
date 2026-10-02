# Collapse multiple "line" layer entries in a single panel into one multi-series line layer entry. Other layers are left untouched.

The first line layer's id, title, and axes are preserved; data and
selectors are concatenated across all line layers. An axis the line
layers name differently is named by the panel's axis title instead (see
[`merge_line_layers()`](https://r.maidr.ai/reference/merge_line_layers.md)).

## Usage

``` r
collapse_lines_to_multiseries(panel, axes = NULL)
```

## Arguments

- panel:

  A processed panel list with \$id and \$layers

- axes:

  The panel's axis titles, as a layout carries them, or NULL to keep the
  first line layer's names whatever the others say

## Value

Panel with line layers merged
