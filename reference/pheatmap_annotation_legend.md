# The categorical entries of a pheatmap's annotation legend

[`pheatmap()`](https://r.maidr.ai/reference/pheatmap.md) draws the
legend of its annotations as a run of grobs per variable: its name, then
for a categorical variable one rect grob of the levels' colours and one
text grob of their names, in the order of `annotation_colors`; for a
numeric one two rect grobs (a ramp of four colours,
`colorRampPalette(annotation_colors[[name]])(4)`, and its frame) and the
two ends of its range. Only the categorical entries say exactly what a
colour stands for; a numeric entry's ramp says which colours its values
were drawn from.

## Usage

``` r
pheatmap_annotation_legend(legend)
```

## Arguments

- legend:

  The gtable's `"annotation_legend"` grob, or NULL

## Value

A named list, by variable: `list(colours, levels)` for a categorical
variable, `list(ramp)` for a numeric one; empty when there is no legend
or it is not laid out so
