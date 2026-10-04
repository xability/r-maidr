# The script and stylesheet of charts a knitted document shows inline

`knitr-inline.js` hands each chart to `maidr.js`, gives it a
description, and keeps the shortcuts of slide decks, books and sites
from firing while a chart has the focus; `knitr-inline.css` lays the
charts out and draws their focus ring. The stylesheet is not named
`maidr-*.css`: `maidr.js` takes a stylesheet of that name for its own
when it looks for `maidr-math.css`.

## Usage

``` r
maidr_knitr_dependency()
```

## Value

A single htmltools::htmlDependency()
