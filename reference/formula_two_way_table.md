# The table `mosaicplot.formula()` would build from a recorded formula call

`mosaicplot(~ Hair + Eye, data = df)` is a common calling style, and the
table it draws is recoverable rather than invented – so it is built the
way `mosaicplot.formula()` builds it, by the same two branches, rather
than by a rule of our own that would agree with it only sometimes.

## Usage

``` r
formula_two_way_table(args)
```

## Arguments

- args:

  Recorded argument list, or NULL

## Value

A table, or NULL when the call is not a readable formula call

## Details

### Which branch, and why it matters

Read from `graphics:::mosaicplot.formula` rather than assumed. A `data`
that is a table (or has more than two dimensions) is summed over the
formula's terms; anything else goes through
[`model.frame()`](https://rdrr.io/r/stats/model.frame.html) and is
**counted by row**:


    if (inherits(edata, "ftable") || inherits(edata, "table") ||
        length(dim(edata)) > 2) {
      data <- marginSums(as.table(data), varnames)
      mosaicplot(data, ...)
    } else {
      mf <- eval(model.frame(formula, data, subset, na.action))
      mosaicplot(table(mf), ...)
    }

The distinction is not cosmetic, and \#248 proposed the other reading. A
data frame of *pre-counted* cells –
`as.data.frame(HairEyeColor[, , 1])`, sixteen rows and a `Freq` column –
is counted by row like any other, so the chart draws sixteen equal
cells:


    table(model.frame(~ Hair + Eye, df))    xtabs(Freq ~ Hair + Eye, df)
            Brown Blue Hazel Green                  Brown Blue Hazel Green
      Black     1    1     1     1            Black    32   11    10     3
      Brown     1    1     1     1            Brown    53   50    25    15
      Red       1    1     1     1            Red      10   10     7     7
      Blond     1    1     1     1            Blond     3   30     5     8

The left table is what
[`mosaicplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) draws;
the right is the one it would draw if handed `HairEyeColor[, , 1]`
directly. Reading the right one would announce numbers the chart does
not show, which is the one thing this processor exists not to do. There
is no `Freq` convention to match: `mosaicplot.formula()` has none.

### What is declined

A recorded `subset`. `mosaicplot.formula()` passes it into
[`model.frame()`](https://rdrr.io/r/stats/model.frame.html), so
honouring it means reproducing an argument whose recorded form is not
the expression
[`model.frame()`](https://rdrr.io/r/stats/model.frame.html) is given –
and ignoring it would read rows the chart left out. Declined rather than
guessed, which leaves the figure exactly the picture it is today.

A recorded `na.action` is *not* passed through, and does not need to be:
[`table()`](https://rdrr.io/r/base/table.html) drops a missing level
whatever reached it, so the three actions a caller can name all draw the
same chart. Measured on a frame with an NA in each column, `na.omit`,
`na.pass` and `na.exclude` gave one table:


         b
    a     p q
      x   2 1
      y   1 0

[`stats::na.omit`](https://rdrr.io/r/stats/na.fail.html) is named here
anyway, because that is what `mosaicplot.formula()` defaults to and
matching it costs nothing.
