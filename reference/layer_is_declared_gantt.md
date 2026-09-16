# Whether a layer's author declared it a schedule

[`maidr_gantt()`](https://r.maidr.ai/reference/maidr_gantt.md) is
maidr's word for "these rectangles are intervals in lanes", the way
[`annotate()`](https://ggplot2.tidyverse.org/reference/annotate.html) is
ggplot2's word for "this is decoration". A rectangle layer carries no
evidence of which it is – the eight-chart table above the `GeomRect`
branch in `detect_layer_type()` is the measurement that closed every
structural rule – so the function the author called is the answer rather
than evidence towards it.

## Usage

``` r
layer_is_declared_gantt(layer)
```

## Arguments

- layer:

  A ggplot2 layer object

## Value

TRUE when [`maidr_gantt()`](https://r.maidr.ai/reference/maidr_gantt.md)
built the layer

## Details

Two carriers are read, field first, because they fail in opposite
directions. Measured on ggplot2 3.4.4:


    maidr_gantt(m)                  head=maidr_gantt         field=gantt
    maidr::maidr_gantt(m)           head=::/maidr/maidr_gantt field=gantt
    one-deep user wrapper           head=maidr_gantt         field=gantt
    two-deep user wrapper           head=maidr_gantt         field=gantt
    do.call(maidr_gantt, list(m))   head=<coerce error>      field=gantt
    geom_rect(m)                    head=geom_rect           field=NULL
    annotate("rect", ...)           head=annotate            field=NULL

[`do.call()`](https://rdrr.io/r/base/do.call.html) leaves the closure
itself at `constructor[[1]]`, where
[`as.character()`](https://rdrr.io/r/base/character.html) raises "cannot
coerce type 'closure' to vector of type 'character'" – the identical
hole
[`layer_is_annotation()`](https://r.maidr.ai/reference/layer_is_annotation.md)
has for `do.call(annotate, ...)` – and the field answers there. The
constructor answers for a ggplot2 that re-instantiated the layer through
[`ggproto()`](https://ggplot2.tidyverse.org/reference/ggproto.html) and
dropped a field it did not know. Both are wrapped, so a layer that
answers neither is refused rather than raising.

Membership rather than equality on the head, for the reason
[`layer_is_annotation()`](https://r.maidr.ai/reference/layer_is_annotation.md)
gives: `maidr::maidr_gantt(...)` heads as
`c("::", "maidr", "maidr_gantt")`.
