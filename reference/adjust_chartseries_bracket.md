# Reposition chartSeries date-range bracket header to prevent clipping

\`quantmod::chartSeries()\` renders a bracketed date-range header (e.g.
"\[2024-01-12/2024-01-15\]") via base R \`title()\` with \`par(adj=1)\`.
For short timeseries the text width exceeds the available right margin
and the closing bracket is clipped at the SVG viewBox edge. This is
upstream quantmod issue \#129 (open since 2016, no fix). See
\`chartSeries.chob.R\` lines 205-209 for the hardcoded placement.

## Usage

``` r
adjust_chartseries_bracket(svg_content, maidr_data)
```

## Arguments

- svg_content:

  Character vector of SVG lines

- maidr_data:

  The maidr-data structure (read-only; used to detect candlestick
  layers)

## Value

Modified SVG content (character vector). If any guard fails, returns
\`svg_content\` unchanged.

## Details

Earlier we tried CSS \`overflow: visible\`, but that re-exposes
chartSeries' intentionally negative-y volume \`\<rect\>\`s which rely on
the SVG root's default \`overflow: hidden\` for clipping. Further canvas
enlargement is impractical: the header is anchored at ~91 width
regardless of total width, so even 24-inch canvases would still leave
the header riding the right edge.

This helper performs surgical SVG post-processing on the exported
gridSVG output: it locates the bracket text element by content pattern,
switches its \`text-anchor\` to \`end\`, and snaps its \`x\` coordinate
to 95 viewBox regardless of header length.

Safety: this is a no-op when \`maidr_data\` contains no candlestick
layers (ggplot candlestick / non-candlestick plots), when xml2 is
unavailable, when the SVG fails to parse, when the viewBox cannot be
read, or when no element matches the bracket pattern.
