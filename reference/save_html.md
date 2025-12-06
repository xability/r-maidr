# Save Interactive Plot as HTML File

Save a ggplot2 or Base R plot as a standalone HTML file with interactive
MAIDR accessibility features.

## Usage

``` r
save_html(plot = NULL, file = "plot.html", ...)
```

## Arguments

- plot:

  A ggplot2 object or NULL for Base R auto-detection

- file:

  File path where to save the HTML file (e.g., "plot.html")

- ...:

  Additional arguments passed to internal functions

## Value

The file path where the HTML was saved (invisibly)

## Examples

``` r
# ggplot2 example
library(ggplot2)
p <- ggplot(mtcars, aes(x = factor(cyl), y = mpg)) +
  geom_bar(stat = "identity")
if (FALSE) { # \dontrun{
maidr::save_html(p, "myplot.html")
} # }

# Base R example
if (FALSE) { # \dontrun{
barplot(c(10, 20, 30), names.arg = c("A", "B", "C"))
maidr::save_html(file = "barplot.html")
} # }
```
