# The local SDK dependency, when a document going offline should carry one

Applies only to `use_cdn = FALSE`: that is the document whose reader has
no network, and the one whose `lib/` folder already travels with it. A
session that names its own copy by URL keeps that – either URL option,
set alone or together, wins – and one that never downloaded the SDK gets
exactly what it did before.

## Usage

``` r
maidr_dotpad_local_dependency(use_cdn = NULL)
```

## Arguments

- use_cdn:

  The document's `use_cdn`, with `NULL` meaning `FALSE`

## Value

An
[`htmltools::htmlDependency()`](https://rstudio.github.io/htmltools/reference/htmlDependency.html),
or `NULL`

## Details

Either option, not only the module's. Both this dependency and the URL
one write the same globals, and the later `head` wins in the browser, so
a document carrying both with only the engine's URL configured would
load the module from `lib/` and the engine from that URL: the offline
copy's worst half, and the network dependency `use_cdn = FALSE` exists
to remove.
