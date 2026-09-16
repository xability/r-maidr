# Download one file of the SDK

A seam for the tests, which replace it rather than reach the network.

## Usage

``` r
maidr_dotpad_download_file(url, destfile)
```

## Arguments

- url:

  Where the file is

- destfile:

  Where to write it

## Value

`destfile`, invisibly

## Details

Bounded rather than left to hang: a connection that takes more than half
a minute to open, or that delivers under a kilobyte a second for a full
minute, fails like any other error. A slow link still gets the 14 MB
engine; a stalled one does not hold the session for good.
