# Whether the first record's fields can become data frame columns

Each field becomes one column, so the names must be unique and non-empty
and every type one that a column can hold a scalar of.

## Usage

``` r
is_record_schema(fields, types)
```

## Arguments

- fields:

  The first record's names

- types:

  The first record's field types

## Value

`TRUE` for unique, non-empty names over scalar-capable types
