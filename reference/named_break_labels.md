# The names the author gave the breaks a continuous axis's positions sit on

A continuous axis whose breaks the author named with text,
`scale_x_continuous(breaks = 1:12, labels = month.abb)`, codes a
category with a number: the axis shows "Feb" where the data holds 2.
When every position sits on a named break, each is read by the name, as
a discrete axis's positions are; when one falls between breaks, none is
(`tick_names_at()`). Labels a function makes from the numbers,
[`scales::label_dollar()`](https://scales.r-lib.org/reference/dollar_format.html)
and the like, format them rather than name them, and reach the reader
through the axis's format
([`extract_format_config()`](https://r.maidr.ai/reference/extract_format_config.md)).

## Usage

``` r
named_break_labels(values, built, panel_index, axis = "x")
```

## Arguments

- values:

  The positions, as ggplot2 built them: in the scale's own space, where
  its breaks are

- built:

  The built ggplot2 object

- panel_index:

  Index into `built$layout$panel_params`

- axis:

  `"x"` or `"y"`

## Value

A character vector as long as `values`, NA where a value is missing, or
NULL
