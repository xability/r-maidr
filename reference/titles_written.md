# The axis titles one recorded call writes in a margin

The axis titles one recorded call writes in a margin

## Usage

``` r
titles_written(call)
```

## Arguments

- call:

  A recorded LOW-level call

## Value

A list of titles, as
[`margin_titles()`](https://r.maidr.ai/reference/margin_titles.md)
describes them: the `xlab` and `ylab` a
[`title()`](https://r.maidr.ai/reference/base-r-wrappers.md) call
writes, or the one an
[`mtext()`](https://r.maidr.ai/reference/base-r-wrappers.md) call does
([`mtext_axis_title()`](https://r.maidr.ai/reference/mtext_axis_title.md));
empty for any other call, a blank title, or one in the outer margin
