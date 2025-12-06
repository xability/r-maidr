# MAIDR Widget Output for Shiny UI (Internal Alternative)

Internal alternative Shiny UI function. This provides the same
functionality as maidr_output() but is no longer recommended for direct
use. Use maidr_output() and render_maidr() instead for better
consistency.

## Usage

``` r
maidr_widget_output(output_id, width = "100%", height = "400px")
```

## Arguments

- output_id:

  The output variable to read the widget from

- width:

  The width of the widget (default: "100percent")

- height:

  The height of the widget (default: "400px")

## Value

A Shiny widget output function for use in UI
