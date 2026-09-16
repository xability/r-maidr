# A downloaded SDK as an htmltools dependency

For the documents [`show()`](https://r.maidr.ai/reference/show.md) and
[`save_html()`](https://r.maidr.ai/reference/save_html.md) write.
htmltools copies the directory into `<libdir>/dotpad-sdk-3.0.2/` when
the document is saved, and the dependency's `head` declares the two
globals with that relative path, so the saved page finds its copy
wherever the folder is moved to, as long as the two move together.
`libdir` is what
[`htmltools::save_html()`](https://rstudio.github.io/htmltools/reference/save_html.html)
is called with; its default is what this package uses.

## Usage

``` r
maidr_dotpad_sdk_dependency(dir = maidr_dotpad_sdk_dir(), libdir = "lib")
```

## Arguments

- dir:

  A complete copy, as
  [`maidr_dotpad_sdk_available()`](https://r.maidr.ai/reference/maidr_dotpad_sdk_available.md)
  reports

- libdir:

  The `libdir` the document is saved with

## Value

An
[`htmltools::htmlDependency()`](https://rstudio.github.io/htmltools/reference/htmlDependency.html)
