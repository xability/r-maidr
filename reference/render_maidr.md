# Render MAIDR Plot in Shiny Server

Creates a Shiny render function for MAIDR widgets using htmlwidgets.
This provides automatic dependency injection and robust JavaScript
initialization.

## Usage

``` r
render_maidr(expr, env = parent.frame(), quoted = FALSE)
```

## Arguments

- expr:

  An expression that returns a ggplot object

- env:

  The environment in which to evaluate expr

- quoted:

  Is expr a quoted expression

## Value

A Shiny render function for use in server

## Examples

``` r
if (interactive()) {
  library(shiny)
  library(ggplot2)
  server <- function(input, output) {
    output$myplot <- render_maidr({
      ggplot(mtcars, aes(x = factor(cyl), y = mpg)) +
        geom_bar(stat = "identity")
    })
  }
}
```
