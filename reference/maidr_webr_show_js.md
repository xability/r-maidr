# JavaScript that shows a finished document on the page

Hands it to `globalThis.maidrWebRShow(html)` when the page defines one.
Otherwise the document goes into an iframe, in the element with id
`maidr-output` when the page has one, else at the end of `<body>`. The
frame is sized to its content, and carries the listener
[`maidr_iframe_host_script()`](https://r.maidr.ai/reference/maidr_iframe_host_script.md)
gives every MAIDR frame, so the keyboard can leave the chart.

## Usage

``` r
maidr_webr_show_js(html)
```

## Arguments

- html:

  The self-contained document, a string

## Value

A JavaScript expression that evaluates to `true`
