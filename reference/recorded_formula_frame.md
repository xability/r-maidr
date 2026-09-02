# Resolve a recorded formula into the frame the chart was drawn from

Base R calls are recorded and read later, at
[`show()`](https://r.maidr.ai/reference/show.md)/[`save_html()`](https://r.maidr.ai/reference/save_html.md)
time, and for every argument but one that is harmless: the wrapper
records *evaluated values*, so a vector recorded is a vector and
rebinding the name it came from afterwards changes nothing.

## Usage

``` r
recorded_formula_frame(
  args,
  call_env = NULL,
  formula = recorded_formula(args, call_env)
)
```

## Arguments

- args:

  Recorded argument list

- call_env:

  The environment snapshot a deferred call was recorded with, or NULL
  when every argument is a plain value.

- formula:

  The formula the call carries, as
  [`recorded_formula()`](https://r.maidr.ai/reference/recorded_formula.md)
  resolves it; passed in when the recorder has already resolved it.

## Value

The model frame, or NULL when the call carries no formula or the frame
cannot be built – in which case the reader falls back to resolving it
itself, exactly as before.

## Details

A formula is the exception. It is a reference rather than a value – it
carries the environment it was written in – and a processor that calls
[`stats::model.frame()`](https://rdrr.io/r/stats/model.frame.html) on it
at render time resolves the variables **then**. Measured (#254):

    len  <- c(1, 2, 3, 10, 11, 12); supp <- rep(c("OJ", "VC"), each = 3)
    stripchart(len ~ supp)              # draws 1,2,3 under OJ
    len  <- c(99, 98, 97, 96, 95, 94)   # the user carries on working
    supp <- rep(c("XX", "YY"), each = 3)
    save_html(file = f)                 # announced 99,98,97 under XX

Every value and both group names belonged to bindings made after the
drawing, and it was silent: the figure rendered as an interactive chart
rather than as a fallback, so nothing said the numbers had moved.

So the frame is built **here**, while the call is being recorded and the
bindings are still the ones the chart was drawn from.
`stripchart.formula` and `boxplot.formula` build the same
`stats::model.frame(formula, data)` as they draw, so this is the frame
they used rather than a reconstruction of it.

Fixed at the recording layer rather than per processor because anything
that reads a formula later inherits the same defect.
