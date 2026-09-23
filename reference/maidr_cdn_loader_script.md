# Script that loads maidr.js from the CDN, falling back to the page's copy

Goes into a chart frame's `srcdoc` in place of a plain CDN `<script>`.
When the CDN load fails – offline, blocked – it looks in the parent
document for the copy
[`maidr_page_bundle_dependency()`](https://r.maidr.ai/reference/maidr_page_bundle_dependency.md)
put there. A `srcdoc` frame shares its parent's origin, so it can read
it.

## Usage

``` r
maidr_cdn_loader_script(cdn_js_url)
```

## Arguments

- cdn_js_url:

  URL of maidr.js on the CDN

## Value

Character string holding a `<script>` element

## Details

The copy arrives in one of two shapes, and both are handled: a `src`
(the `_files` folder, or a `data:` URL) or inline text, which is what
pandoc turns a script into when it embeds it. maidr.js initialises
itself when it runs, so nothing is called once it has loaded. KaTeX,
which it fetches only when an AI response carries maths, is pointed at
the page's copy through `window.maidrMathStylesheetUrl`, or added as a
`<style>` when inline.
