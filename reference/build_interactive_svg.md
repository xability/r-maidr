# Build the Interactive SVG, or Answer NULL When It Cannot Be Built

`should_fallback()` answers whether the recorded layers are ones maidr
can read. It cannot answer whether the plot can be *exported*, because
that is gridSVG's question and gridSVG is not consulted until the export
runs. Two base R charts fail there on plots that pass the gate –
[`matplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) with
"non-numeric argument to binary operator" and
[`symbols()`](https://r.maidr.ai/reference/base-r-wrappers.md) with
gridSVG's own "We shouldn't be here!" assertion, both raised inside
`grid.export()` rather than by anything this package computes.

## Usage

``` r
build_interactive_svg(orchestrator, ...)
```

## Arguments

- orchestrator:

  The orchestrator for the plot being rendered.

- ...:

  Passed through to
  [`create_enhanced_svg()`](https://r.maidr.ai/reference/create_enhanced_svg.md).

## Value

The SVG content, or `NULL` when the build failed and fallback is
enabled.

## Details

Left to propagate, those kill the save outright: the caller gets neither
the interactive chart nor the static image, and an error naming a
package they never called. The lower claim the package makes about a
recorded plot is that it is *at worst a picture* (#216), and an export
that throws is no more a reason to break that than a layer it cannot
classify.

The whole build is guarded rather than the export alone. From the
caller's side the gtable, the data and the SVG are one step – producing
the interactive chart – and which of the three threw does not change
what they should be given instead.

`maidr_set_fallback(enabled = FALSE)` is the caller asking for the
failure rather than the picture, so the error is re-raised untouched
there.
