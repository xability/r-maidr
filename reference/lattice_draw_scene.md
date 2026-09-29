# Draw a trellis object off-screen and keep what the reading needs

The chart is drawn once, into a grob that is later drawn again onto the
svglite page the SVG is exported from; every selector is written against
the names this drawing gives. While the off-screen device is still open,
two things only lattice and grid can say are kept with it: which packet
each layout cell holds
([`trellis.currentLayout()`](https://rdrr.io/pkg/lattice/man/panel.number.html),
valid only right after drawing) and every grob drawn, with the viewport
it was drawn in (`grid.ls()`), which is how grobs inside a panel are
told from its axes and strips.

## Usage

``` r
lattice_draw_scene(plot, prefix = LATTICE_PREFIX)
```

## Arguments

- plot:

  A trellis object, as
  [`lattice_prepare()`](https://r.maidr.ai/reference/lattice_prepare.md)
  returns it

- prefix:

  The grob-name prefix

## Value

A list: `grob`, the drawn chart; `packets`, the packet matrix indexed
`[row, column]` as the grob names are; `listing`, a data frame of every
grob and viewport drawn, with its `name`, `vpPath` and `type`.

## Details

The off-screen device would draw with its own lattice theme, so the
theme the reader set on the device they look at is carried over
([`lattice_carry_theme()`](https://r.maidr.ai/reference/lattice_carry_theme.md)).

No device is opened that a reader could see, or left open. With none
open, `grid.grabExpr()` would end by making "the device that was current
before" current again with `dev.set(1)`, which opens the default device:
a window at the console, an `Rplots.pdf` in a script, for every chart
read in a session that had drawn nothing yet. An off-screen device that
writes no file stands in as that device, and is closed afterwards.

Nor is lattice's record of the chart it drew last left describing this
drawing, which no device shows: it is put back afterwards, so
[`trellis.focus()`](https://rdrr.io/pkg/lattice/man/interaction.html)
and `print(more = TRUE)` carry on with the reader's own chart. A print
the console hook opens the viewer for is the exception: it is the
reader's own chart.
