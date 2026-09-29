# MAIDR's print function for trellis objects

Renders a printed trellis object in the MAIDR viewer when the print is a
reader asking to see a chart, and draws it the way lattice would have
otherwise. See
[`lattice_print_opens_viewer()`](https://r.maidr.ai/reference/lattice_print_opens_viewer.md)
for which prints those are. An unsupported chart is drawn natively. One
that is read but cannot be exported opens in the viewer as a static
image, with a warning, as it does from
[`show()`](https://r.maidr.ai/reference/show.md):
[`build_interactive_svg()`](https://r.maidr.ai/reference/build_interactive_svg.md)
turns the failure into the picture. It is drawn natively when fallback
is off, which hands that error to this hook, and when the viewer cannot
be opened.

## Usage

``` r
maidr_print_trellis(x, ...)
```

## Arguments

- x:

  A trellis object

- ...:

  Arguments [`print()`](https://rdrr.io/r/base/print.html) was given,
  passed to lattice when the chart is drawn natively

## Value

`x`, invisibly
