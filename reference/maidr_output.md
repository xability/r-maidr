# MAIDR Output Container for Shiny UI

Creates a Shiny output container for MAIDR widgets using htmlwidgets.
This provides automatic dependency injection and robust JavaScript
initialization.

## Usage

``` r
maidr_output(output_id, width = "100%", height = "400px")
```

## Arguments

- output_id:

  The output variable to read the plot from

- width:

  The width of the plot container (default: "100percent")

- height:

  The height of the plot container (default: "400px")

## Value

A Shiny widget output function for use in UI

## Examples

``` r
if (interactive()) {
  library(shiny)
  ui <- fluidPage(maidr_output("myplot"))
}
```
