# The trellis object restricted to its first page

`plot.trellis()` draws every page, starting a new one for each, so the
device – and the SVG exported from it – ends up holding only the last
page. A chart laid out over several pages is read from its first, which
is the page a reader would come to first; the number of pages it had is
kept in the `maidr_pages` attribute so the caller can say what was left
out.

## Usage

``` r
lattice_first_page(plot)
```

## Arguments

- plot:

  A trellis object

## Value

The object, laid out on one page.
