# One rebuilt frame per layer, so a facet does not pay for it per panel

[`process_facet_panel()`](https://r.maidr.ai/reference/process_facet_panel.md)
runs once per panel, so a jittered layer asked for its undisplaced
positions once per panel too – and each of those rebuilds the *whole*
plot, every panel of it. Measured by counting
[`ggplot2::ggplot_build`](https://ggplot2.tidyverse.org/reference/ggplot_build.html)
calls through a facet of P panels: 3, 5 and 9 calls for P of 2, 4 and 8.
One build is the original; the other P are the same answer computed P
times over, so the work is quadratic in the panel count while the answer
never varies –
[`undisplaced_layer_data()`](https://r.maidr.ai/reference/undisplaced_layer_data.md)
depends only on the plot and the layer index.

## Usage

``` r
.jitter_cache
```

## Details

Keyed on the layer itself rather than on the plot. ggplot2 `Layer`
objects are ggproto, ggproto objects are environments, and
[`identical()`](https://rdrr.io/r/base/identical.html) on two
environments is a pointer comparison – so the lookup is O(1) and exact,
where hashing or deep-comparing the plot could cost as much as the
rebuild it saves. A layer belongs to one plot, so its identity settles
the question.

One entry per layer index, each holding the layer it was computed from,
and the whole cache emptied when a plot starts being processed.

All three parts are load-bearing. The index bounds the cache at the
number of layers a plot has and stops two jittered layers evicting each
other once per panel, which is the cost this exists to remove. The layer
catches the ordinary case of a second plot built from its own
[`geom_jitter()`](https://ggplot2.tidyverse.org/reference/geom_jitter.html).
And the reset catches the case the layer cannot: ggplot2 documents a
layer as reusable across plots, and `+.gg` appends the same ggproto
object rather than a clone, so

    shared <- geom_jitter()
    p1 <- ggplot(df1, aes(g, score)) + shared
    p2 <- ggplot(df2, aes(g, score)) + shared

gives two plots that are
[`identical()`](https://rdrr.io/r/base/identical.html) at that layer.
Measured before the reset went in: `p2` was announced with every one of
`df1`'s values, and the row-count check waved it through because the two
frames were the same length.
