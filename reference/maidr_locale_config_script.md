# The locale pack location as a `<script>` element

For the documents assembled from a template. It keeps a location the
page already declared, so an author's own tag wins whichever comes
first.

## Usage

``` r
maidr_locale_config_script(url = maidr_locale_base_url())
```

## Arguments

- url:

  As returned by
  [`maidr_locale_base_url()`](https://r.maidr.ai/reference/maidr_locale_base_url.md)

## Value

The element, or `""` when `url` is `NULL`
