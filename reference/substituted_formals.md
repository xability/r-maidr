# The formals a function reads with `substitute()`

Found in its code rather than listed, so a method maidr has not been
told about is read the same way: `substitute(x)` in the body or in a
default, such as
[`qqplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)'s
`xlab = deparse1(substitute(x))`.

## Usage

``` r
substituted_formals(definition)
```

## Arguments

- definition:

  A function

## Value

Character vector of formal names

## Details

Each function is read once and remembered: the walk takes about 2 ms
over [`hist.default()`](https://rdrr.io/r/graphics/hist.html), which a
loop of [`hist()`](https://r.maidr.ai/reference/base-r-wrappers.md)
calls would otherwise pay on every call. The functions read are the
recorded ones and the methods they dispatch to, a few dozen at most, and
[`identical()`](https://rdrr.io/r/base/identical.html) recognises the
same function by its address before comparing anything.
