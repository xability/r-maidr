# Read a recorded logical argument the way its drawing function does

Every base R reader asked
[`isTRUE()`](https://rdrr.io/r/base/Logic.html) of a recorded flag, and
the base R drawing functions ask `if (x)`. The two agree on `TRUE`, on
`FALSE` and on absent, and disagree on every other truthy value R
accepts in an `if` – so a chart written `stripchart(x, vertical = 1)`
was drawn vertically and announced horizontally, with the values on the
group axis and the group positions on the value axis, silently, on a
chart that renders as an interactive one rather than as a fallback
(#256).

## Usage

``` r
recorded_flag(args, name, default = FALSE)
```

## Arguments

- args:

  Recorded argument list

- name:

  The formal's name

- default:

  What an absent, `NA` or unreadable argument means

## Value

TRUE or FALSE

## Details

Measured, by reading each drawing function's own body:

|                            |                                  |
|----------------------------|----------------------------------|
| function                   | asks                             |
| `barplot.default`          | `if (beside)`, `(logx && horiz)` |
| `bxp`                      | `if (horizontal)`                |
| `hist.default`             | `if (freq1)`                     |
| `stripchart.default`       | `if (vertical)`                  |
| `qqnorm.default`, `qqline` | `if (datax)`                     |
| `vioplot.default`          | \`if (horizontal                 |

All seven ask R's own truthiness, so all seven are read through this.

`NA` and an uncoercible value give the caller's default rather than an
error: `if (NA)` stops in R, but a reader that stops takes the whole
figure with it, and a chart read under its default is better than no
chart at all. A value of any length but one does the same, since `if` on
one of those errors too.
