# Return a `withVisible()` result with the visibility it recorded

The wrappers used to return everything invisibly, so `par("mar")`
printed nothing once maidr was attached and `hist(x, plot = FALSE)` had
to be wrapped in [`print()`](https://rdrr.io/r/base/print.html) to be
seen.

## Usage

``` r
as_drawn(result)
```

## Arguments

- result:

  A list from [`withVisible()`](https://rdrr.io/r/base/withVisible.html)

## Value

The value, invisibly when the original call made it so
