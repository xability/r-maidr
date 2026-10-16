# Declare that a point layer draws a Manhattan plot

`maidr_manhattan()` is
[`ggplot2::geom_point()`](https://ggplot2.tidyverse.org/reference/geom_point.html)
with three things added: the author saying that the points are a
Manhattan plot, the significance threshold the chart is read against,
and two aesthetics for what each point is – `label` (the SNP or variant)
and `region` (its chromosome). A declared layer is read as a
`manhattan`: the description says how many points clear the threshold
and names them, a rotor mode steps through only those points, and every
point is announced with its label and chromosome. The same points drawn
with
[`geom_point()`](https://ggplot2.tidyverse.org/reference/geom_point.html)
read as a scatter of tens of thousands of positions, walked one at a
time.

Nothing about the picture changes: the geom draws exactly what
[`geom_point()`](https://ggplot2.tidyverse.org/reference/geom_point.html)
draws, and neither `label` nor `region` reaches a mark.

The `manhattan` layer type \[experimental\] is one of the experimental
plot types: it has not been through a user study, and its reading may
change without a deprecation period. See "Experimental Plot Types" in
the README.

## Usage

``` r
maidr_manhattan(
  mapping = NULL,
  data = NULL,
  position = "identity",
  ...,
  significance,
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
  `x` (the position along the genome) and `y` (the significance, such as
  -log10 of the p value) are required. `label` may name each point (the
  SNP) and `region` its chromosome; both are announced with the point.
  Every other point aesthetic (`colour`, `size`, `alpha`, ...) behaves
  exactly as it does there.

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

## Details

`x` is the position along the genome – usually each variant's position
offset by the length of the chromosomes before it, with the axis
labelled by chromosome through
`scale_x_continuous(breaks = , labels = )` – and `y` the significance. A
point is significant when its y is at or above `significance` (at or
below it with `direction = "below"`), in the units y is announced in:
`significance = -log10(5e-8)` for genome-wide significance on a
-log10(p) axis. There is no default, for the reason
[`maidr_volcano()`](https://r.maidr.ai/reference/maidr_volcano.md)
gives.

## See also

[`maidr_volcano()`](https://r.maidr.ai/reference/maidr_volcano.md) for a
volcano plot; [`save_html()`](https://r.maidr.ai/reference/save_html.md)
and [`show()`](https://r.maidr.ai/reference/show.md) for rendering the
declared chart

## Examples

``` r
if (requireNamespace("ggplot2", quietly = TRUE)) {
  snps <- data.frame(
    snp = paste0("rs", 1:8),
    chr = rep(c("1", "2"), each = 4),
    pos = c(1, 2, 3, 4, 6, 7, 8, 9),
    p = c(0.3, 2e-9, 0.01, 0.6, 0.05, 0.8, 4e-10, 0.2)
  )

  manhattan <- ggplot2::ggplot(
    snps,
    ggplot2::aes(x = pos, y = -log10(p), colour = chr)
  ) +
    maidr_manhattan(
      ggplot2::aes(label = snp, region = chr),
      significance = -log10(5e-8)
    ) +
    ggplot2::geom_hline(yintercept = -log10(5e-8), linetype = "dashed") +
    ggplot2::scale_x_continuous(breaks = c(2.5, 7.5), labels = c("1", "2")) +
    ggplot2::labs(x = "Chromosome", y = "-log10 p")

  if (interactive()) {
    show(manhattan)
  }
}
```
