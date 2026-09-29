# Keep lattice's record of the chart it drew last

lattice keeps one record, for the whole session, of the chart it drew
last: the chart
[`trellis.focus()`](https://rdrr.io/pkg/lattice/man/interaction.html),
[`trellis.currentLayout()`](https://rdrr.io/pkg/lattice/man/panel.number.html)
and
[`trellis.last.object()`](https://rdrr.io/pkg/lattice/man/update.trellis.html)
act on, and whether a `print(more = TRUE)` page is still being composed.
A chart MAIDR draws to read it, or to picture it, would replace the
record of the reader's own chart with one of a drawing no device shows,
so the record is taken before and put back after – except for a print
the console hook opens the viewer for, which is the reader's own print
of their chart.

## Usage

``` r
lattice_keep_status()
```

## Value

A function that puts the record back as it was when this was called; it
does nothing when there is nothing to put back.

## Details

The record has no exported accessor. Should it ever not be where it is
looked for, nothing is put back and the chart is drawn all the same.
