# The first maidr.js that keeps a page's shortcuts off a chart itself

maidr.js 4.15.0 keeps the shortcuts of the page around a chart off the
keys a reader presses in it, hands Shift+Tab on a deck's slide to the
slide, draws a focus ring a page's stylesheet cannot remove, and paints
the chart rather than the page for high contrast (xability/maidr#1388,
\#1390). Before it, the knitted page's own script did all of that.

## Usage

``` r
MAIDR_PAGE_GUARDS_VERSION
```
