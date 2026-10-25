# The `maidr-data` attribute's JSON

Selectors that resolved nothing are dropped and single ones flattened
first, and layer titles are made text; see
[`set_maidr_data_attr()`](https://r.maidr.ai/reference/set_maidr_data_attr.md)
and
[`layer_titles_as_text()`](https://r.maidr.ai/reference/layer_titles_as_text.md).

## Usage

``` r
maidr_data_json(maidr_data)
```

## Arguments

- maidr_data:

  The maidr-data structure

## Value

The JSON, a `json` string
