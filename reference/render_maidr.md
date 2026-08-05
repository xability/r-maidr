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

  An expression that draws a plot. Either a ggplot object, or Base R
  plotting calls – their return values differ
  ([`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) returns
  NULL, [`barplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  returns bar midpoints) and are ignored; what counts is whether the
  expression drew. An expression that draws nothing and returns NULL
  renders nothing, per Shiny convention.

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
