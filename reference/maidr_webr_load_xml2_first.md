# Load xml2 ahead of systemfonts under webR

webR links the packages' compiled code into one namespace of symbols,
and the first library to define a symbol is the one every later library
uses. The webR builds of both xml2 and systemfonts (which svglite loads)
carry a libxml2 of their own, and since xml2 was rebuilt on 2026-10-12
the two no longer agree. Loaded after systemfonts, xml2 runs against
systemfonts' copy, and parsing an SVG reads out of bounds: the wasm
aborts and R's worker dies (#380). Loaded first, xml2 keeps its own, and
systemfonts works with it.

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

[`show()`](https://r.maidr.ai/reference/show.md) and
[`save_html()`](https://r.maidr.ai/reference/save_html.md) no longer
parse with xml2 under webR at all
([`finish_svg_markup()`](https://r.maidr.ai/reference/finish_svg_markup.md),
\#388), so they work whichever loaded first. What still reads SVG with
xml2 there is the knitr path, so maidr loads xml2 itself as it loads,
and when systemfonts is already loaded it says so.
