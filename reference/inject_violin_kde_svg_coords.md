# Inject svg_x/svg_y coordinates into violin_kde layer data

After \`grid.draw(gt)\` has been called on a PDF device, this function
navigates to the panel viewport, maps data coordinates to SVG points,
and injects \`svg_x\`/\`svg_y\` into each ViolinKdePoint. Temporary
metadata fields (\`.panel_x_range\`, \`.panel_y_range\`,
\`.is_horizontal\`, \`data_left_x\`, \`data_right_x\`, \`data_y\`) are
stripped from the output.

## Usage

``` r
inject_violin_kde_svg_coords(gt, maidr_data)
```

## Arguments

- gt:

  The gtable object (used to find the panel viewport name)

- maidr_data:

  The maidr-data structure (modified in place)

## Value

Updated maidr_data with svg_x/svg_y injected
