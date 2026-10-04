# Check a requested chart width or height

Check a requested chart width or height

## Usage

``` r
check_chart_size(value, arg)
```

## Arguments

- value:

  The value given: `NULL`, or a size in inches.

- arg:

  The argument's name, as the caller gave it.

## Value

`value`, invisibly. Stops unless it is `NULL` or one positive number no
larger than
[MAIDR_MAX_CHART_SIZE](https://r.maidr.ai/reference/MAIDR_MAX_CHART_SIZE.md).
