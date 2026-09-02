# Is a recorded argument a formula, evaluated or not?

A value recorded on the ordinary path is a `formula` object; on the NSE
path the same argument is the unevaluated call to `~`, which
[`inherits()`](https://rdrr.io/r/base/class.html) does not recognise.

## Usage

``` r
is_formula_argument(value)
```

## Arguments

- value:

  A recorded argument

## Value

TRUE for either spelling
