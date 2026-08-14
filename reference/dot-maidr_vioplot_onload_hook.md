# Wrap vioplot's entry point once its namespace is available

vioplot is in Suggests, so if it loads after maidr its
[`vioplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) has not
been wrapped yet and user calls would go unrecorded. Same shape as the
quantmod hook above, and registered beside it in `.onLoad`.

## Usage

``` r
.maidr_vioplot_onload_hook(...)
```
