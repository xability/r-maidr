# Check if Base R patching is currently active

Wrappers are installed once during .onLoad and remain in the namespace.
This flag controls whether they record calls or act as pass-through.

## Usage

``` r
is_patching_enabled()
```

## Value

TRUE if patching is active
