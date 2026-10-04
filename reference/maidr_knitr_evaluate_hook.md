# maidr's knitr `evaluate` hook, over the hook it replaces

Runs a chunk's code with the hook it replaces, and then forgets the
pages replayed while the code ran (`forget_replayed_tokens()`): knitr
saves a chunk's figures, replaying each page, only once its code has
run, so a page the code replayed itself –
[`dev.print()`](https://rdrr.io/r/grDevices/dev2.html),
[`dev.copy()`](https://rdrr.io/r/grDevices/dev2.html),
[`replayPlot()`](https://rdrr.io/r/grDevices/recordplot.html) – would
otherwise be taken for the chunk's first figure. knitr looks the hook up
before a chunk runs, so the chunk that installed it is not run with it,
and is guarded instead (`guard_installing_chunk()`); the hook forgets
the guard of such a chunk once it has run.

## Usage

``` r
maidr_knitr_evaluate_hook(previous)
```

## Arguments

- previous:

  The `evaluate` hook in place before; knitr evaluates with
  [`evaluate::evaluate()`](https://r.maidr.ai/reference/evaluate.r-lib.org/reference/evaluate.md)
  when there is none

## Value

An `evaluate` hook
