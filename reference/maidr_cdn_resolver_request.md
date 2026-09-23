# Fetch one resolver endpoint

The only function in this package that makes the version lookup's
request, so tests replace it and never reach the network.

## Usage

``` r
maidr_cdn_resolver_request(url, timeout)
```

## Arguments

- url:

  Endpoint URL

- timeout:

  Seconds allowed for the whole transfer

## Value

The response body as a string; an error on any failure
