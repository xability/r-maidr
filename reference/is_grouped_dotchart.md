# Whether a `dotchart()` call draws more than one group

[`dotchart()`](https://r.maidr.ai/reference/base-r-wrappers.md) draws a
group per matrix column, or per level of `groups`, with a header in the
left margin and every dot in one shared grob. The grouping is what the
chart is drawn to show and there is nothing in a flat `dot` layer to
carry it, so such a call is declined rather than flattened.

## Usage

``` r
is_grouped_dotchart(args)
```

## Arguments

- args:

  The arguments recorded from the
  [`dotchart()`](https://r.maidr.ai/reference/base-r-wrappers.md) call.

## Value

`TRUE` when the call draws groups, otherwise `FALSE`.
