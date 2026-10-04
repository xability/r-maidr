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

- `fig.align` aligns the chart, and an `out.width` the author sets (not
  the one knitr derives for a retina figure) sets the wrapper's width,
  which the chart shrinks to; `fig.width` and `fig.height` are not read,
  since maidr draws every chart at its own size. The charts in place of
  figures `fig.show = "hold"` holds, at such a width and not aligned,
  sit side by side, as knitr's images do.

A figure's options hold its own caption and alt text alone; of several,
as a chart `knit_print()` is asked for with a chunk's options may see,
the `index`-th is taken.
