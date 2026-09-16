# Whether a directory holds a complete copy of the SDK

Complete means every file in the manifest is present at its recorded
size. The digests are checked when the copy is made, not on every
render, so this costs a handful of
[`file.info()`](https://rdrr.io/r/base/file.info.html) calls.

## Usage

``` r
maidr_dotpad_sdk_available(dir = maidr_dotpad_sdk_dir())
```

## Arguments

- dir:

  Where to look

## Value

`TRUE` or `FALSE`
