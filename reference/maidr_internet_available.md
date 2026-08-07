# Check internet availability, with a time-boxed cache

curl::has_internet() can block for seconds on offline machines, so the
result is cached rather than probed per plot. The cache is time-boxed to
MAIDR_INTERNET_CACHE_TTL seconds so a stale answer self-heals: a
transient failure does not pin the rest of the session to inlining the
multi-megabyte bundle, and a session that goes offline after a
successful probe stops emitting documents that point at a CDN it can no
longer reach.

## Usage

``` r
maidr_internet_available()
```

## Value

TRUE if internet appears available
