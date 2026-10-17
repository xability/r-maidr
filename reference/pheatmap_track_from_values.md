# One annotation track from the values the caller passed

The values are taken only when they are what the track was drawn from: a
missing value exactly where no colour was drawn, and for a categorical
variable each level in one colour. A numeric variable is drawn by
cutting its range into 100 bins coloured along
`colorRampPalette(annotation_colors[[name]])(100)`; its colours are
computed so, from the colours the caller gave or else from the legend's
ramp of four (pheatmap's own palettes have four, which the ramp then
repeats exactly), and must be the colours drawn. With neither, each bin
must be in one colour.

## Usage

``` r
pheatmap_track_from_values(values, fill, colours = NULL, ramp = NULL)
```

## Arguments

- values:

  The variable's values, in drawn order

- fill:

  The colours the track was drawn in, in the same order

- colours:

  The variable's `annotation_colors` entry, or NULL

- ramp:

  The variable's ramp in the annotation legend, or NULL

## Value

`list(values, levels)` – `levels` NULL for a numeric variable, and a
categorical one's values the 1-based position of each in `levels` – or
NULL
