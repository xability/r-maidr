# Whether one record matches the run's fields and types exactly

Whether one record matches the run's fields and types exactly

## Usage

``` r
is_flat_record(record, fields, types)
```

## Arguments

- record:

  A candidate record

- fields:

  The run's field names, in order

- types:

  The run's field types, in order

## Value

`TRUE` when every field is one attribute-free value of its type
