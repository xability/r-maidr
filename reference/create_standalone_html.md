# Create self-contained HTML for iframe embedding

Generates a complete standalone HTML document with MAIDR.js that can be
embedded in an iframe for isolation. Each iframe gets its own JavaScript
context, avoiding MAIDR.js singleton pattern issues with multiple plots.

## Usage

``` r
create_standalone_html(svg_content)
```

## Arguments

- svg_content:

  Character vector of SVG content with maidr-data attribute

## Value

Character string of complete HTML document
