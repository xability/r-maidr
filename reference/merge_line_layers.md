# Combine a list of single-line layer entries into one multi-series line entry.

Each input line layer's \`data\` is a list-of-series (typically length-1
for a single GeomLine/GeomMA). We concatenate all series across all
layers.

## Usage

``` r
merge_line_layers(line_layers)
```

## Details

Selector handling: the line layer's selector generator (panel_ctx path
in \`Ggplot2LineLayerProcessor\$generate_selectors\`) discovers \*all\*
polyline grobs in the panel, so when there are N line layers in the same
panel each input layer's \`selectors\` list is the same length-N set.
After merging we want exactly one selector per series (so the JS
frontend precondition \`selectors.length === data.length\` holds). We
therefore deduplicate selectors across input layers and trim/pad to the
merged series count.
