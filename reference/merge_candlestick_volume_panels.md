# Post-process a 2D subplot grid: if the layout is candlestick over volume-only bar (2 rows x 1 col, sharing an x-axis), collapse to a single 1x1 subplot whose layers are candlestick (+ embedded volume), bar, and optional line (multi-series MAs).

Post-process a 2D subplot grid: if the layout is candlestick over
volume-only bar (2 rows x 1 col, sharing an x-axis), collapse to a
single 1x1 subplot whose layers are candlestick (+ embedded volume),
bar, and optional line (multi-series MAs).

## Usage

``` r
merge_candlestick_volume_panels(grid)
```
