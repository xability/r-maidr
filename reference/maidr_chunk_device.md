# The device a chunk records and saves its figures with

svglite, in place of the `png` knitr gives HTML documents, so the static
figures of a page with inline charts are vector images too. Only that
default is replaced, in an R chunk of HTML output that shows charts
inline; any device the author chose is kept:

## Usage

``` r
maidr_chunk_device(options)
```

## Arguments

- options:

  Chunk options, as option hooks see them: before knitr's own fix-ups

## Value

The device's name

## Details

- a `dev` the chunk names, in its header or a `#|` line, or through an
  `opts.label` template;

- a document device other than `png`: YAML `dev:`, `opts_chunk$set()`,
  or Quarto's `fig-format:` other than its default `retina`, which is
  `png` at `fig.retina = 2`;

- several devices, a `fig.ext`, or `dev.args` svglite cannot take (knitr
  hands flat `dev.args` to the device unfiltered);

- a cached chunk: the device is part of the chunk's cache key, which
  knitr computes before the chunk can load maidr, so switching it would
  miss the cache on every render;

- a chunk whose figures are made something else of, as bitmaps: an
  animation (`fig.show = "animate"`, which gifski takes only as png and
  maidr never shows as a chart), `crop`, or a `fig.process` function;

- a chunk of another engine: Python saves its figures in the format
  `dev` names;

- `options(maidr.knitr_dev = FALSE)`, for a document whose `png` is a
  choice (`dev: png` in R Markdown's YAML cannot be told from the
  default).

knitr records a chunk's figures on svglite only from 1.44.
