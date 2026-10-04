# Prefix Every Id of One maidr SVG, and Everything That Refers to One

The SVG is read with xml2 rather than edited as text, so text content is
never touched: libxml2 leaves `"` unescaped in text, and a chart title
can read `id="clip.1" url(#clip.1)` literally. The maidr-data JSON is
edited in place rather than parsed and written again, so no data value
is re-serialized; only the selectors and the figure id change.

## Usage

``` r
inline_prefix_svg_ids(svg, prefix)
```

## Arguments

- svg:

  One `<svg>` element carrying a `maidr-data` attribute, as
  `create_maidr_html(plot, shiny = TRUE)` returns it: a string, an
  [`htmltools::HTML`](https://rstudio.github.io/htmltools/reference/HTML.html)
  string or a character vector of lines, with or without an `<?xml?>`
  prolog.

- prefix:

  The chart's prefix, from
  [`inline_id_prefix()`](https://r.maidr.ai/reference/inline_id_prefix.md).

## Value

The SVG as one string, without the prolog. A chart this function cannot
fully scope – not one well-formed SVG with valid maidr-data, a
`<style>`, `<script>` or `<foreignObject>` in it, or a selector outside
the forms the package builds – is refused with an error of class
`maidr_inline_unsupported`.

## Details

What is rewritten:

- every `id` attribute;

- every `url(#X)` in any attribute but `maidr-data`, quoted or not, and
  every `href` or `xlink:href` of `#X`, when `X` is an id of this SVG;

- every id in an ARIA reference list (none are emitted today);

- every selector string under a `selectors` or `selector` key of the
  maidr-data JSON, at any depth;

- the JSON figure id (the top-level `id`), which maidr.js derives the
  ids of the article and figure it wraps the chart in from.

Subplot and layer ids never reach the DOM and are left alone.
