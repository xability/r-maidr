# Create a wrapper for functions taking unevaluated expressions

Used for functions like curve() whose arguments must stay lazy. The
recorded args are the unevaluated call expressions together with the
caller environment, so replay evaluates them exactly as the user's call
did.

## Usage

``` r
create_nse_wrapper(function_name, original_function)
```

## Arguments

- function_name:

  Name of the function

- original_function:

  Original function to wrap

## Value

Wrapped function
