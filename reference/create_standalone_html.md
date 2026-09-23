# Create self-contained HTML for iframe embedding

Generates a complete standalone HTML document with MAIDR.js that can be
embedded in an iframe for isolation. Each iframe gets its own JavaScript
context, avoiding MAIDR.js singleton pattern issues with multiple plots.

## Usage

``` r
create_standalone_html(svg_content, use_cdn = NULL, page_fallback = FALSE)
```

## Arguments

- svg_content:

  Character vector of SVG content with maidr-data attribute

- use_cdn:

  Logical. If `TRUE`, use CDN. If `FALSE`, use bundled files. If `NULL`
  (default), auto-detect based on internet availability.

- page_fallback:

  Logical. When the CDN is used, fall back to the copy of the bundle the
  embedding page carries if the CDN load fails. Set by the knitr paths,
  which add that copy to the document with
  [`maidr_page_bundle_dependency()`](https://r.maidr.ai/reference/maidr_page_bundle_dependency.md),
  and by
  [`maidr_widget()`](https://r.maidr.ai/reference/maidr_widget.md),
  which declares the same dependency on the widget.

## Value

Character string of complete HTML document
