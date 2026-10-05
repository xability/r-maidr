# Resolve one axis title from a recorded Base R call

The author's own `xlab=`/`ylab=` always wins, read as the text R draws
for it, whatever it was given as (`base_r_annotation_text()`); a
plotmath title is read as it was written, `Miles[gallon]`, given alone
or in a list with its colour or size. An empty string counts as
unsupplied: Base R draws no title for it, so falling through to the
chart type's default announces more than the blank would, and the
renderer would otherwise substitute its generic "X"/"Y" anyway. This is
how the candlestick processor has always read these arguments.

## Usage

``` r
recorded_axis_label(args, name, default = NULL)
```

## Arguments

- args:

  Recorded argument list, or NULL

- name:

  Argument to read: `"xlab"` or `"ylab"`

- default:

  What this chart type can honestly say when the author said nothing.
  Pass NULL when it can say nothing: an absent label leaves the generic
  to the renderer, which is where that decision belongs.

## Value

Character scalar, or `default`
