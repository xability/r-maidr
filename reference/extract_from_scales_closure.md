# Extract Format Configuration from scales Package Closure

Inspects the closure environment of a scales label function to extract
formatting parameters. This allows users to use scales:: functions
directly without needing maidr:: wrappers.

## Usage

``` r
extract_from_scales_closure(label_func)
```

## Arguments

- label_func:

  A label function (e.g., from scales::label_dollar)

## Value

Format configuration list or NULL
