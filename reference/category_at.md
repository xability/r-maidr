# The name at one position, or `NULL`

A point drawn *off* an integer is still in that integer's category.
`position_dodge` shifts a point sideways to make room for a sibling
series and `position_jitter` scatters it, and both displacements stay
*within* the category's own slot – so the tick it was moved from is the
category it is in, not a category it is being falsely assigned to.
Measured on a dodged scatter over two groups, `x` arrives as 0.875,
1.125, 1.875, 2.125, and an exact match names none of the 24 points.

## Usage

``` r
category_at(position, labels)
```

## Arguments

- position:

  A drawn coordinate

- labels:

  The map from
  [`discrete_axis_labels()`](https://r.maidr.ai/reference/discrete_axis_labels.md)

## Value

The name, or `NULL` when there is none

## Details

Rounding is what recovers them, which is the answer the Python binding
reached for the same situation: "a point drawn off one is a group a
`dodge` shifted aside to make room for its neighbour – still that group,
and still named by the tick it was moved from."

Bounded at half a tick, which is what keeps it honest. ggplot2 keeps
both displacements inside the slot – a dodge divides the category's
width, and `position_jitter`'s default reaches 40% of the resolution –
so anything further out is not a displaced member of that category and
is left unnamed. The `is_discrete()` gate above does the rest: on a
continuous axis there are no names to round onto, so a measurement
cannot be renamed after whichever tick it happens to fall nearest.
