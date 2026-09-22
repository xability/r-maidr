# Is a package attached ahead of maidr on the search path?

[`library(quantmod)`](https://www.quantmod.com/) after
[`library(maidr)`](https://github.com/xability/r-maidr) puts
`package:quantmod` in front of `package:maidr`, so an unqualified
[`chartSeries()`](https://r.maidr.ai/reference/base-r-wrappers.md) binds
to quantmod's own function and maidr's recording wrapper is never
entered.
[`library(vioplot)`](https://github.com/TomKellyGenetics/vioplot) and
[`library(wordcloud)`](http://blog.fellstat.com/?cat=11) after maidr do
the same to
[`vioplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) and
[`wordcloud()`](https://r.maidr.ai/reference/base-r-wrappers.md): the
"No Base R plots detected" error that follows a bare call to either was
measured with maidr 0.5.0 (#320).

## Usage

``` r
package_masks_maidr(package)
```

## Arguments

- package:

  Name of the package, as in
  [WRAPPED_SUGGESTS](https://r.maidr.ai/reference/WRAPPED_SUGGESTS.md).

## Value

`TRUE` when both packages are attached and `package` comes first.

## Details

maidr deliberately does not reach into another package's namespace to
win this race: overwriting a foreign package's binding would also
redirect the package's *internal* calls through maidr's `...`-forwarding
wrapper, which for quantmod corrupts the
`match.call(expand.dots = TRUE)` it relies on. maidr reports the
condition instead.
