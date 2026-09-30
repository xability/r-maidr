# Hand a finished document to the page webR runs in

In order: the function in `options(maidr.webr_display)`, called with the
HTML string; then the page, see
[`maidr_webr_show_js()`](https://r.maidr.ai/reference/maidr_webr_show_js.md);
otherwise, when there is no page to reach, the document is written to a
file and its path is reported.

## Usage

``` r
maidr_webr_display(html)
```

## Arguments

- html:

  The self-contained document, a string

## Value

Invisibly, the file path when nothing showed the document
