# Embed volume y-values from a bar layer into the candlestick layer's data.

Strategy: 1. If both layers have the same number of points, embed
positionally. This is the canonical case: patchwork stacks two panels
driven by the same date column, so the i-th candle and the i-th bar
refer to the same trading day even if the bar layer's x is formatted
differently from the candle's \`value\`. 2. Otherwise, fall back to
string-matching the candle's \`value\` field against the bar layer's
\`x\` field.

## Usage

``` r
embed_volume_into_candle_data(candle_layer, bar_layer)
```
