# Restore original functions

Deactivates patching by flipping the active flag. Wrappers remain in the
namespace but act as pass-through (calling the original function
directly). This avoids modifying the locked namespace or the search
path.

## Usage

``` r
restore_original_functions()
```

## Value

NULL (invisible)
