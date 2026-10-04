# Recorded values that are calls, as the expressions they stand for

A plotmath title is a call: `main = bquote(mu == .(n))` hands the chart
the call `mu == 3`, and `xlab = quote(x[i])` the call `x[i]`. Everything
that reads a recorded call passes its values on through
[`do.call()`](https://rdrr.io/r/base/do.call.html) – the replay that
draws maidr's chart, and the processors that compute what
[`boxplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) or
[`qqnorm()`](https://r.maidr.ai/reference/base-r-wrappers.md) drew – and
[`do.call()`](https://rdrr.io/r/base/do.call.html) evaluates a call it
is handed, so each of them stopped looking up `mu`: the exported chart
was drawn with nothing on it, and a box plot or Q-Q plot was read with
no data. gridGraphics, which turns the replay into maidr's SVG, stops on
a title that is a call as well.

## Usage

``` r
calls_as_expressions(args)
```

## Arguments

- args:

  Recorded argument list of evaluated values

## Value

`args`, each call or symbol in it replaced by an expression vector
holding it

## Details

An expression vector holding the call is drawn as the same plotmath by R
and by gridGraphics, is not evaluated by
[`do.call()`](https://rdrr.io/r/base/do.call.html), and reads as its
text. A formula is a call too, and stays one: it is read as a formula,
and evaluating one gives the formula back.
