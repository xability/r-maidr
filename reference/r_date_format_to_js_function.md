# Convert R Date Format to JavaScript Function

Creates a JavaScript function string that formats dates according to an
R strftime format string. Used for complex date formats that cannot be
represented by Intl.DateTimeFormat options alone.

## Usage

``` r
r_date_format_to_js_function(format, tz = "UTC")
```

## Arguments

- format:

  R date format string

- tz:

  Timezone

## Value

JavaScript function body string
