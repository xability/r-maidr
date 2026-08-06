# Strip internal violin_kde metadata without coordinate injection

Removes the temporary fields (\`.panel_x_range\`, \`.panel_y_range\`,
\`.is_horizontal\`, \`.panel_index\`, \`.panel_name\`, \`data_left_x\`,
\`data_right_x\`, \`data_y\`) that must never appear in the serialized
maidr-data JSON. Called unconditionally after coordinate injection, so a
layer whose panel viewport could not be navigated still comes out clean.

## Usage

``` r
strip_violin_kde_metadata(maidr_data)
```

## Arguments

- maidr_data:

  The maidr-data structure

## Value

Cleaned maidr_data
