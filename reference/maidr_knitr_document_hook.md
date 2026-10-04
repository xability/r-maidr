# maidr's knitr `document` hook, over the hook it replaces

knitr calls it once a document's chunks have all run, and their devices
have closed. At the end of the knit the session started – not of a child
document, nor of one rendered from inside another's chunk, whose knit
goes on – it takes maidr's integration out
([`uninstall_knitr_integration()`](https://r.maidr.ai/reference/uninstall_knitr_integration.md))
and drops what the knit's chunks recorded
([`drop_stale_device_storage()`](https://r.maidr.ai/reference/drop_stale_device_storage.md)):
the last chunk's Base R calls would otherwise be kept under its device's
number, which the next device the session opens is given, and read into
that device's chart. The next render installs maidr again from its first
chart, as a second render in a session always has.

## Usage

``` r
maidr_knitr_document_hook(previous)
```

## Arguments

- previous:

  The `document` hook in place before

## Value

A `document` hook
