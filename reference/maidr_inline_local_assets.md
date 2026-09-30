# Turn a saved document into one self-contained string

Replaces each local `<script src>` and `<link rel="stylesheet" href>`
that points beside the file with its contents.

## Usage

``` r
maidr_inline_local_assets(file)
```

## Arguments

- file:

  Path of an HTML document saved with its dependencies beside it

## Value

The document as a single string
