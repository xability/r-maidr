# The bundle a knitted document carries for its charts

The knitr paths put each chart in a `srcdoc` iframe whose `<script>`
loads maidr.js from the CDN. That document lives in an attribute, where
neither pandoc's `--embed-resources` (R Markdown's `self_contained`,
Quarto's `embed-resources`) nor anything else that rewrites a page's
resources can see it, so a self-contained document still needed the
network to make its charts accessible, and offline they were plain
pictures.

## Usage

``` r
maidr_page_bundle_dependency()
```

## Value

A single htmltools::htmlDependency()

## Details

This dependency gives the document one copy of the bundle that the
tooling does see: linked from the `_files` folder, or embedded into the
page when the document is self-contained. Its scripts are of a type no
browser runs, so the page itself is left alone; a chart frame whose CDN
load fails reads the copy from its parent instead (see
[`maidr_cdn_loader_script()`](https://r.maidr.ai/reference/maidr_cdn_loader_script.md)).
