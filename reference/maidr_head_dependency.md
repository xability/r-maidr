# A dependency that only writes to the document's `<head>`

The DotPad SDK and locale pack settings reach maidr.js as globals,
declared in a dependency's `head` (see
[`maidr_dotpad_config_dependency()`](https://r.maidr.ai/reference/maidr_dotpad_config_dependency.md)
and
[`maidr_locale_config_dependency()`](https://r.maidr.ai/reference/maidr_locale_config_dependency.md));
there is no file to serve. Such a dependency still names a directory on
disk, the bundle's, without declaring any file in it. Quarto copies
every dependency of a document with
[`htmltools::copyDependencyToDir()`](https://rstudio.github.io/htmltools/reference/copyDependencyToDir.html),
which refuses one that names none ("is not disk-based"), so a `.qmd`
showing a chart through
[`maidr_htmlwidget()`](https://r.maidr.ai/reference/maidr_htmlwidget.md)
did not render at all. As it declares no file, none is copied for it,
and every document renders it as before: its `head` alone.

## Usage

``` r
maidr_head_dependency(name, head)
```

## Arguments

- name:

  The dependency's name

- head:

  The markup it writes to the `<head>`

## Value

A single htmltools::htmlDependency()
