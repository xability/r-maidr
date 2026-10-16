# pheatmap System Initialization

Register the pheatmap system with the global registry. The adapter
claims objects by their class alone, so where it is registered among the
others does not matter, except that it must come before Base R, whose
adapter claims by device state.

## Usage

``` r
initialize_pheatmap_system()
```

## Value

NULL (invisible)
