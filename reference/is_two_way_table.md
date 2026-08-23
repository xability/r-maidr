# Whether a `mosaicplot()` call was handed a two-way table

A `mosaic` layer has one category axis and one fill, so it can carry a
two-dimensional table and no more.
[`mosaicplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
accepts deeper ones and splits them recursively.

## Usage

``` r
is_two_way_table(args)
```

## Arguments

- args:

  The arguments recorded from the
  [`mosaicplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  call.

## Value

`TRUE` when the call's table has exactly two dimensions.

## Details

The table itself is resolved by
[`recorded_two_way_table()`](https://r.maidr.ai/reference/recorded_two_way_table.md),
which the processor also reads, so dispatch and extraction cannot
disagree about which calls are readable.
