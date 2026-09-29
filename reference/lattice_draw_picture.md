# Draw a picture of a trellis object: its first page, as lattice draws it

A file holds one page, and the first is the one the interactive reading
of a multi-page chart describes. The picture is no print of the
reader's, so lattice's record of the chart it drew last is kept as it
was
([`lattice_keep_status()`](https://r.maidr.ai/reference/lattice_keep_status.md));
where it is not – a print the console hook opened the viewer for – a
first page cut from a longer chart is not saved as lattice's last
object, where `update(trellis.last.object())` would carry on from it
without the pages left out.

## Usage

``` r
lattice_draw_picture(plot)
```

## Arguments

- plot:

  A trellis object

## Value

The number of pages the chart is laid out on, invisibly.
