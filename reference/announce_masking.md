# Say, as a package is attached, that it now masks a maidr wrapper

Run from the attach hooks below. By then the package sits ahead of maidr
on the search path, so this is the moment to tell the user that bare
calls to its entry point will no longer be recorded. Silent when the
package does not mask, and under `maidr.startup_message = FALSE`.

## Usage

``` r
announce_masking(package)
```

## Arguments

- package:

  Name of the package, as in
  [WRAPPED_SUGGESTS](https://r.maidr.ai/reference/WRAPPED_SUGGESTS.md).
