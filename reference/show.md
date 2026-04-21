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

  - `TRUE`: Use CDN (requires internet)

  - `FALSE`: Use local bundled files (works offline)

  - `NULL` (default): Auto-detect based on internet availability

- shiny:

  If TRUE, returns just the SVG content instead of full HTML document

- as_widget:

  If TRUE, returns an htmlwidget object instead of opening in browser

- ...:

  Additional arguments passed to internal functions

## Value

Invisible NULL. The plot is displayed in RStudio Viewer or browser as a
side effect.

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
