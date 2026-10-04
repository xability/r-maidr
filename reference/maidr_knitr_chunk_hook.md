# maidr's knitr chunk hook, over the hook it replaces

Runs once a chunk's output is complete, after the hook it replaces. A
chunk whose output holds an inline chart declares the page dependencies
([`maidr_knitr_dependencies()`](https://r.maidr.ai/reference/maidr_knitr_dependencies.md))
through
[`knitr::knit_meta_add()`](https://rdrr.io/pkg/knitr/man/knit_meta.html),
whichever way the chart got there: a figure, or `cat(knit_print(p))` in
a `results = "asis"` loop, which drops the meta a `knit_asis` object
carries.

## Usage

``` r
maidr_knitr_chunk_hook(previous)
```

## Arguments

- previous:

  The chunk hook in place before

## Value

A chunk hook

## Details

A chunk cached with `cache = TRUE` is not run again, and only what knitr
cached of it comes back: its output, and the meta its `knit_asis` output
carried, which knitr keeps under `.<hash>_meta` in `knit_global()` until
it saves the chunk – just after this hook. The dependencies are added
there too, or a later render would bring the chart back without
maidr.js. The name is knitr's (`knitr:::cache_meta_name()`), and a test
checks it has not changed.
