# Message for show()/save_html()/maidr_widget() with nothing recorded

Names the quantmod masking case when it applies: the bare "create a plot
first" wording is actively misleading there, because the user *did* draw
a chart — it just went to quantmod unrecorded.

## Usage

``` r
no_base_r_plots_message()
```

## Value

The error message string.
