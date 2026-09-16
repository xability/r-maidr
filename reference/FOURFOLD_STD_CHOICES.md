# The `std` choices `graphics::fourfoldplot()` offers

Written out rather than read from `formals(graphics::fourfoldplot)$std`,
which is an unevaluated `call` of length 4 (measured:
[`class()`](https://rdrr.io/r/base/class.html) is `"call"`, and
`formals(...)$std[[1]]` is the symbol `c`) and would have to be
[`eval()`](https://rdrr.io/r/base/eval.html)ed on every dispatch. That
the literal still matches upstream is asserted against the real
[`formals()`](https://rdrr.io/r/base/formals.html) in
`tests/testthat/test-base-r-fourfoldplot.R`, the answer the `qqplot`
branch gives to the same exposure.

## Usage

``` r
FOURFOLD_STD_CHOICES
```
