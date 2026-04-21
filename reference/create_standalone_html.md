# Create self-contained HTML for iframe embedding

Generates a complete standalone HTML document with MAIDR.js that can be
embedded in an iframe for isolation. Each iframe gets its own JavaScript
context, avoiding MAIDR.js singleton pattern issues with multiple plots.

## Usage

``` r
create_standalone_html(svg_content, use_cdn = NULL)
```

## Arguments

- svg_content:

  Character vector of SVG content with maidr-data attribute

- use_cdn:

  Logical. If \`TRUE\`, use CDN. If \`FALSE\`, use bundled files. If
  \`NULL\` (default), auto-detect based on internet availability.

## Value

Character string of complete HTML document
