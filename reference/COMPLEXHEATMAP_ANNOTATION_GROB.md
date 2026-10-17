# The name the cells of one slice of a ComplexHeatmap annotation track are exported under

`anno_simple()` draws the cells of a track, in each slice of the heat
map, as one rect grob with a generated name. Each is renamed to this
prefix followed by `-<h>-<t>-<k>`: the heat map's place among those
read, the track's place among that heat map's tracks, and the slice, so
each cell is the SVG element
`#maidr-complexheatmap-annotation-<h>-<t>-<k>.1.<i>`.

## Usage

``` r
COMPLEXHEATMAP_ANNOTATION_GROB
```
