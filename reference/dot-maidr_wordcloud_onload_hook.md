# Wrap wordcloud's entry point once its namespace is available

Same shape and same reason as the vioplot hook above: `wordcloud` is in
Suggests, so a call made after a late
[`library(wordcloud)`](http://blog.fellstat.com/?cat=11) would otherwise
go unrecorded entirely.

## Usage

``` r
.maidr_wordcloud_onload_hook(...)
```
