# The page dependencies of the charts a knitted document shows inline

A knitted HTML page shows its charts inline (see
[`knitr_inline_chart()`](https://r.maidr.ai/reference/knitr_inline_chart.md))
and loads `maidr.js` once for all of them. These are the dependencies it
declares for that: those of
[`maidr_html_dependencies()`](https://r.maidr.ai/reference/maidr_html_dependencies.md)
for the bundled copy, the bundle's own changed in two ways, and one
more:

## Usage

``` r
maidr_knitr_dependencies()
```

## Value

A list of htmlDependency objects: the configuration dependencies of
[`maidr_html_dependencies()`](https://r.maidr.ai/reference/maidr_html_dependencies.md),
the bundle, and `maidr-knitr`

## Details

- `maidr.js` is loaded with `defer`. In the iframes a document used
  before, the bundle never held up the page around them; in the page's
  `<head>`, 1.9 MB of script would hold up its first paint until it had
  loaded. That holds for a page that links the bundle from its `_files`
  folder: a self-contained page (`self_contained`, `embed-resources`)
  has the bundle inlined in its `<head>`, where `defer` does nothing.

- `maidr-math.css`, which `maidr.js` fetches from beside itself, is
  declared as an attachment, so every renderer copies it with the
  bundle: bookdown copies only the files a page references, and left a
  book's charts with no stylesheet for the maths in AI chat responses. A
  self-contained page drops the attachment, and has no URL to resolve it
  against either.

- `maidr-knitr`
  ([`maidr_knitr_dependency()`](https://r.maidr.ai/reference/maidr_knitr_dependency.md))
  binds the charts and keeps the host page's keyboard shortcuts out of
  them.

The `maidr` dependency of
[`save_html()`](https://r.maidr.ai/reference/save_html.md),
[`show()`](https://r.maidr.ai/reference/show.md) and the widgets is not
changed.
