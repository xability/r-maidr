# Say, as pheatmap is attached, that it now masks maidr's pheatmap()

The attach hook for 'pheatmap'. Attached after maidr, a bare
[`pheatmap()`](https://r.maidr.ai/reference/pheatmap.md) reaches
pheatmap's own function, and maidr can read its values only from the
colours.

## Usage

``` r
.maidr_pheatmap_attach_hook(...)
```

## Arguments

- ...:

  Unused; what the hook is called with

## Value

NULL (invisible)
