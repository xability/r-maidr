# Create inline image HTML for non-iframe rendering

Creates a simple img tag for fallback/non-HTML output. Used when we
don't need iframe isolation (unsupported plots in HTML, or any plot in
PDF/EPUB output).

## Usage

``` r
create_inline_image(plot = NULL, width = "100%", height = "auto")
```

## Arguments

- plot:

  A ggplot object or NULL for Base R

- width:

  Width for the image container

- height:

  Height for the image container

## Value

Character string of HTML with img tag
