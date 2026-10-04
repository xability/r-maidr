# Whether a chart is shown inline in the document being knitted

True while knitting HTML that pandoc writes as a page a browser opens:
`html_document` and the formats built on it, bookdown, Quarto,
reveal.js, ioslides, slidy, dashboards. Not for a document knitted
without pandoc (`.Rhtml`, or
[`knitr::knit()`](https://rdrr.io/pkg/knitr/man/knit.html) to Markdown),
nor for the outputs knitr also counts as HTML: Markdown and GitHub
Markdown, whose readers drop the script, EPUB, and xaringan, whose
remark.js shows a raw HTML block as text. Not for an HTML fragment
either, which has no `<head>` for maidr.js, nor for pagedown, whose
paged.js rebuilds the page before maidr.js could bind a chart in it.
Markdown, EPUB and xaringan keep the plot as its library draws it
([`is_html_output()`](https://r.maidr.ai/reference/is_html_output.md));
the others keep a chart in an iframe of its own.

## Usage

``` r
inline_output_ok()
```

## Value

Logical
