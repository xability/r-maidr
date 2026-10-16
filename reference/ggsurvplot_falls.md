# Whether each curve of a survminer figure falls from where it starts

A survival estimate never rises. A curve that does – `fun = "event"` or
`"cumhaz"` – is not one, and is not read as one.

## Usage

``` r
ggsurvplot_falls(rows)
```

## Arguments

- rows:

  The figure's data

## Value

TRUE or FALSE
