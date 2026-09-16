# Where a downloaded copy of the DotPad SDK lives

The option `maidr.dotpad_sdk_dir`, then the environment variable
`MAIDR_DOTPAD_SDK_DIR`, then a per-user cache directory from
[`tools::R_user_dir()`](https://rdrr.io/r/tools/userdir.html)
(`~/.cache/R/maidr/dotpad-sdk/3.0.2` on Linux). Nothing is created by
asking.

## Usage

``` r
maidr_dotpad_sdk_dir()
```

## Value

A single path
