# Rewrite svglite shapes into the exported document's shapes

Rewrite svglite shapes into the exported document's shapes

## Usage

``` r
svg_convert_shapes(
  lines,
  ids,
  clips,
  h,
  as_path = logical(length(lines)),
  own = rep(NA_character_, length(lines)),
  blank = logical(length(lines))
)
```

## Arguments

- lines:

  svglite element lines.

- ids:

  Element ids (NA for none).

- clips:

  Clip-path ids (NA for none).

- h:

  Page height in px.

- as_path:

  Shapes of a path grob, written as `<path>`.

- own:

  Each shape's own gpar names (see
  [`svg_style_attrs()`](https://r.maidr.ai/reference/svg_style_attrs.md)).

- blank:

  Shapes drawn with a blank line type.

## Value

Character vector of rewritten element lines.
