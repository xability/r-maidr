# The values of a line that nothing is drawn for

grid draws a line as its runs of two or more finite vertices: a missing
or infinite coordinate breaks it, and a vertex with a break or an end of
the line on both sides – a value between two missing ones, or next to
one at the line's end, or a line's only value – is in no run, so it is
drawn as nothing and the SVG holds no vertex for it. The frontend pairs
a line's readings with its vertices in order, and when there are more
readings than vertices it places the readings by their x between the
first vertex and the last, which puts them off their vertices, and all
on the first one when x is a level's name. Such a value is read as the
gap the chart shows; with `type = "b"` or `"o"` its point is still read,
in the point layer.

## Usage

``` r
lattice_line_alone(x, y)
```

## Arguments

- x, y:

  The line's coordinates, in the order drawn

## Value

Logical, one per vertex: `TRUE` for a finite one that no segment is
drawn through
