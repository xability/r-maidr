# A z axis format that names the categories of a heatmap's fill

A cell of categories holds its category's place in the legend
([`heat_fill_numbers()`](https://r.maidr.ai/reference/heat_fill_numbers.md));
the frontend reads the z axis's `format` function on each value it
announces, so the cell is read by the name. The names are a JSON array,
which is a JavaScript one: `toJSON()` escapes quotes and backslashes,
and U+2028 and U+2029 are legal in a JavaScript string since ES2019. A
name like `</script>` reaches the page escaped, in the chart's
attribute.

## Usage

``` r
heat_level_format(levels)
```

## Arguments

- levels:

  The names, in the legend's order

## Value

An AxisFormat holding a `function`
