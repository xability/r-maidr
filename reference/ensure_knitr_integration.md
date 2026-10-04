# Install maidr's knitr integration into the running knit, once

Does nothing outside a knit, while interception is off
([`maidr_off()`](https://r.maidr.ai/reference/maidr_off.md),
`options(maidr.auto_show = FALSE)`), or when the integration is already
in place for this knit: the marker is set and maidr's plot and chunk
hooks are the ones knitr will call. The marker alone is not enough. A
document rendered from inside another one's chunk inherits the marker,
but not the hooks, and a document can set a hook of its own over
maidr's; either way, maidr installs itself again, over what is there.

## Usage

``` r
ensure_knitr_integration()
```

## Value

`TRUE` when the integration is in place for this knit, invisibly
