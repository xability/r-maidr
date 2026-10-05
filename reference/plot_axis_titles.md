# The axis titles a recorded `plot()` call writes

Each method of
[`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) titles its
axes its own way, so the titles are read by the method the call reached.

## Usage

``` r
plot_axis_titles(plot_call)
```

## Arguments

- plot_call:

  A recorded [`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  call

## Value

List with `x` and `y`, or an empty list when the method reached writes
no titles maidr reads

## Details

- [`plot.default()`](https://rdrr.io/r/graphics/plot.default.html):
  whatever [`xy.coords()`](https://rdrr.io/r/grDevices/xy.coords.html)
  makes of `x` and `y`.

- [`plot.ts()`](https://rdrr.io/r/stats/plot.ts.html), for one series:
  "Time" against the series' one column name or, without one, the series
  as written.

- `plot.table()`, for a one-way table: the table's dimension name, when
  it has one, against the table as written.

- `plot.data.frame()`, for a frame of two columns: the two column names.

An `xlab` or `ylab` given as NULL is the method's to read too.
[`plot.default()`](https://rdrr.io/r/graphics/plot.default.html) and
`plot.table()` draw their own title for it, but
[`plot.ts()`](https://rdrr.io/r/stats/plot.ts.html) draws none, and
`plot.data.frame()` hands it on to
[`plot.default()`](https://rdrr.io/r/graphics/plot.default.html), which
titles the axis after the column it was handed, `x[[1L]]` or `x[[2L]]`.

Any other method gives none, and so do these where they draw something
else: several series in panels, a mosaic, a strip chart or a pairs plot.
An argument written before the one the method was dispatched on, as in
`plot(main = "Nile", Nile)`, changes none of this.
