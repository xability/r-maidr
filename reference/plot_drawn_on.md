# The plot a low-level call draws on

A low-level call draws on the plot drawn last, unless `par(mfg = )`
moved back to an earlier panel of a grid first:
`par(mfrow = c(1, 2)); plot(a); plot(b); par(mfg = c(1, 1)); title(xlab = "A")`
draws "A" under the first plot. It is recorded with the plot it was
written after, so it is read on the plot, of those drawn up to it, that
R drew in the region it was drawn in
([`device_plot_region()`](https://r.maidr.ai/reference/device_plot_region.md)).

## Usage

``` r
plot_drawn_on(call, groups, last)
```

## Arguments

- call:

  A recorded LOW-level call

- groups:

  The plot groups, from
  [`group_device_calls()`](https://r.maidr.ai/reference/group_device_calls.md)

- last:

  The index of the group the call was recorded in, the last one drawn
  before it

## Value

The index in `groups` of the last one up to `last` drawn in the call's
region, or `last` where none was, or where either region was not
recorded
