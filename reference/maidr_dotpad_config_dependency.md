# The DotPad SDK globals as an htmltools dependency

For the paths that assemble their document from dependencies rather than
a template: [`show()`](https://r.maidr.ai/reference/show.md),
[`save_html()`](https://r.maidr.ai/reference/save_html.md) and the knitr
widget. The globals ride in the dependency's `head`, and the dependency
is listed ahead of the `maidr` one so the head lands before the bundle's
`<script>`.

## Usage

``` r
maidr_dotpad_config_dependency(config = maidr_dotpad_config())
```

## Arguments

- config:

  The settings, as returned by
  [`maidr_dotpad_config()`](https://r.maidr.ai/reference/maidr_dotpad_config.md)

## Value

An
[`htmltools::htmlDependency()`](https://rstudio.github.io/htmltools/reference/htmlDependency.html),
or `NULL` when nothing is configured
