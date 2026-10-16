# Load xml2 ahead of systemfonts under webR

webR links the packages' compiled code into one namespace of symbols,
and the first library to define a symbol is the one every later library
uses. The webR builds of both xml2 and systemfonts (which svglite loads)
carry a libxml2 of their own, and since xml2 was rebuilt on 2026-10-12
the two no longer agree. Loaded after systemfonts, xml2 runs against
systemfonts' copy, and parsing the chart's SVG reads out of bounds: the
wasm aborts, R's worker dies, and
[`show()`](https://r.maidr.ai/reference/show.md) never returns (#380).
Loaded first, xml2 keeps its own, and systemfonts works with it.

## Usage

``` r
maidr_webr_load_xml2_first(loaded = loadedNamespaces(), load = loadNamespace)
```

## Arguments

- loaded:

  The namespaces already loaded

- load:

  The function that loads a namespace

## Value

Invisibly, `FALSE` when systemfonts was loaded before xml2

## Details

maidr loads svglite and xml2 only when it draws, svglite first, so it
loads xml2 itself as it loads. When systemfonts is already loaded there
is nothing to do but say so.
