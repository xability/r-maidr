# Check if current knitr output format is HTML

Detects whether the current RMarkdown document is being rendered to HTML
format (html_document, bookdown, etc.) vs non-HTML formats (pdf, etc.)

## Usage

``` r
is_html_output()
```

## Value

TRUE if rendering to HTML, FALSE otherwise

## Details

Markdown output (`github_document`, `md_document`,
[`knitr::knit()`](https://rdrr.io/pkg/knitr/man/knit.html) of an
`.Rmd`), which knitr also counts as HTML, is not: GitHub and most
Markdown viewers drop an iframe, and rmarkdown refuses the dependency a
frame brings, so a chart in one was either lost or stopped the render.
Its charts are drawn as their libraries draw them, as knitr's figures.
So are EPUB's, whose writer refuses HTML a chart brings unless the
document allows it, and whose readers would not run maidr.js anyway, and
xaringan's, whose remark.js shows a chart's raw HTML as text on the
slide.
