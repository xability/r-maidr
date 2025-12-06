# Check Internal Guard Flag

Checks if we're currently in internal code (to prevent recursive
tracing).

## Usage

``` r
is_internal_call()
```

## Value

TRUE if internal guard is set, FALSE otherwise
