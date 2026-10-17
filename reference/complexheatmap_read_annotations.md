# Read one ComplexHeatmap heat map's simple annotation tracks

Finds the tracks
([`complexheatmap_annotation_tracks()`](https://r.maidr.ai/reference/complexheatmap_annotation_tracks.md)),
names their cells in the drawing
([`complexheatmap_name_annotations()`](https://r.maidr.ai/reference/complexheatmap_name_annotations.md))
and reads each as a layer
([ComplexHeatmapAnnotationLayerProcessor](https://r.maidr.ai/reference/ComplexHeatmapAnnotationLayerProcessor.md)),
for the heat map's own subplot after its `heat` layer.

## Usage

``` r
complexheatmap_read_annotations(
  plot,
  view,
  layout,
  first,
  members = list(),
  h = 1L
)
```

## Arguments

- plot:

  The `Heatmap` or `HeatmapList` passed in

- view:

  The capture, from
  [`complexheatmap_capture()`](https://r.maidr.ai/reference/complexheatmap_capture.md),
  its `heatmap` the one whose tracks are read

- layout:

  The heat map's layout: its title and its rows' title

- first:

  The index the first track's layer is given

- members:

  The list's annotations the heat map owns
  ([`complexheatmap_member_annotations()`](https://r.maidr.ai/reference/complexheatmap_member_annotations.md))

- h:

  The heat map's place among those read

## Value

A list: `grob`, the drawing with the tracks' cells renamed; `layers`,
the layers read; `processors`, their processors; `unread`, the names of
the annotations drawn and not read
