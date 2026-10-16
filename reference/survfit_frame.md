# A `survfit` object's curves as rows, from the origin the plot starts at

One row per time each stratum reports, after
[`survival::survfit0()`](https://rdrr.io/pkg/survival/man/survfit0.html)'s
added origin: the time, the survival estimate, the band's bounds (`NA`
where the fit kept none), whether a subject was censored there
(`n.censor`, or a time with no event when the fit counts no censoring)
and the stratum's index. Shared by the Base R reading of
[`plot()`](https://r.maidr.ai/reference/base-r-wrappers.md) and by
[`maidr_survival()`](https://r.maidr.ai/reference/maidr_survival.md), so
both read one object the same way.

## Usage

``` r
survfit_frame(fit)
```

## Arguments

- fit:

  A `survfit` object accepted by
  [`survfit_readable()`](https://r.maidr.ai/reference/survfit_readable.md)

## Value

A data frame with columns `time`, `surv`, `lower`, `upper`, `censored`
and `stratum`, and the strata's names as its `"strata"` attribute (NULL
without strata)
