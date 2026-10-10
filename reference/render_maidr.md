# Render MAIDR Plot in Shiny Server

Creates a Shiny render function for MAIDR widgets using htmlwidgets.
This provides automatic dependency injection and robust JavaScript
initialization.

## Usage

``` r
render_maidr(
  expr,
  env = parent.frame(),
  quoted = FALSE,
  fig_width = NULL,
  fig_height = NULL,
  hover_mode = NULL
)
```

## Arguments

- expr:

  An expression that draws a plot. Either a ggplot object or a lattice
  (trellis) object, returned rather than printed, or Base R plotting
  calls – their return values differ
  ([`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) returns
  NULL, [`barplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  returns bar midpoints) and are ignored; what counts is whether the
  expression drew. An expression that draws nothing and returns NULL
  renders nothing, per Shiny convention.

- env:

  The environment in which to evaluate expr

- quoted:

  Is expr a quoted expression

- fig_width, fig_height:

  The size to draw the chart at, in inches, as `width` and `height` set
  it in [`show()`](https://r.maidr.ai/reference/show.md): each a single
  positive number no larger than 50, or `NULL` (the default) for 7 x 5
  in, 12 x 6 in for a candlestick chart. They are not the size of the
  output on the page, which
  [`maidr_output()`](https://r.maidr.ai/reference/maidr_output.md)'s
  `width` and `height` set: a chart wider than its output shrinks to fit
  it. Nothing sizes the chart to its output; the size is the one given
  here.

- hover_mode:

  How the pointer moves the reader through the chart, as in
  [`show()`](https://r.maidr.ai/reference/show.md): `"pointermove"`,
  `"click"` or `"off"`, or `NULL` (the default) for
  `getOption("maidr.hover_mode")`, and for the reader's own setting when
  that is unset.

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

    # Drawn 10 inches wide and 4 high
    output$wide <- render_maidr(
      {
        ggplot(mtcars, aes(x = wt, y = mpg)) +
          geom_point()
      },
      fig_width = 10,
      fig_height = 4
    )

    # Only a click moves the reader through this one
    output$quiet <- render_maidr(
      {
        ggplot(mtcars, aes(x = wt, y = mpg)) +
          geom_point()
      },
      hover_mode = "click"
    )
  }
}
```
