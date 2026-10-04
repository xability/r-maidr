# maidr's knitr plot hook, over the hook it replaces

The replaced hook is kept in the closure rather than in a global, so a
document rendered from inside another one's chunk keeps its own, and a
hook a document wraps around maidr's cannot be called back into.

## Usage

``` r
maidr_knitr_plot_hook(original)
```

## Arguments

- original:

  The plot hook in place before

## Value

A plot hook calling
[`maidr_plot_hook()`](https://r.maidr.ai/reference/maidr_plot_hook.md)
