# The grobs each supported lattice panel function draws, by what they are

lattice names every grob it draws inside a panel
`<prefix>.<what>[.group.<k>].panel.<column>.<row>`, `<what>` being the
panel function's identifier and the primitive it drew (`xyplot.points`,
`barchart.x.2.rect`, `density rug.x`). This table says, for each
supported panel function, what every `<what>` it can draw is:

## Usage

``` r
LATTICE_PANEL_ROLES
```

## Details

- a **role** names marks a layer is read from;

- `observations` marks the data drawn again as marks nobody navigates –
  the jittered points and the rug under a density curve;

- `decoration` marks reference lines, grids, contour labels and the
  like, which carry no observations.

A grob drawn inside a panel that matches none of these is something the
reading does not know the meaning of, and the chart falls back to an
image rather than being read without it
([`lattice_panel_audit()`](https://r.maidr.ai/reference/lattice_panel_audit.md)).
The table was taken from a sweep of the stock panel functions over their
arguments, lattice 0.23, `type` among them:
[`panel.dotplot()`](https://rdrr.io/pkg/lattice/man/panel.dotplot.html),
[`panel.stripplot()`](https://rdrr.io/pkg/lattice/man/panel.stripplot.html),
[`panel.qqmath()`](https://rdrr.io/pkg/lattice/man/panel.qqmath.html)
and [`panel.qq()`](https://rdrr.io/pkg/lattice/man/panel.xyplot.html)
hand `type`, `abline` and `grid` on to
[`panel.xyplot()`](https://rdrr.io/pkg/lattice/man/panel.xyplot.html),
which draws its lines, spikes, fits and averages under their identifier
– or `xyplot`'s, for a group
[`panel.superpose()`](https://rdrr.io/pkg/lattice/man/panel.superpose.html)
draws – and its reference lines under its own.
