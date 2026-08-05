# Check internet availability once per session

curl::has_internet() can block for seconds on offline machines, so the
result is cached for the session rather than probed per plot.

## Usage

``` r
maidr_internet_available()
```

## Value

TRUE if internet appears available
