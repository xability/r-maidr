# Get `<style>`/`<script>` tags with the bundled assets inlined

Reads the bundled maidr.js/maidr-math.css once per session and caches
the assembled tags.

## Usage

``` r
maidr_inline_asset_tags()
```

## Value

A named list with `css_tag` and `js_tag` strings

## Details

KaTeX is inlined rather than left to `maidr.js` to fetch, because these
tags go into a standalone document whose script is inline: it has no URL
of its own, so the runtime has nothing to resolve the stylesheet
against.
