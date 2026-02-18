# Clean MAIDR internal arguments from args list

Removes internal arguments (starting with .maidr\_) from an args list
before passing to original functions during replay.

## Usage

``` r
clean_maidr_args(args)
```

## Arguments

- args:

  List of arguments

## Value

Cleaned args list without .maidr\_\* entries
