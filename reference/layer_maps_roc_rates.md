# Whether a line layer maps the ROC's own vocabulary

A ROC curve drawn as
[`geom_line()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
or
[`geom_path()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
carries no evidence of what it means except its column names, and two
producers name them after the rates themselves:
[`pROC::ggroc()`](https://rdrr.io/pkg/pROC/man/ggroc.html) maps
`specificity` or `1-specificity` against `sensitivity`, and
[`ggplot2::autoplot()`](https://ggplot2.tidyverse.org/reference/autoplot.html)
of a
[`yardstick::roc_curve()`](https://yardstick.tidymodels.org/reference/roc_curve.html)
maps `1 - specificity` against `sensitivity`. Those names are the claim,
and nothing else is read as one – a line of `fpr` against `tpr` under
any other column names is declared with
[`maidr_roc()`](https://r.maidr.ai/reference/maidr_roc.md) instead,
because a rule loose enough to catch it would catch charts that are not
ROC curves.

## Usage

``` r
layer_maps_roc_rates(layer, plot_object)
```

## Arguments

- layer:

  A ggplot2 layer

- plot_object:

  The plot the layer belongs to

## Value

TRUE when the layer's x and y are specificity and sensitivity
