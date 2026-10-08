# Declare that a path layer draws a precision-recall curve

`maidr_pr_curve()` is
[`ggplot2::geom_path()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
with three things added: the author saying that the path is a
precision-recall curve, a `threshold` aesthetic for the decision
threshold each point was scored at, and the share of positives in the
data – the precision a classifier that guesses keeps at every recall,
which every point of the curve is read against. A declared layer is read
as a `pr_curve`: each point announced as its recall and precision, its
threshold and how far its precision sits above that baseline, with the
average precision of each curve and the point with the best F1 score in
the description. The same path drawn with
[`geom_path()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
or
[`geom_line()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
reads as a line, which says the rates and nothing a precision-recall
curve is drawn to say.

Nothing about the picture changes: the geom draws exactly what
[`geom_path()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
draws, and `threshold` reaches no mark.

The `pr_curve` layer type \[experimental\] is one of the experimental
plot types: it has not been through a user study, and its reading may
change without a deprecation period. See "Experimental Plot Types" in
the README.

## Usage

``` r
maidr_pr_curve(
  mapping = NULL,
  data = NULL,
  position = "identity",
  ...,
  prevalence = NULL,
  ap = NULL,
  na.rm = FALSE,
  show.legend = NA,
  inherit.aes = TRUE
)
```

## Arguments

- mapping:

  Aesthetics, as for
  [`ggplot2::geom_path()`](https://ggplot2.tidyverse.org/reference/geom_path.html):
  `x` (the recall) and `y` (the precision) are required, and `threshold`
  may name the decision threshold at each point. Every other path
  aesthetic (`colour`, `linetype`, `group`, ...) behaves exactly as it
  does there.

- data:

  The layer's data, as for
  [`ggplot2::geom_path()`](https://ggplot2.tidyverse.org/reference/geom_path.html).

- position:

  Position adjustment, as for
  [`ggplot2::geom_path()`](https://ggplot2.tidyverse.org/reference/geom_path.html).

- ...:

  Other arguments passed to the layer, as for
  [`ggplot2::geom_path()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
  – except `stat`, which is fixed at `"identity"`.

- prevalence:

  The share of positives in the data each curve was scored on, from 0 to
  1: the height of the chance baseline. One number for a single curve or
  for curves scored on the same data; for several scored on different
  data, a vector named by the groups' names, or unnamed and in the
  groups' sorted order. `NULL` (the default) reads the curve without a
  baseline.

- ap:

  The average precision of each curve as the author computed it – with
  [`yardstick::average_precision()`](https://yardstick.tidymodels.org/reference/average_precision.html),
  say – announced in the description in place of the step-wise area over
  the drawn points. Given as `prevalence` is. `NULL` (the default)
  measures it from the points.

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

`x` is the recall and `y` the precision, both fractions of one, in any
order: the average precision is measured over the points sorted by
recall. Several classifiers on one chart are several groups, split by
`colour`, `linetype` or `group` as a multi-series line is, and each is
announced by its group's name.

## Curves maidr reads without a declaration

[`ggplot2::autoplot()`](https://ggplot2.tidyverse.org/reference/autoplot.html)
of a
[`yardstick::pr_curve()`](https://yardstick.tidymodels.org/reference/pr_curve.html)
draws a
[`geom_path()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
that maps `recall` against `precision`, and is read as a
precision-recall curve as it stands – as is any
[`geom_line()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
or
[`geom_path()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
of columns named `recall` and `precision`. Such a curve carries neither
the thresholds nor the share of positives into the plot, so no threshold
is announced, the average precision is measured from the points, and the
points are not read against a baseline; `maidr_pr_curve()` is how an
author supplies them.

A Base R `plot(recall, precision, type = "l")` (or `type = "s"`) and a
lattice `xyplot(precision ~ recall, type = "l")` are read the same way
when their axes are titled `Recall` and `Precision` – which both take
from the variables' names unless `xlab` and `ylab` say otherwise – and
every value is a fraction of one.

## Until the bundled maidr.js carries the trace

The `pr_curve` trace shipped in maidr.js 4.14.0. While the copy this
package bundles is older (see `maidr:::MAIDR_VERSION`), a declared or
detected curve is read as a line, so that every chart keeps rendering.

## See also

[`maidr_roc()`](https://r.maidr.ai/reference/maidr_roc.md), the ROC
curve's declaration;
[`save_html()`](https://r.maidr.ai/reference/save_html.md) and
[`show()`](https://r.maidr.ai/reference/show.md) for rendering the
declared chart

## Examples

``` r
if (requireNamespace("ggplot2", quietly = TRUE)) {
  curve <- data.frame(
    recall = c(0, 0.2, 0.4, 0.6, 0.8, 1),
    precision = c(1, 1, 0.89, 0.8, 0.62, 0.3),
    cutoff = c(1, 0.9, 0.75, 0.6, 0.4, 0)
  )

  pr <- ggplot2::ggplot(curve) +
    maidr_pr_curve(
      ggplot2::aes(x = recall, y = precision, threshold = cutoff),
      prevalence = 0.3
    ) +
    ggplot2::geom_hline(yintercept = 0.3, linetype = "dashed") +
    ggplot2::labs(x = "Recall", y = "Precision")

  if (interactive()) {
    show(pr)
  }
}
```
