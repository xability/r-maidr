# Draw a trellis object the way the lattice system reads it

Always `plot.trellis()`, lattice's own drawer, which neither consults
`print.function` nor comes back through MAIDR's print hook, and never a
bare [`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md), which
inside this namespace is MAIDR's recording wrapper. The layout arguments
are given explicitly: `plot.trellis()` falls back to `plot$plot.args`
for any it is not given, and a `split =` stored there by
[`update()`](https://rdrr.io/r/stats/update.html) would draw the chart
into part of the page. A panel function that fails is not drawn around
as lattice does by default: the error is raised, so the chart falls back
to an image rather than being read with a panel missing.

## Usage

``` r
lattice_draw(plot, prefix = LATTICE_PREFIX)
```

## Arguments

- plot:

  A trellis object

- prefix:

  The grob-name prefix

## Value

NULL, invisibly

## Details

`packet.panel` is not given: it chooses which packets the page holds,
not where the chart goes, and `plot.trellis()` takes one stored in
`plot$plot.args` –
[`?packet.panel.default`](https://rdrr.io/pkg/lattice/man/packet.panel.default.html)'s
way to draw a later page – when it is not.

What is drawn is not saved as lattice's last object: it is the copy
[`lattice_prepare()`](https://r.maidr.ai/reference/lattice_prepare.md)
made, which may hold only the chart's first page, and
`update(trellis.last.object())` would carry on from it without the pages
left out.
