# The locale pack location as an htmltools dependency

For the paths that assemble their document from dependencies:
[`show()`](https://r.maidr.ai/reference/show.md),
[`save_html()`](https://r.maidr.ai/reference/save_html.md), the
htmlwidget and knitr. htmltools writes a dependency's `head` after its
scripts, so the location rides in a dependency of its own, listed ahead
of the `maidr` one, as
[`maidr_dotpad_config_dependency()`](https://r.maidr.ai/reference/maidr_dotpad_config_dependency.md)
does.

## Usage

``` r
maidr_locale_config_dependency(use_cdn = FALSE)
```

## Arguments

- use_cdn:

  Whether the document loads maidr.js from the CDN

## Value

An
[`htmltools::htmlDependency()`](https://rstudio.github.io/htmltools/reference/htmlDependency.html),
or `NULL` when nothing is to be declared
