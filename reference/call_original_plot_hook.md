# Delegate to the stored original knitr plot hook

Falls back to knitr's markdown hook only when no original was stored.

## Usage

``` r
call_original_plot_hook(x, options)
```

## Arguments

- x:

  The plot file path from knitr

- options:

  Chunk options

## Value

The hook's output
