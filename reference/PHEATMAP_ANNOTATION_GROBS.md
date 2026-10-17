# The names the annotation tracks of a pheatmap are exported under

[`pheatmap()`](https://r.maidr.ai/reference/pheatmap.md) draws all the
column annotation tracks as one rect grob and all the row annotation
tracks as another, each with a generated name. They are renamed to these
before drawing
([`pheatmap_name_annotations()`](https://r.maidr.ai/reference/pheatmap_name_annotations.md)),
so each cell of a track is the SVG element `#<name>.1.<k>`.

## Usage

``` r
PHEATMAP_ANNOTATION_GROBS
```
