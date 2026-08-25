# Move a rect's anchor so its extent can be stated positively

Only rects anchored at the low edge are touched. A centred or
high-anchored rect with a negative extent covers a different span, and
moving its anchor would move the rectangle rather than restate it – so
those are left as they are, warning and all, rather than silently
redrawn somewhere else.

## Usage

``` r
flip_negative_extent(position, extent, anchor)
```

## Arguments

- position:

  The rect's `x` or `y`, as a unit

- extent:

  The rect's `width` or `height`, as a unit

- anchor:

  Where the rect is anchored on this axis, from
  [`rect_anchor()`](https://r.maidr.ai/reference/rect_anchor.md): 0 is
  the low edge

## Value

List with the restated `position` and `extent`
