# Copies of what an older maidr.js leaves to a knitted page

`knitr-compat.js` and `knitr-compat.css` hold copies of what maidr.js
does itself from
[MAIDR_PAGE_GUARDS_VERSION](https://r.maidr.ai/reference/MAIDR_PAGE_GUARDS_VERSION.md):
they keep the shortcuts of slide decks, books, sites and dashboard cards
from firing while a chart has the focus, hand Shift+Tab at the start of
a deck's slide to the slide, draw the charts' focus ring, and keep high
contrast to the chart. Each stands down for a maidr.js that says, in
`maidrLive.features`, that it does the same. A page carries them only
when
[`maidr_knitr_compat_needed()`](https://r.maidr.ai/reference/maidr_knitr_compat_needed.md)
says so.

## Usage

``` r
maidr_knitr_compat_dependency()
```

## Value

A single htmltools::htmlDependency()
