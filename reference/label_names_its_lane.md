# Whether an axis label names a lane or just writes its own coordinate out

A continuous axis has labels too – "1", "0.5", "1,000" – but those are
formatted renderings of the numbers rather than names for them, which is
the distinction
[`discrete_axis_labels()`](https://r.maidr.ai/reference/discrete_axis_labels.md)
already draws for a discrete scale and xability/py-maidr#533 settled for
lanes: an explicit tick names the lane it sits in, and the axis's own
coordinates do not.

## Usage

``` r
label_names_its_lane(label, break_value)
```

## Arguments

- label:

  One axis label

- break_value:

  The break the label was drawn at

## Value

TRUE when the label is a name rather than the break written out

## Details

So the test is "is this label a rendering of its own number", not "is
there a label". Measured on ggplot2 3.4.4, bands at 0.6-1.4, 1.6-2.4,
2.6-3.4:


    default scale                             1, 2, 3            -> position
    breaks = 1:3, labels = c("design", ...)   design, build, test -> name
    breaks = 1:3, labels = c("1", "2", "3")   1, 2, 3            -> position
    breaks = 1:3                              1, 2, 3            -> position
    breaks = seq(0, 4, 0.5)                   0.5, 1.0, 1.5, ... -> position

An author who writes `labels = c("1", "2", "3")` is deliberately naming
lanes "1", "2" and "3" and gets positions instead. That is the trade
py-maidr made, and it is the safe direction: a lane called "2" says less
than a lane called by the position 2 it sits at.

The strip is what keeps
[`scales::comma`](https://scales.r-lib.org/reference/comma.html),
[`scales::dollar`](https://scales.r-lib.org/reference/dollar_format.html)
and a padded label from reading as names – measured, `"1,000"` at the
break 1000 and `"$1"` at 1 both come back FALSE. It does not save
[`scales::percent`](https://scales.r-lib.org/reference/percent_format.html),
which renders the break 1 as `"100%"`: measured, that reads as a name
and a lane is called `"100%"` rather than 1. The cost is a cosmetic
mis-name inside a schedule the author already declared, not a false
claim, so it is recorded rather than chased.
