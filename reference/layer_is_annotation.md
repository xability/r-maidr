# Whether a layer was drawn by `annotate()` rather than by a geom

[`annotate()`](https://ggplot2.tidyverse.org/reference/annotate.html) is
ggplot2's word for decoration: a highlighted region, a label, an arrow
pointing at something. Whatever geom it happens to use, the function is
the author saying "this is not data".

## Usage

``` r
layer_is_annotation(layer)
```

## Arguments

- layer:

  A ggplot2 layer object

## Value

TRUE when
[`annotate()`](https://ggplot2.tidyverse.org/reference/annotate.html)
built the layer

## Details

ggplot2 records which function built each layer, so this is exact rather
than a guess about geometry. Measured on ggplot2 3.4.4,
`layer$constructor` holds the matched call and its head is the function
name:


    geom_rect(aes(...))                       -> geom_rect
    annotate("rect", xmin = 2, xmax = 3, ...) -> annotate
    annotate("text", x = 2, y = 3, ...)       -> annotate

It survives disguise, which is what makes it better than the shape-based
rules considered in \#197.
[`annotate()`](https://ggplot2.tidyverse.org/reference/annotate.html)
sets `inherit.aes = FALSE` and `show.legend = FALSE`, so those two look
like a signature – but a
[`geom_rect()`](https://ggplot2.tidyverse.org/reference/geom_tile.html)
written with both still reports `geom_rect`, and a rule keyed on them
would call that user's data decoration.

Deliberately not a rule about *what* an annotation may draw. The whole
point of asking the constructor is that the answer does not depend on
the mark: `annotate("segment")` is an arrow, not a schedule, and a
geometry test would have to claim or refuse it on its coordinates.

A layer with no `constructor` – a ggplot2 that stopped recording it, or
a layer built by hand – answers FALSE and keeps whatever reading it had.
