# Declare that a path layer draws a ROC curve

`maidr_roc()` is
[`ggplot2::geom_path()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
with two things added: the author saying that the path is a receiver
operating characteristic curve, and a `threshold` aesthetic for the
decision threshold each point was scored at. A declared layer is read as
a `roc` – each point announced as its false and true positive rates, its
threshold and its height above the chance diagonal, the area under each
curve and the best operating point in the description – where the same
path drawn with
[`geom_path()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
or
[`geom_line()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
reads as a line, which says the rates and nothing a ROC curve is drawn
to say.

Nothing about the picture changes: the geom draws exactly what
[`geom_path()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
draws, and `threshold` reaches no mark.

## Usage

``` r
maidr_roc(
  mapping = NULL,
  data = NULL,
  position = "identity",
  ...,
  auc = NULL,
  na.rm = FALSE,
  show.legend = NA,
  inherit.aes = TRUE
)
```

## Arguments

- mapping:

  Aesthetics, as for
  [`ggplot2::geom_path()`](https://ggplot2.tidyverse.org/reference/geom_path.html):
  `x` (the false positive rate) and `y` (the true positive rate) are
  required, and `threshold` may name the decision threshold at each
  point. Every other path aesthetic (`colour`, `linetype`, `group`, ...)
  behaves exactly as it does there.

- data:

  The layer's data, as for
  [`ggplot2::geom_path()`](https://ggplot2.tidyverse.org/reference/geom_path.html).

- position:

  Position adjustment, as for
  [`ggplot2::geom_path()`](https://ggplot2.tidyverse.org/reference/geom_path.html).

- ...:

  Other arguments passed to the layer, as for
  [`ggplot2::geom_path()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
  – except `stat`, which is fixed at `"identity"`: a declared curve is
  always drawn from the author's own rates.

- auc:

  The area under each curve as the author computed it – with
  [`pROC::auc()`](https://rdrr.io/pkg/pROC/man/auc.html),
  [`yardstick::roc_auc()`](https://yardstick.tidymodels.org/reference/roc_auc.html)
  or by hand – announced in the description in place of the trapezoid
  rule over the drawn points. One number for a single curve; for
  several, a vector named by the groups' names, or unnamed and in the
  groups' sorted order. `NULL` (the default) measures the area from the
  points, which is what the trapezoid rule gives and what those
  functions compute for an empirical curve.

- na.rm:

  If `FALSE` (the default), rows with missing values are removed with a
  warning.

- show.legend:

  Whether this layer is included in the legends.

- inherit.aes:

  If `FALSE`, the plot's default aesthetics are not inherited.

## Value

A ggplot2 layer, to be added to a plot with `+`.

## What is asked of the data

`x` is the false positive rate and `y` the true positive rate, both
fractions of one, in the order the curve is to be walked – from (0, 0)
up, as `sklearn.metrics.roc_curve()` returns them, or from (1, 1) down,
as [`pROC::coords()`](https://rdrr.io/pkg/pROC/man/coords.html) does;
the area is measured over the points sorted by `x` either way. Several
classifiers on one chart are several groups, split by `colour`,
`linetype` or `group` as a multi-series line is, and each is announced
by its group's name.

## Curves maidr reads without a declaration

Two idioms name their axes after the ROC's own vocabulary, and are read
as ROC curves as they stand:
[`pROC::ggroc()`](https://rdrr.io/pkg/pROC/man/ggroc.html), whose
[`geom_line()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
maps `specificity` (or `1-specificity` with `legacy.axes = TRUE`)
against `sensitivity`, and
[`ggplot2::autoplot()`](https://ggplot2.tidyverse.org/reference/autoplot.html)
of a
[`yardstick::roc_curve()`](https://yardstick.tidymodels.org/reference/roc_curve.html),
whose
[`geom_path()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
maps `1 - specificity` against `sensitivity`. Where `x` is `specificity`
itself – pROC's default, drawn on a reversed axis – the announced rate
is `1 - specificity` and the axis is named so, because the height above
chance is measured against the false positive rate and a rate read off a
reversed axis would put every point on the wrong side of the diagonal.
Neither idiom carries thresholds or the area into the plot, so the area
is measured from the points and no threshold is announced; `maidr_roc()`
is how an author supplies both.

## Until the bundled maidr.js carries the trace

The `roc` trace shipped in maidr.js 4.9.0. While the copy this package
bundles is older (see `maidr:::MAIDR_VERSION`), a declared or detected
curve is read as a line, so that every chart keeps rendering; the
reading switches to `roc` with the next bundle update and no change to
the chart.

## What it costs not to declare

A
[`geom_line()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
of rates under any other column names keeps the line reading it has
today, deliberately: every chart already written keeps exactly the
reading it has.

## See also

[`maidr_gantt()`](https://r.maidr.ai/reference/maidr_gantt.md), the
other per-layer declaration;
[`save_html()`](https://r.maidr.ai/reference/save_html.md) and
[`show()`](https://r.maidr.ai/reference/show.md) for rendering the
declared chart

## Examples

``` r
if (requireNamespace("ggplot2", quietly = TRUE)) {
  curve <- data.frame(
    fpr = c(0, 0.05, 0.1, 0.2, 0.35, 0.6, 1),
    tpr = c(0, 0.55, 0.75, 0.86, 0.93, 0.98, 1),
    cutoff = c(1, 0.8, 0.6, 0.45, 0.3, 0.15, 0)
  )

  roc <- ggplot2::ggplot(curve) +
    maidr_roc(ggplot2::aes(x = fpr, y = tpr, threshold = cutoff)) +
    ggplot2::geom_abline(linetype = "dashed") +
    ggplot2::labs(x = "False positive rate", y = "True positive rate")

  # The same path written with `geom_path()` draws the same chart and is
  # read as a line: the rates, and none of what a ROC curve is read for.
  if (interactive()) {
    show(roc)
  }
}
```
