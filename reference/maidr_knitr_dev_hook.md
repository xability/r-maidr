# maidr's `dev` option hook, over the hook it replaces

knitr runs it at the start of every chunk, before the chunk's device
opens, after the hook it replaces (flexdashboard has one). It drops what
was recorded on devices that have closed since, and the tokens of pages
replayed for no figure – a chunk whose plot hook never ran
(`fig.show = "hide"`, an error) would otherwise leave them to the next
chunk, which knitr gives the same device number – and picks the chunk's
device
([`maidr_chunk_device()`](https://r.maidr.ai/reference/maidr_chunk_device.md)).
The device of a chunk that is knitting a child document is still open,
and what it recorded is kept. The hook does nothing in a knit maidr was
not installed into: a plain
[`knitr::knit()`](https://rdrr.io/pkg/knitr/man/knit.html) leaves it
behind.

## Usage

``` r
maidr_knitr_dev_hook(previous)
```

## Arguments

- previous:

  The `dev` option hook in place before

## Value

An option hook

## Details

flexdashboard's hook makes a `png` figure two, the second drawn for
phones (`flexdashboard_phone_figures()`), and leaves any other device
alone. A vector figure needs no copy for phones, so where the chunk was
given knitr's default, its hook is run again on svglite instead.
