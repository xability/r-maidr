# Strip internal violin_kde metadata without coordinate injection

Fallback used when the panel viewport cannot be navigated: removes the
temporary fields (\`.panel_x_range\`, \`.panel_y_range\`,
\`.is_horizontal\`, \`data_left_x\`, \`data_right_x\`, \`data_y\`) that
must never appear in the serialized maidr-data JSON.

## Usage

``` r
strip_violin_kde_metadata(maidr_data)
```

## Arguments

- maidr_data:

  The maidr-data structure

## Value

Cleaned maidr_data
