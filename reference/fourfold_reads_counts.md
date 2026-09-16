# Whether a `fourfoldplot()` call draws the table rather than its odds ratio

The dispatch-side wrapper over
[`fourfold_decline_reason()`](https://r.maidr.ai/reference/fourfold_decline_reason.md),
in the shape
[`is_two_way_table()`](https://r.maidr.ai/reference/is_two_way_table.md)
has over
[`recorded_two_way_table()`](https://r.maidr.ai/reference/recorded_two_way_table.md).

## Usage

``` r
fourfold_reads_counts(args)
```

## Arguments

- args:

  The arguments recorded from the
  [`fourfoldplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  call.

## Value

`TRUE` when the four quadrants are the four counts.
