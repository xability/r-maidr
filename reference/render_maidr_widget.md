# Render MAIDR Widget in Shiny Server (Internal Alternative)

Internal alternative Shiny server function. This provides the same
functionality as render_maidr() but is no longer recommended for direct
use. Use maidr_output() and render_maidr() instead for better
consistency.

## Usage

``` r
render_maidr_widget(expr, env = parent.frame(), quoted = FALSE)
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
