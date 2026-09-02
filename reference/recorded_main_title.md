# The `main` title a recorded call wrote, as text

`main = expression(alpha^2)` is an ordinary way to put a Greek letter on
a chart, and a dozen readers passed the recorded value straight into the
layer's `title`.
[`jsonlite::toJSON()`](https://jeroen.r-universe.dev/jsonlite/reference/fromJSON.html)
has no method for an expression, so the whole save failed on a title. A
title that is not text is announced as empty rather than failing the
chart it sits on; the drawing keeps it.

## Usage

``` r
recorded_main_title(args)
```

## Arguments

- args:

  Recorded argument list

## Value

Character scalar, empty when there is no usable title

## Details

Exact-name lookup, since `args$main` would partial-match nothing today
but is the same shape as the `args$x` / `xlab` collision that emptied
[`monthplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) (#292).
