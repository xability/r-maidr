# Fill a heatmap's score matrix from the source rows

Each drawn tile takes the fill of the first source row at its (x, y):
the row whose `x == x_level & y == y_level` is first not `FALSE`. A row
with a missing x or y compares `NA` against every level, so it wins the
cells it comes first for, with a missing value.

## Usage

``` r
heat_fill_scores(
  score_matrix,
  source,
  x_col,
  y_col,
  fill_col,
  x_values,
  y_values,
  built_x,
  built_y
)
```

## Arguments

- score_matrix:

  The y-by-x matrix to fill, all `NA`

- source:

  This panel's source rows

- x_col, y_col, fill_col:

  Column names in `source`

- x_values, y_values:

  The axis levels

- built_x, built_y:

  Each drawn tile's position, a level index

## Value

`score_matrix`, filled. Read it through
[`as.numeric()`](https://rdrr.io/r/base/numeric.html): where no cell
takes a value its storage type is left as it was.

## Details

Scanning the source for every tile made this quadratic – a 300 x 300
grid took over a minute – so each source row is coded by level once and
the cells are looked up in C++. A column
[`heat_codable()`](https://r.maidr.ai/reference/heat_codable.md) cannot
code is still scanned.
