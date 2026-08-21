# The processor classes a factory's `create_processor()` dispatches to

Read off the method rather than kept beside it. The list a factory used
to return was written out by hand and consulted by nothing, so it
drifted freely: by the time \#200 was filed it was missing four of the
twenty ggplot2 processors and one of the fourteen base R ones, and
nothing in the package or its tests could tell. A second list is a
second thing to keep true; asking the dispatch itself is one thing that
cannot disagree with itself.

## Usage

``` r
dispatched_processor_classes(generator, prefix)
```

## Arguments

- generator:

  The factory's `R6ClassGenerator`.

- prefix:

  The class-name prefix its processors share.

## Value

Character vector of class names, in the order first dispatched.

## Details

`deparse(body(...))` is used rather than reading `R/`, because an
installed package has no `R/` to read – the sources are gone by then and
only the parsed function survives.
