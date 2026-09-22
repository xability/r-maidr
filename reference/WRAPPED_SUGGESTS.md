# The Suggests packages whose plotting entry point maidr wraps

Named by package, valued by the function. Each is wrapped into maidr's
own namespace when the package loads (the `onLoad` hooks below), so a
bare call reaches the wrapper only while `package:maidr` sits ahead of
the package on the search path. Attached after maidr, the package masks
the wrapper and its calls go unrecorded; see
[`package_masks_maidr()`](https://r.maidr.ai/reference/package_masks_maidr.md).

## Usage

``` r
WRAPPED_SUGGESTS
```
