# `<script>` tag that declares the DotPad SDK globals

Emitted ahead of `maidr.js` wherever this package loads the bundle, so
maidr.js finds the globals already set when it reads them. Nothing is
emitted when neither setting is configured: maidr.js then falls back to
the vendor's copy on jsDelivr, as documented in
[maidr-options](https://r.maidr.ai/reference/maidr-options.md).

## Usage

``` r
maidr_dotpad_config_script(config = maidr_dotpad_config())
```

## Arguments

- config:

  The settings, as returned by
  [`maidr_dotpad_config()`](https://r.maidr.ai/reference/maidr_dotpad_config.md)

## Value

A character string: the tag, or `""` when nothing is configured
