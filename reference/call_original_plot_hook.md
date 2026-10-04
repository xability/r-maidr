# Delegate to the plot hook maidr's was installed over

Falls back to knitr's markdown hook only when there is none.

## Usage

``` r
call_original_plot_hook(x, options, original = NULL)
```

## Arguments

- x:

  The plot file path from knitr

- options:

  Chunk options

- original:

  The plot hook maidr's was installed over

## Value

The hook's output
