# Reproduce the axis labels curve() derives for itself

curve() computes its default labels internally and does not return them:
the x label is `xname` ("x" unless the caller overrides it) and the y
label is the deparsed expression, with a bare function name rewritten as
`fname(xname)`. Reading them off the recorded call keeps the announced
axes matching the drawn ones; without them a visibly labelled plot would
be announced with two empty axis titles.

## Usage

``` r
curve_default_labels(recorded_args)
```

## Arguments

- recorded_args:

  Recorded (unevaluated) argument list of the call

## Value

List with `x` and `y` label strings

## Details

An explicit `xlab`/`ylab` in the call wins over these defaults; the line
processor applies that precedence.
