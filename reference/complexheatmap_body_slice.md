# The body slice a grob draws the cells of, if it does

The body slice a grob draws the cells of, if it does

## Usage

``` r
complexheatmap_body_slice(grob, prefix, nrows, ncols)
```

## Arguments

- grob:

  A child of the grabbed drawing

- prefix:

  The body viewports' name before `<kr>_<kc>`

- nrows, ncols:

  The number of rows in each row slice, and of columns in each column
  slice

## Value

`c(kr, kc)` when the grob is a rect in the body viewport of that slice,
drawing its cells
([`complexheatmap_rect_is_cells()`](https://r.maidr.ai/reference/complexheatmap_rect_is_cells.md));
else NULL
