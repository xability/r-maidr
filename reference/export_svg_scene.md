# Export the grid scene on the current (svglite) device

Must be called with the chart already drawn on a device opened by
[`open_svg_device()`](https://r.maidr.ai/reference/open_svg_device.md).
Closes that device.

## Usage

``` r
export_svg_scene(svg_string, width, height)
```

## Arguments

- svg_string:

  The function
  [`open_svg_device()`](https://r.maidr.ai/reference/open_svg_device.md)
  returned.

- width, height:

  Page size in inches.

## Value

Character vector of SVG lines.
