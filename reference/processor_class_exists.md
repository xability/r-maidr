# Whether a name refers to a processor class this package ships

The check used to be `exists(name, mode = "function")`, and a processor
is an R6 *generator* rather than a function, so it matched nothing –
`is.function(Ggplot2BarLayerProcessor)` is `FALSE` and `class(...)` is
`"R6ClassGenerator"`. Every entry a factory offered was filtered out by
it, so both factories reported an empty registry for every processor
they ship (#200).

## Usage

``` r
processor_class_exists(processor_class_name)
```

## Arguments

- processor_class_name:

  Name of the processor class.

## Value

`TRUE` when the name is an R6 generator that is reachable.
