# The titles a `plot()` method derives that R draws

A method of [`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
draws the title it derives for an axis, such as "Time" or the series as
written, only where the call gives that axis no title of its own:
`ylab = ""` is drawn as the blank it is, in place of the title, and
`ann = FALSE` draws no titles at all. Without an `ann` of its own, the
call draws them as `par("ann")` said when it was made, so
`par(ann = FALSE)` turns them off too. Read through
[`recorded_axis_label()`](https://r.maidr.ai/reference/recorded_axis_label.md),
which takes a blank for no title, the title R did not draw was
announced: "AirPassengers" for `plot(AirPassengers, ylab = "")`.

## Usage

``` r
drawn_default_titles(args, titles, ann = TRUE)
```

## Arguments

- args:

  Recorded argument list

- titles:

  List with `x` and `y`, the titles the method derives

- ann:

  What `par("ann")` was when the call was made

## Value

`titles`, without each one R does not draw

## Details

A title given as NULL is no title of the call's own: where the method
draws one for it,
[`plot_axis_titles()`](https://r.maidr.ai/reference/plot_axis_titles.md)
says which. A title the call writes itself is
[`recorded_axis_label()`](https://r.maidr.ai/reference/recorded_axis_label.md)'s
to read.
