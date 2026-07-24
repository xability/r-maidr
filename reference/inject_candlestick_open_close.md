# Inject candlestick open/close virtual line elements into the SVG

tidyquant's \`geom_candlestick()\` draws each candle's body as a single
\`\<rect\>\`. Upstream maidr JS auto-derives \`open\` and \`close\`
highlight positions from the rect's bounding-box edges, but its
heuristic assumes a natural SVG y-axis (y increasing downward). gridSVG
exports content inside a \`translate(0, h) scale(1, -1)\` group, so y is
flipped. The upstream heuristic therefore swaps open and close on every
candle.

## Usage

``` r
inject_candlestick_open_close(svg_content, maidr_data)
```

## Arguments

- svg_content:

  Character vector of SVG lines

- maidr_data:

  The maidr-data structure (read-only; used to look up per-candle
  \`trend\`)

## Value

Modified SVG content (character vector). If parsing fails or no
candlestick layers are present, returns \`svg_content\` unchanged.

## Details

We sidestep the heuristic by emitting two sibling \`\<g\>\` containers
(one for opens, one for closes), each holding N invisible \`\<line\>\`
elements positioned at the correct edge of the corresponding body rect
(computed from the per-candle \`trend\`). The candlestick processor
emits explicit \`selectors.open\` / \`selectors.close\` referencing
these groups, so JS uses our placed elements directly and skips its own
derivation.
