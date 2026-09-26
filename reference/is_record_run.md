# Whether a list is a run of flat, uniformly typed records

The first record sets the field names and types every other record must
match exactly.

## Usage

``` r
is_record_run(node)
```

## Arguments

- node:

  A non-empty list

## Value

`TRUE` when
[`records_as_frames()`](https://r.maidr.ai/reference/records_as_frames.md)
may convert `node`
