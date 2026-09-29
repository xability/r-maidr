# Draw a trellis object on a screen rather than on MAIDR's hidden device

MAIDR's hidden device is current from the first Base R call it records
until [`show()`](https://r.maidr.ai/reference/show.md), and counts as a
screen only because it kept one from opening: a chart lattice draws
there goes into a temporary file nobody sees, which
[`show()`](https://r.maidr.ai/reference/show.md) then deletes. So a
chart drawn there at the console
([`drawn_at_console()`](https://r.maidr.ai/reference/drawn_at_console.md))
is drawn on the screen lattice would have drawn it on instead: the one
MAIDR opened last, as plain R draws every chart on one screen
([`use_default_device()`](https://r.maidr.ai/reference/use_default_device.md)),
with the settings the reader made
([`lattice_carry_reader_settings()`](https://r.maidr.ai/reference/lattice_carry_reader_settings.md)).
The charts that join its page with `more = TRUE` follow it there, and go
to a new screen should that one have been closed before the page was
finished. The hidden device is made current again for the Base R chart
it holds. A chart drawn into a page made on the hidden device itself
(`draw.in`, or `newpage = FALSE` with no page being composed) stays
there, with that page and its viewports, as do the charts that join it,
and so does one MAIDR draws while it renders.

## Usage

``` r
lattice_draw_on_screen(x, ..., .draw)
```

## Arguments

- x:

  A trellis object

- ...:

  The arguments of the print or
  [`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) call
  besides the object

- .draw:

  The function that draws it: lattice's print function, or Base R's
  [`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md)

## Value

What `.draw` returns, with its visibility
