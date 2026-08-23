# Whether the smooth processor can read a layer drawn with this geom

The list this processor works from, stated once so that the classifier
can consult it. `Ggplot2Adapter$detect_layer_type()` decides a layer is
a `"smooth"` partly on its *stat* – `StatFunction` and `StatDensity`
both claim one – and a stat can name a geom this list does not. When it
did, `resolve_target_layer()` rejected the layer's own index, found
nothing in the fallback search and
[`stop()`](https://rdrr.io/r/base/stop.html)ped:

## Usage

``` r
smooth_reads_geom(geom)
```

## Arguments

- geom:

  A layer's geom

## Value

TRUE when this processor can read a layer drawn with it

## Details


    stat_function(fun = sin, geom = "point")  Error: No smooth curve layers found in plot
    stat_function(fun = sin, geom = "step")   Error: No smooth curve layers found in plot
    stat_function(fun = sin)                  interactive

Not a fallback to a picture – an error out of
[`save_html()`](https://r.maidr.ai/reference/save_html.md), so the
caller's script stopped, and which geom the author passed decided
whether the call returned at all (#230). A decline is a reading
decision; an exception is a broken call.

[`inherits()`](https://rdrr.io/r/base/class.html) rather than
`class(geom)[1]` here, unlike the dispatch: this asks whether the
processor can *read* the artist, which a subclass of a readable geom
can. `GeomFunction` and `GeomQuantile` are named all the same, because
both are `GeomPath` subclasses and a plain
[`geom_path()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
is typed `"line"` and never arrives here – widening to the parent would
claim nothing extra and would blur what this list is for, the geoms that
draw a *computed* curve (#202, \#229).
