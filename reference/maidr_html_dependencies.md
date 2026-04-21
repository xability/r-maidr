# Register JS/CSS dependencies for maidr with auto-detection

Creates HTML dependencies for MAIDR JavaScript and CSS files. Behavior
is controlled by the \`use_cdn\` parameter: - If \`TRUE\`: Use CDN
(requires internet) - If \`FALSE\`: Use local bundled files (works
offline) - If \`NULL\` (default): Auto-detect based on internet
availability

## Usage

``` r
maidr_html_dependencies(use_cdn = NULL)
```

## Arguments

- use_cdn:

  Logical. If \`TRUE\`, use CDN. If \`FALSE\`, use bundled files. If
  \`NULL\` (default), auto-detect based on internet availability.

## Value

A list containing one htmlDependency object
