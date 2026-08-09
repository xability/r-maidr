# Collect every panel cell of a gtable, descending into nested gtables

Nested layouts like `(p1 | p2) / p3` place the inner row's panels inside
a CHILD gtable ("patchwork-table-N"), so scanning only the top-level
layout drops them. Panels are collected in DISCOVERY order, which
follows patchwork's plot-addition order and therefore matches
[`extract_patchwork_leaves()`](https://r.maidr.ai/reference/extract_patchwork_leaves.md).

## Usage

``` r
collect_gtable_panels(
  gt,
  t_path = integer(0),
  l_path = integer(0),
  vp_prefix = character(0)
)
```

## Arguments

- gt:

  Gtable object

- t_path:

  Accumulated top positions of the enclosing cells

- l_path:

  Accumulated left positions of the enclosing cells

- vp_prefix:

  Accumulated viewport names of the enclosing cells

## Value

List of panel entries (name, grob, t, l, t_key, l_key, vp_path)

## Details

Each entry also carries the grid viewport path needed to navigate to
that panel after the gtable has been drawn. gtable names a cell's
viewport `<name>.<t>-<r>-<b>-<l>` and wraps a nested gtable's children
in a "layout" viewport, so the path down to a nested panel is
`c("<child>.t-r-b-l", "layout", "<panel>.t-r-b-l")`. Panel names are NOT
unique across a nested composition (both halves of a 2x2 contain a
"panel-1"), which is why callers address panels by position in this list
rather than by name.
