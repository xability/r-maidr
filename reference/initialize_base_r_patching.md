# Initialize Base R function patching

This function sets up the function patching system by wrapping Base R
plotting functions (HIGH, LOW, and LAYOUT levels). It should be called
before any Base R plotting commands.

## Usage

``` r
initialize_base_r_patching(include_low = TRUE, include_layout = TRUE)
```

## Arguments

- include_low:

  Include LOW-level functions (lines, points, etc.)

- include_layout:

  Include LAYOUT functions (par, layout, etc.)

## Value

NULL (invisible)
