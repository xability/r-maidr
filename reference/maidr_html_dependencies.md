# Register JS/CSS dependencies for maidr

Creates HTML dependencies for MAIDR JavaScript and CSS files. Behavior
is controlled by the \`use_cdn\` parameter: - If \`TRUE\`: Use CDN
(requires internet) - If \`FALSE\` (default): Use local bundled files
(works offline) - If \`NULL\`: Same as \`FALSE\` — use local bundled
files

## Usage

``` r
maidr_html_dependencies(use_cdn = NULL)
```

## Arguments

- use_cdn:

  Logical. If \`TRUE\`, use CDN. If \`FALSE\` or \`NULL\` (default), use
  bundled files.

## Value

A list containing one htmlDependency object

## Details

We default to local bundled assets for deterministic rendering.
Previously we auto-detected via \`curl::has_internet()\`; when internet
was available the CDN path was selected, which combined with a
(now-fixed) malformed nested-\`\<html\>\` HTML scaffold caused base R
chart SVGs to render squished in the upper-left of the viewport. Local
assets match the ggplot path that has always rendered correctly. Users
who want CDN can still pass \`use_cdn = TRUE\` explicitly.
