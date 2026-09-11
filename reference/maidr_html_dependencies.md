# Register JS dependencies for maidr

Creates the HTML dependency for the MAIDR JavaScript bundle. Behavior is
controlled by the `use_cdn` parameter:

- If `TRUE`: Use CDN (requires internet)

- If `FALSE` (default): Use local bundled files (works offline)

- If `NULL`: Same as `FALSE` - use local bundled files

## Usage

``` r
maidr_html_dependencies(use_cdn = NULL)
```

## Arguments

- use_cdn:

  Logical. If `TRUE`, use CDN. If `FALSE` or `NULL` (default), use
  bundled files.

## Value

A list of htmlDependency objects: the `maidr` bundle, preceded by
`maidr-dotpad-config` when a DotPad SDK location is configured

## Details

We default to local bundled assets for deterministic rendering.
Previously we auto-detected via
[`curl::has_internet()`](https://jeroen.r-universe.dev/curl/reference/nslookup.html);
when internet was available the CDN path was selected, which combined
with a (now-fixed) malformed nested-`<html>` HTML scaffold caused base R
chart SVGs to render squished in the upper-left of the viewport. Local
assets match the ggplot path that has always rendered correctly. Users
who want CDN can still pass `use_cdn = TRUE` explicitly.

When a DotPad SDK location is configured (see
[maidr-options](https://r.maidr.ai/reference/maidr-options.md)), a
`maidr-dotpad-config` dependency precedes the `maidr` one: its `head`
declares the `window.MAIDR_DOTPAD_*` globals, and listing it first is
what puts them ahead of the bundle's `<script>` in the rendered
document.

No stylesheet is declared. MAIDR styles its interface at runtime, and
since maidr 3.75.1 the published `maidr.css` is a placeholder with no
rules in it. The one stylesheet that does carry rules, `maidr-math.css`
(KaTeX, for LaTeX in AI chat responses), is fetched by `maidr.js`
itself, resolved against the URL it was loaded from – the CDN directory,
or the `lib/` folder htmltools copies the bundle into.
