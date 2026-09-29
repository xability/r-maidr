# Whether lattice's current page is still being composed

Read from the record
[`lattice_keep_status()`](https://r.maidr.ai/reference/lattice_keep_status.md)
keeps: a chart drawn with `more = TRUE` leaves its page open, and
`plot.trellis()` draws the next chart onto that page rather than
starting one. Should the record not be where it is looked for, no page
is taken to be open.

## Usage

``` r
lattice_page_open()
```

## Value

`TRUE` when the next chart lattice draws joins the current page.
