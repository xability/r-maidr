# Stop on svglite output the rewrite cannot vouch for

The rewrite reads svglite's text output, one element per line, and
attributes each shape to the grob drawn before it. A later svglite that
wrote otherwise would not fail on its own: its shapes would be numbered
onto the wrong grobs, and a reader would be announced one mark while
another is outlined. So anything the rewrite does not recognise stops
the export, and the chart falls back to a static image with a warning
naming this, instead of shipping selectors that point at the wrong
marks.

## Usage

``` r
svg_unreadable(what)
```

## Arguments

- what:

  What was found.
