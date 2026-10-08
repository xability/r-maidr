# Whether a line layer maps the precision-recall vocabulary

A precision-recall curve drawn as
[`geom_line()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
or
[`geom_path()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
carries no evidence of what it means except its column names, and
[`ggplot2::autoplot()`](https://ggplot2.tidyverse.org/reference/autoplot.html)
of a
[`yardstick::pr_curve()`](https://yardstick.tidymodels.org/reference/pr_curve.html)
names them after the rates themselves: `recall` against `precision`.
Those names are the claim, as `specificity` and `sensitivity` are for a
ROC curve
([`layer_maps_roc_rates()`](https://r.maidr.ai/reference/layer_maps_roc_rates.md)).

## Usage

``` r
layer_maps_pr_rates(layer, plot_object)
```

## Arguments

- layer:

  A ggplot2 layer

- plot_object:

  The plot the layer belongs to

## Value

TRUE when the layer's x is recall and its y precision
