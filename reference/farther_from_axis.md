# Whether one margin line is farther from the axis than another

The lines of a margin count outwards from the axis, from 0. A line below
0 is inside the plot, so it is farther than every line of the margin,
and farther the further in it is.

## Usage

``` r
farther_from_axis(line, than)
```

## Arguments

- line, than:

  Two lines of one margin, as
  [`mtext()`](https://r.maidr.ai/reference/base-r-wrappers.md) takes
  them

## Value

TRUE when `line` is the farther of the two
