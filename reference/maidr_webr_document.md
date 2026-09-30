# Render an htmltools document to one self-contained string

Saves the document with its dependencies beside it, in a directory that
is removed again, and inlines what it points at; see
[`maidr_inline_local_assets()`](https://r.maidr.ai/reference/maidr_inline_local_assets.md).

## Usage

``` r
maidr_webr_document(html_doc)
```

## Arguments

- html_doc:

  An htmltools HTML document object

## Value

The document as a single string
