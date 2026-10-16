# The script and stylesheet of charts a knitted document shows inline

`knitr-inline.js` hands each chart to `maidr.js`, gives it a description
and sizes it; `knitr-inline.css` lays the charts out. The stylesheet is
not named `maidr-*.css`: `maidr.js` takes a stylesheet of that name for
its own when it looks for `maidr-math.css`.

## Usage

``` r
maidr_knitr_dependency()
```

## Value

A single htmltools::htmlDependency()
