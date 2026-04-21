# Create HTML document with dependencies

Create HTML document with dependencies

## Usage

``` r
create_html_document(svg_content, use_cdn = NULL)
```

## Arguments

- svg_content:

  Character vector of SVG content

- use_cdn:

  Logical. If \`TRUE\`, use CDN. If \`FALSE\`, use bundled files. If
  \`NULL\` (default), auto-detect based on internet availability.

## Value

An htmltools HTML document object
