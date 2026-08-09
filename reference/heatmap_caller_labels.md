# Resolve a heatmap()'s Caller-Supplied Axis Labels

[`heatmap()`](https://r.maidr.ai/reference/base-r-wrappers.md) gives an
explicit `labRow=`/`labCol=` priority over the matrix's own dimnames,
and subscripts it by the same ordering it applies to the data:
`labRow[rowInd] %||% rownames(x) %||% (1L:nr)[rowInd]`. Reading the
labels off the reordered matrix therefore announced the dimnames – or,
for an unnamed matrix, bare indices – while the axis showed the caller's
strings.

## Usage

``` r
heatmap_caller_labels(labels, ordering)
```

## Arguments

- labels:

  The recorded `labRow=` or `labCol=` argument, or NULL

- ordering:

  The matching `rowInd`/`colInd`. Never NULL: when no ordering was
  recovered the caller passes the identity, because
  [`heatmap()`](https://r.maidr.ai/reference/base-r-wrappers.md) applies
  a subscript either way

## Value

Character vector in drawn order, or NULL when the caller supplied no
labels for this axis

## Details

A short or `NA`-carrying vector is passed through rather than rejected:
`labRow[rowInd]` yields `NA` for the positions it cannot fill, and grid
draws that as the glyphs "NA", so mirroring it keeps the announcement
equal to the picture. Subscripting is also what holds the result to one
label per row: a caller who supplies too many gets the surplus dropped,
exactly as
[`heatmap()`](https://r.maidr.ai/reference/base-r-wrappers.md) drops it.
