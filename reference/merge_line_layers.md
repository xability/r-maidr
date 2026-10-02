# Combine a list of single-line layer entries into one multi-series line entry.

Each input line layer's `data` is a list-of-series (typically length-1
for a single GeomLine/GeomMA). We concatenate all series across all
layers.

## Usage

``` r
merge_line_layers(line_layers, axes = NULL)
```

## Arguments

- line_layers:

  The line layer entries, in panel order

- axes:

  The panel's axis titles, or NULL to keep the first layer's names

## Details

Selector handling: each input layer now resolves to its OWN polyline
grob and emits one selector per curve it drew, so the inputs no longer
overlap. The dedupe-and-trim below is kept as a backstop, not as the
mechanism: it used to be load-bearing, because the generator discovered
*all* polyline grobs in the panel and handed every one of N line layers
the same length-N set. What still has to hold after merging is the
frontend precondition `selectors.length === data.length`, one selector
per merged series, which is why the trim below stays. There is
deliberately no pad: a short list fails that precondition and the
frontend drops the layer's highlight rather than aiming it at the wrong
curve.

The merged layer is read under one name per axis. When the line layers
were named differently –
`geom_line(aes(y = sales)) + geom_line(aes(y = target))` – none of their
names describes every series, and the panel's axis title does (#349).
