# Read one DotPad setting from an option, then an environment variable

Read one DotPad setting from an option, then an environment variable

## Usage

``` r
maidr_dotpad_setting(option, envvar)
```

## Arguments

- option:

  Name of the R option

- envvar:

  Name of the environment variable consulted when the option is unset or
  empty

## Value

A single non-empty string, or `NULL`
