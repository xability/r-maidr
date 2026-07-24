# Collapse multiple "line" layer entries in a single panel into one multi-series line layer entry. Other layers are left untouched.

The first line layer's id, title, and axes are preserved; data and
selectors are concatenated across all line layers.

## Usage

``` r
collapse_lines_to_multiseries(panel)
```

## Arguments

- panel:

  A processed panel list with \$id and \$layers

## Value

Panel with line layers merged
