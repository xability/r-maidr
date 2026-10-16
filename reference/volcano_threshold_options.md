# The `thresholdOptions` a volcano or Manhattan layer declares

Checked here, when the layer is built, so that a threshold the core
would ignore – a string, a vector, `NA` – is an error the author sees
rather than a chart that silently claims nothing is significant.

## Usage

``` r
volcano_threshold_options(
  significance,
  direction,
  effect = NULL,
  caller = "maidr_volcano"
)
```

## Arguments

- significance:

  The cutoff on the y axis

- direction:

  `"above"` or `"below"`

- effect:

  The cutoff on the magnitude of x, or NULL

- caller:

  The declaring function's name, for the error messages

## Value

A list shaped as maidr.js's `ThresholdOptions`
