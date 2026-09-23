# Wrap a chart in its iframe for a knitted document

Online, the frame loads maidr.js from the CDN, and the document is given
its own copy of the bundle
([`maidr_page_bundle_dependency()`](https://r.maidr.ai/reference/maidr_page_bundle_dependency.md))
for the frame to fall back on. The frame's document sits in a `srcdoc`
attribute, where R Markdown's `self_contained` and Quarto's
`embed-resources` cannot reach its `<script src>`; the copy is what they
embed instead, once per document however many charts it has, so a
self-contained document's charts work offline. Offline at render time,
each frame carries the bundle inline, as before.

## Usage

``` r
create_knitr_iframe(content)
```

## Arguments

- content:

  The chart's SVG content, from
  [`create_maidr_html()`](https://r.maidr.ai/reference/create_maidr_html.md)

## Value

Character string of iframe HTML
