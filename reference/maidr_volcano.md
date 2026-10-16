# Declare that a point layer draws a volcano plot

`maidr_volcano()` is
[`ggplot2::geom_point()`](https://ggplot2.tidyverse.org/reference/geom_point.html)
with three things added: the author saying that the points are a volcano
plot, the significance threshold the chart is read against, and two
aesthetics for what each point is – `label` (the gene) and `region` (any
grouping announced alongside it, such as up- or down-regulated). A
declared layer is read as a `volcano`: the description says how many
points clear the threshold and names them, a rotor mode steps through
only those points, and every point is announced with its label and
region. The same points drawn with
[`geom_point()`](https://ggplot2.tidyverse.org/reference/geom_point.html)
read as a scatter, which says two coordinates and withholds which gene
they belong to.

Nothing about the picture changes: the geom draws exactly what
[`geom_point()`](https://ggplot2.tidyverse.org/reference/geom_point.html)
draws, and neither `label` nor `region` reaches a mark. Draw the
threshold lines yourself, with
[`geom_hline()`](https://ggplot2.tidyverse.org/reference/geom_abline.html)
and
[`geom_vline()`](https://ggplot2.tidyverse.org/reference/geom_abline.html);
maidr leaves reference lines out of the reading.

The `volcano` layer type \[experimental\] is one of the experimental
plot types: it has not been through a user study, and its reading may
change without a deprecation period. See "Experimental Plot Types" in
the README.

## Usage

``` r
maidr_volcano(
  mapping = NULL,
  data = NULL,
  position = "identity",
  ...,
  significance,
  effect = NULL,
  direction = c("above", "below"),
  na.rm = FALSE,
  show.legend = NA,
  inherit.aes = TRUE
)
```

## Arguments

- mapping:

  Aesthetics, as for
  [`ggplot2::geom_point()`](https://ggplot2.tidyverse.org/reference/geom_point.html):
  `x` (the effect size, such as a log2 fold change) and `y` (the
  significance, such as -log10 of the p value) are required. `label` may
  name each point (the gene) and `region` the group it belongs to; both
  are announced with the point. Every other point aesthetic (`colour`,
  `size`, `alpha`, ...) behaves exactly as it does there.

- data:

  The layer's data, as for
  [`ggplot2::geom_point()`](https://ggplot2.tidyverse.org/reference/geom_point.html).

- position:

  Position adjustment, as for
  [`ggplot2::geom_point()`](https://ggplot2.tidyverse.org/reference/geom_point.html).

- ...:

  Other arguments passed to the layer, as for
  [`ggplot2::geom_point()`](https://ggplot2.tidyverse.org/reference/geom_point.html)
  – except `stat`, which is fixed at `"identity"`: a declared layer is
  always drawn from the author's own points.

- significance:

  The significance cutoff on the y axis, one number in the units y is
  announced in. Required.

- effect:

  The effect-size cutoff, applied to the magnitude of x, or `NULL` (the
  default) for none.

- direction:

  Which side of `significance` the significant points are on: `"above"`
  (the default) for a -log10(p) axis, `"below"` for a raw p value.

- na.rm:

  If `FALSE` (the default), rows with missing values are removed with a
  warning.

- show.legend:

  Whether this layer is included in the legends.

- inherit.aes:

  If `FALSE`, the plot's default aesthetics are not inherited.

## Value

A ggplot2 layer, to be added to a plot with `+`.

## The threshold is stated, never guessed

A point is significant when its y is at or above `significance` (at or
below it with `direction = "below"`) and, when `effect` is given, the
magnitude of its x is at least `effect` – a fold change of -2 is as
large an effect as one of +2. Both are in the units the axes are
announced in, which are the data's own: `significance = -log10(0.05)`
for `y = -log10(pvalue)`, and `significance = 0.05, direction = "below"`
for a raw p value, even on a log-scaled y axis, whose points are
announced as the p values they are.

There is no default, because these charts sit on transformed axes whose
conventions differ by field and by tool, and a line drawn in the wrong
place would put every point on the wrong side of it without saying so.

## See also

[`maidr_manhattan()`](https://r.maidr.ai/reference/maidr_manhattan.md)
for a Manhattan plot;
[`save_html()`](https://r.maidr.ai/reference/save_html.md) and
[`show()`](https://r.maidr.ai/reference/show.md) for rendering the
declared chart

## Examples

``` r
if (requireNamespace("ggplot2", quietly = TRUE)) {
  genes <- data.frame(
    gene = c("TP53", "MYC", "EGFR", "BRCA1", "KRAS", "PTEN", "GAPDH"),
    log2fc = c(2.8, -3.1, 1.6, -0.4, 0.3, -2.2, 0.1),
    padj = c(1e-8, 1e-6, 0.02, 0.4, 0.7, 1e-4, 0.9)
  )

  volcano <- ggplot2::ggplot(
    genes,
    ggplot2::aes(x = log2fc, y = -log10(padj))
  ) +
    maidr_volcano(
      ggplot2::aes(label = gene),
      significance = -log10(0.05),
      effect = 1
    ) +
    ggplot2::geom_hline(yintercept = -log10(0.05), linetype = "dashed") +
    ggplot2::geom_vline(xintercept = c(-1, 1), linetype = "dashed") +
    ggplot2::labs(x = "log2 fold change", y = "-log10 adjusted p")

  if (interactive()) {
    show(volcano)
  }
}
```
