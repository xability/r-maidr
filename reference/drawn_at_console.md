# Whether a chart drawn now is drawn at the console

In an interactive session, and neither while knitr runs, which makes the
chart a chunk's figure, nor inside a Shiny render, which draws it for
its output.

## Usage

``` r
drawn_at_console()
```

## Value

`TRUE` for a chart drawn at the console.
