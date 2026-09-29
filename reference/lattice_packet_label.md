# The strip title of one packet

One level per conditioning variable, in formula order, joined with
`" & "` as a ggplot2 facet title is. A shingle's level is an interval,
which lattice draws as a shaded bar under the variable's name, so it is
named with the variable: `"equal.count(wt, 3) [ 2.6175, 3.5725 ]"`. Read
from `condlevels` rather than from the drawn strips, whose text is not
reliable: some strip styles draw every level under one grob.

## Usage

``` r
lattice_packet_label(plot, level_index)
```

## Arguments

- plot:

  A trellis object

- level_index:

  The packet's level index for each variable

## Value

A string, `""` for an unconditioned chart.

## Details

An unconditioned chart has one packet, under a variable lattice makes up
and leaves unnamed. `outer = TRUE` conditions on the variables of an
extended formula (`a + b ~ x`) through a variable left unnamed too,
whose levels are those variables' names, so the name alone does not tell
the two apart.

A strip made by `strip.custom(factor.levels = , var.name = )` draws
those in place of the levels and names lattice hands it, and is read as
drawn. A factor's name is drawn only when the strip asks for it, as
`strip.custom(strip.names = TRUE)` does, and then before its level
across the strip's `sep`, so the packet is read `"cyl : 4"` as it is
drawn.
