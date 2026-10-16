# ComplexHeatmap System Initialization

Register the ComplexHeatmap system with the global registry. The adapter
claims objects by their class alone, so it must come before Base R,
whose adapter claims by device state.

## Usage

``` r
initialize_complexheatmap_system()
```

## Value

NULL (invisible)
