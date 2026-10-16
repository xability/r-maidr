# Declare a Kaplan-Meier curve

`maidr_survival()` draws Kaplan-Meier survival curves – one per stratum,
each held level until an event drops it – and declares them as such, so
that maidr reads them as a `survival` layer: each time announced with
its survival estimate and, when the band is drawn, its confidence
interval, the times a subject was censored marked so a reader can step
between them with the rotor, and the median survival of each curve in
the description. The same staircase drawn with
[`geom_step()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
reads as a step chart, which announces the levels and nothing of the
censoring that says how much of the curve the data still supports.

Give it a
[`survival::survfit`](https://rdrr.io/pkg/survival/man/survfit.html)
object and it draws the curves
[`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) of that
object would: `ggplot() + maidr_survival(fit)`. Give it data and
aesthetics and it draws them as they are, as any geom does.

The `survival` layer type \[experimental\] is one of the experimental
plot types: it has not been through a user study, and its reading may
change without a deprecation period. See "Experimental Plot Types" in
the README.

## Usage

``` r
maidr_survival(
  mapping = NULL,
  data = NULL,
  position = "identity",
  ...,
  conf.int = FALSE,
  conf.int.alpha = 0.2,
  censor = TRUE,
  censor.shape = 3,
  censor.size = 3,
  na.rm = FALSE,
  show.legend = NA,
  inherit.aes = TRUE
)
```

## Arguments

- mapping:

  Aesthetics, as for
  [`ggplot2::geom_step()`](https://ggplot2.tidyverse.org/reference/geom_path.html):
  `x` (the time) and `y` (the survival estimate) are required, and
  `ymin`, `ymax` and `censored` may be mapped as described in Details.
  Or a `survfit` object, drawn as described there.

- data:

  The layer's data, as for
  [`ggplot2::geom_step()`](https://ggplot2.tidyverse.org/reference/geom_path.html),
  or a `survfit` object. When `mapping` is the `survfit` object, `data`
  may be further aesthetics.

- position:

  Position adjustment, as for
  [`ggplot2::geom_step()`](https://ggplot2.tidyverse.org/reference/geom_path.html).

- ...:

  Other arguments passed to the layer, such as `linewidth` or a fixed
  `colour` – except `stat`, which is fixed at `"identity"`.

- conf.int:

  Whether to draw the confidence band from `ymin` and `ymax` (from the
  object's own bounds, for a `survfit`), and read it as each point's
  `yMin` and `yMax`. `FALSE` by default.

- conf.int.alpha:

  The band's opacity.

- censor:

  Whether to draw a mark at each censored time. Censoring is read either
  way.

- censor.shape, censor.size:

  The marks' plotting character and size, as `shape` and `size` are
  given to
  [`ggplot2::geom_point()`](https://ggplot2.tidyverse.org/reference/geom_point.html).

- na.rm:

  If `FALSE` (the default), rows with missing values are removed with a
  warning.

- show.legend:

  Whether this layer is included in the legends.

- inherit.aes:

  If `FALSE`, the plot's default aesthetics are not inherited. Always
  `FALSE` for a `survfit` object.

## Value

A ggplot2 layer, to be added to a plot with `+`.

## From a `survfit` object

The curves start at the origin
[`survival::survfit0()`](https://rdrr.io/pkg/survival/man/survfit0.html)
adds, as [`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
starts them, and run to each stratum's last time. The layer draws from a
data frame of its own, with the columns `Time`, `Survival probability`,
`lower`, `upper`, `censored` and, for a fit with strata, `Stratum`,
which are what the axes and the legend are titled by; map further
aesthetics onto them, `maidr_survival(fit, aes(linetype = Stratum))`,
and retitle with
[`ggplot2::labs()`](https://ggplot2.tidyverse.org/reference/labs.html).
The plot's own aesthetics are not inherited. A multi-state fit, or one
with several curves per stratum (`survfit()` of a Cox model over several
new subjects), is an error: neither is one survival curve per stratum.

## From data

`x` is the time and `y` the survival estimate, one row per time at which
the estimate is reported, and the strata are groups, split by `colour`,
`linetype` or `group` as the series of a line chart are. `censored`
marks the times a subject left the study without the event: `TRUE`, or a
count greater than zero such as a `survfit` summary's `n.censor`. `ymin`
and `ymax` are the band's bounds at each time, drawn and read only with
`conf.int = TRUE`.

## What is read

One series per stratum, each point a row: the time, the estimate,
`censored` where the row is censored, and, when the band is drawn,
`yMin` and `yMax`. Censoring is read whether or not the marks are drawn,
as it is from a Base R plot: it is part of the estimate, not of its
decoration.

## survminer

A figure from
[`survminer::ggsurvplot()`](https://rdrr.io/pkg/survminer/man/ggsurvplot.html)
is read the same way when it is handed to
[`show()`](https://r.maidr.ai/reference/show.md) or
[`save_html()`](https://r.maidr.ai/reference/save_html.md) as it stands:
its curve, band and censoring marks are redrawn as one
`maidr_survival()` layer from the data the figure carries. The risk
table, and a figure whose curve is not a survival probability
(`fun = "event"` or `"cumhaz"`), are not read; the first is left out,
the second keeps the reading
[`geom_step()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
has.

## See also

[`maidr_roc()`](https://r.maidr.ai/reference/maidr_roc.md) and
[`maidr_volcano()`](https://r.maidr.ai/reference/maidr_volcano.md), the
other declarations;
[`save_html()`](https://r.maidr.ai/reference/save_html.md) and
[`show()`](https://r.maidr.ai/reference/show.md) for rendering the
declared chart

## Examples

``` r
if (requireNamespace("ggplot2", quietly = TRUE) &&
  requireNamespace("survival", quietly = TRUE)) {
  fit <- survival::survfit(
    survival::Surv(time, status) ~ sex,
    data = survival::lung
  )

  km <- ggplot2::ggplot() +
    maidr_survival(fit, conf.int = TRUE) +
    ggplot2::labs(x = "Days", title = "Survival by sex")

  # The same curves drawn with `geom_step()` read as a step chart: the
  # levels, and nothing of who was censored.
  if (interactive()) {
    show(km)
  }
}
```
