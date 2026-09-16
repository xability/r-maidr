# Why a file is not the one the manifest describes, or `NULL`

Size first, because it is the failure with a story: the corrupt
`liblouis.data` that motivated the pin was 7,685 bytes short, and a size
says so where a digest only says "different".

## Usage

``` r
maidr_dotpad_file_mismatch(path, expected)
```

## Arguments

- path:

  The file on disk

- expected:

  One row of the manifest's `files`

## Value

A string naming the difference, or `NULL` when there is none

## Details

Then the digests base R can compute: MD5 always, and SHA-256 too from R
4.5, which added
[`tools::sha256sum()`](https://rdrr.io/r/tools/sha256sum.html). The
manifest carries both so the stronger check is used wherever it is
available without adding a dependency for the older R this package
supports.
