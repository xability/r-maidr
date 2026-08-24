# Address one tile of a grob that draws a whole panel of them

gridSVG exports a `rect` grob holding several rectangles as one group of
`<rect>` elements, each with its own id: `<grob>.1.<n>`, counted from
one in draw order. A spine plot's panel is the case that needs it.

## Usage

``` r
rect_cell_selector(grob_name, drawn_at)
```

## Arguments

- grob_name:

  The grob holding the tiles

- drawn_at:

  Which tile, counted in draw order from one

## Value

A CSS selector matching exactly that tile
