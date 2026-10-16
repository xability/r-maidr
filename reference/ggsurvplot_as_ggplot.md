# The ggplot2 figure maidr reads from a `survminer::ggsurvplot()` object

survminer draws a Kaplan-Meier figure as a
[`geom_step()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
of the curves, a stepped ribbon of the band (its own `GeomConfint`) and
a
[`geom_point()`](https://ggplot2.tidyverse.org/reference/geom_point.html)
of the censored times, all from one data frame that carries `time`,
`surv`, `n.censor`, `lower` and `upper`. Those three layers are redrawn
as one
[`maidr_survival()`](https://r.maidr.ai/reference/maidr_survival.md)
layer from that frame – the band at survminer's opacity and the marks in
its shape and size – so the figure is read as a `survival` layer rather
than as a step, an unreadable ribbon and a scatter of the censored
times.

## Usage

``` r
ggsurvplot_as_ggplot(x)
```

## Arguments

- x:

  Any object

## Value

`x`, or for a `ggsurvplot` object the ggplot to read

## Details

Anything else is handed back as the figure's plot unchanged: a figure
with no single curve layer, a band drawn some other way
(`conf.int.style = "step"`), or a curve that does not fall
(`fun = "event"`, `"cumhaz"`), which is not a survival probability. The
risk table and the other parts of the object are not read, and a message
says so when there is one.
