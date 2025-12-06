# Create MAIDR htmlwidget

Internal function that creates an interactive MAIDR widget from a ggplot
object. This is called internally by render_maidr() and should not be
called directly. Use maidr_output() and render_maidr() for Shiny
integration instead.

## Usage

``` r
maidr_widget(plot, width = NULL, height = NULL, element_id = NULL, ...)
```

## Arguments

- plot:

  A ggplot object to render as an interactive MAIDR widget

- width:

  The width of the widget in pixels or CSS units (default: NULL for
  auto-sizing)

- height:

  The height of the widget in pixels or CSS units (default: NULL for
  auto-sizing)

- element_id:

  A unique identifier for the widget (default: NULL for auto-generated)

- ...:

  Additional arguments passed to create_maidr_html()

## Value

An htmlwidget object that can be displayed in RStudio, Shiny, or saved
as HTML
