# Turn a grob name into the selector gridSVG exports it under

gridSVG appends `.1` to each grob id, and the existing base R processors
address elements with the `[id^=...]` prefix form.

## Usage

``` r
vioplot_grob_selector(element, id)
```
