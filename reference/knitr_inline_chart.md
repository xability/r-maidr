# Write one chart inline into a knitted HTML page

The chart's `<svg>`, its ids prefixed, in a `{=html}` raw block (blank
lines around it, so pandoc reads it as a block of its own) inside a
`.maidr-knitr` wrapper:

## Usage

``` r
knitr_inline_chart(svg, options = list(), index = 1L, figure = FALSE)
```

## Arguments

- svg:

  The chart's SVG, from `create_maidr_html(shiny = TRUE)`

- options:

  The chunk options

- index:

  Which of the chunk's figures this one is, from 1

- figure:

  `TRUE` for a chart the plot hook writes in place of a figure, `FALSE`
  for one `knit_print()` returns

## Value

Character string of Markdown

## Details

- The svg is a named image until maidr.js has mounted the chart, and
  stays one when it never does: `role="img"`, named by `fig.alt`, else
  `fig.cap`, else the chart's title, else its kind and axes ("Bar chart
  of n by kind"). The name is the element that holds the text, through
  `aria-labelledby`, rather than a copy in `aria-label`: bookdown
  resolves a text reference, `(ref:label)`, in the whole page,
  attributes included, and the HTML it writes would end the attribute.
  `knitr-inline.js` removes the role and the name once maidr's own
  focusable element is around the chart.

- The maidr-data JSON is in `data-maidr-knitr`, for `knitr-inline.js` to
  hand to maidr.js; see that script for why it is not in `maidr-data`.

- The alt text (or the title, when there is no caption either) is kept
  in a hidden span, and the caption below the chart. maidr names the
  chart's focusable element itself, so `knitr-inline.js` makes both its
  description.

- A caption is a `<p class="caption">` in a wrapper of class `figure`,
  as knitr writes a figure, with bookdown's `(#fig:label)` before it, so
  a bookdown cross-reference finds it. Markdown in it is shown as
  written: the caption is inside the raw block. Of the figures
  `fig.show = "hold"` holds to the end of a chunk, only the last is
  captioned, as knitr captions them; the caption of each other one is
  kept as its description.

- A chart in place of a figure of a `fig-` chunk in Quarto is given to
  Quarto as the figure it numbers and captions
  (`quarto_figure_float()`); every other chart is captioned here.

- Any other chart in place of a figure in Quarto is in a
  `.cell-output-display` div (`quarto_output_display()`), as Quarto's
  plot hook writes each figure, but in a `results = "asis"` chunk, where
  it writes none; and its wrapper is Markdown around the raw block,
  which pandoc reads as a div (`quarto_chart()`), but in a chunk Quarto
  lays out as a panel (`quarto_lays_out()`). A dashboard makes a card of
  each such chunk, as of a chunk whose output is an image, and leaves
  the chart in it: of a chunk whose output is only a raw block, it made
  none, and gathered such chunks, one after another, into one card,
  titled by the first; and it lifts an output that is only a raw block
  out of its card when the text `bsli` is in it.

- The chart was drawn at the chunk's `fig.width` and `fig.height`
  (`knitr_chart_size()`), which set the room it is laid out in, on a
  canvas of 72 pixels to the inch that its `viewBox` keeps. It is shown
  at the size knitr shows the chunk's figure at: its svg's `width` and
  `height` are the figure's (`knitr_chart_ppi()`).

- An `out.width` the author sets (not the one knitr derives for a retina
  figure) is the wrapper's width, which the chart fills, wider than its
  own size or narrower; in a panel Quarto lays out, a percentage is the
  cell's, as Quarto makes an image's. An `out.height` sets the chart's
  height, and its width keeps its shape. `fig.align` aligns the chart,
  and the wrapper too when it is narrower than its column. A chart
  Quarto captions outside a float is centred unless the chunk says
  otherwise, as Quarto centres such a figure. Every chart still shrinks
  to a column narrower than itself, keeping its shape. The charts in
  place of figures `fig.show = "hold"` holds, at such a width and not
  aligned, sit side by side, as knitr's images do.

- In a Quarto reveal.js deck that keeps `auto-stretch`, a chart not
  given a height is marked `maidr-knitr-stretch`, and `knitr-inline.js`
  stretches it when it stands alone on its slide, as Quarto stretches a
  lone figure (`quarto_auto_stretch()`).

A figure's options hold its own caption and alt text alone; of several,
as a chart `knit_print()` is asked for with a chunk's options may see,
the `index`-th is taken.
