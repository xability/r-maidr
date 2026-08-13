# How long a cached internet probe stays trusted, in seconds

Five minutes: long enough that knitting a document with dozens of plots
still probes at most once or twice, short enough that connectivity that
changed under a long-lived session is picked up while the user is still
looking at it.

## Usage

``` r
MAIDR_INTERNET_CACHE_TTL
```
