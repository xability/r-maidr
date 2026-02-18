# Create enhanced wrapper for axis to capture scales:: format config

This wrapper intercepts axis() calls and checks if the labels argument
is a scales:: label function (closure). If so, it extracts the format
configuration before applying the function to get the actual labels.

## Usage

``` r
create_axis_wrapper(original_function)
```

## Arguments

- original_function:

  Original axis function

## Value

Enhanced wrapped function
