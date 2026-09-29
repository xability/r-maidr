# Whether a print of a trellis object should open the MAIDR viewer

Every print of a trellis object reaches the hook, and most of them are
not a reader asking to see a chart. Each of these is drawn natively:

## Usage

``` r
lattice_print_opens_viewer(args, stored = NULL)
```

## Arguments

- args:

  The arguments [`print()`](https://rdrr.io/r/base/print.html) was given
  besides the object.

- stored:

  The object's `plot.args`, which `plot.trellis()` draws with in place
  of any argument [`print()`](https://rdrr.io/r/base/print.html) was not
  given.

## Value

`TRUE` when the print should open the viewer.

## Details

- a composition – `print(p, split = , more = TRUE)`, `position =`,
  `newpage = FALSE`, `draw.in =`, by name, partial name or place (see
  [`lattice_print_arguments()`](https://r.maidr.ai/reference/lattice_print_arguments.md)),
  or carried in the chart's `plot.args` – places the chart on a page
  other charts share, which is lattice's own idiom for arranging
  several;

- a print onto a device that is not a screen: a file the user opened
  with [`pdf()`](https://rdrr.io/r/grDevices/pdf.html) or
  [`png()`](https://rdrr.io/r/grDevices/png.html) expects the chart in
  the file, and `grid.grabExpr()` or
  [`ggplotify::as.grob()`](https://rdrr.io/pkg/ggplotify/man/as-grob.html)
  expect it on their own off-screen device;

- a print while knitr is running, which is
  [`knit_print.trellis()`](https://r.maidr.ai/reference/knit_print.trellis.md)'s
  to make accessible, or inside a Shiny render, which is
  [`render_maidr()`](https://r.maidr.ai/reference/render_maidr.md)'s;

- a print outside an interactive session, where there is no viewer to
  open;

- a print MAIDR makes while it renders, and any print after
  [`maidr_off()`](https://r.maidr.ai/reference/maidr_off.md) or under
  `options(maidr.lattice = FALSE)`.
