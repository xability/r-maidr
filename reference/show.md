# Display Interactive MAIDR Plot

Display a ggplot2 or Base R plot as an interactive, accessible
visualization using the MAIDR (Multimodal Access and Interactive Data
Representation) system.

## Usage

``` r
show(plot = NULL, use_cdn = NULL, shiny = FALSE, as_widget = FALSE, ...)
```

## Arguments

- plot:

  A ggplot2 object or NULL for Base R auto-detection

- use_cdn:

  Logical. Controls where MAIDR.js is loaded from:

  - `TRUE`: Use the jsDelivr CDN (requires internet), which loads the
    latest published MAIDR.js rather than the bundled copy. The version
    is looked up once per R session; pin one with
    `options(maidr.cdn_version = ...)`, see
    [`?"maidr-options"`](https://r.maidr.ai/reference/maidr-options.md).

  - `FALSE`: Use local bundled files (works offline, and makes no
    network request)

  - `NULL` (default): Use the bundled files, so the viewer works
    offline. With `as_widget = TRUE` the widget instead auto-detects
    internet availability and uses the CDN when online, as the knitr and
    Shiny paths do.

- shiny:

  If TRUE, returns just the SVG content instead of full HTML document

- as_widget:

  If TRUE, returns an htmlwidget object instead of opening in browser

- ...:

  Additional arguments passed to internal functions

## Value

Invisible NULL. The plot is displayed in RStudio Viewer or browser as a
side effect.

## Details

Attaching maidr masks
[`methods::show()`](https://rdrr.io/r/methods/show.html). An object that
is not a plot maidr renders – an S4 object, a vector, a data frame – is
handed to [`methods::show()`](https://rdrr.io/r/methods/show.html), so
it prints as it did before maidr was attached. In a script or a package,
call `maidr::show()` and
[`methods::show()`](https://rdrr.io/r/methods/show.html) by name;
[`?"base-r-wrappers"`](https://r.maidr.ai/reference/base-r-wrappers.md)
lists everything else attaching maidr masks.

## Examples

``` r
# ggplot2 bar chart
library(ggplot2)
p <- ggplot(mtcars, aes(x = factor(cyl), y = mpg)) +
  geom_bar(stat = "identity")
# \donttest{
maidr::show(p)
# }

# ggplot2 violin plot
p_violin <- ggplot(mtcars, aes(x = factor(cyl), y = mpg)) +
  geom_violin(fill = "lightblue", alpha = 0.7) +
  labs(title = "MPG by Cylinders", x = "Cylinders", y = "MPG")
# \donttest{
maidr::show(p_violin)
# }

# Base R example (requires interactive session for function patching)
if (interactive()) {
  barplot(c(10, 20, 30), names.arg = c("A", "B", "C"))
  maidr::show()
}
```
