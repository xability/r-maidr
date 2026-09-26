# Presentation attributes for a group, as gridSVG gave them

gridSVG wrote a group's own gpar as attributes its shapes inherit, and a
shape's own gpar on the shape. Shapes here keep that split (see
[`svg_convert_shapes()`](https://r.maidr.ai/reference/svg_convert_shapes.md)),
so the groups carry their share: each setting the group's gpar names, at
the value the drawing inherits there. Alpha is folded into the opacities
rather than written as `opacity`, the way the device folds it into every
shape.

## Usage

``` r
svg_gp_attrs(eff, set)
```

## Arguments

- eff:

  The effective gpar at the group.

- set:

  Names of the gpar settings the group itself makes.

## Value

A string of attributes with a leading space, or "".
