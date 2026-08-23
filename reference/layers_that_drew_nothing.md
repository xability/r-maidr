# Which of a plot's layers drew no rows

The one place the emptiness rule lives, so the orchestrator and the
patchwork leaf path cannot disagree about it. A leaf inside a
`patchwork` composition is classified by `ggplot2_patchwork_utils.R`
rather than by `Ggplot2PlotOrchestrator$detect_layers()`, so a rule
written only in the orchestrator would have left every composed chart
ghosting (#232).

## Usage

``` r
layers_that_drew_nothing(plot)
```

## Arguments

- plot:

  A ggplot object.

## Value

Integer indices into `plot$layers`, possibly empty.

## Details

One
[`ggplot_build()`](https://ggplot2.tidyverse.org/reference/ggplot_build.html)
per plot, not per layer. That is what makes this affordable at all: the
same question asked inside `detect_layer_type()` would multiply the
build by the layer count, which is why \#231 applied it to one geom
only.

A build that cannot answer reports nothing empty. A plot that will not
build is a bigger problem than this one, and it is about to be met by
whatever else needs the build.
