# Wrap a single function

This is only called during .onLoad when the namespace is still open. The
wrapper checks is_patching_enabled() at runtime to decide whether to
record calls or pass through.

## Usage

``` r
wrap_function(function_name)
```

## Arguments

- function_name:

  Name of the function to wrap

## Value

TRUE if successful, FALSE otherwise
