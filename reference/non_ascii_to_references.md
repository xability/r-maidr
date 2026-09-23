# Replace every non-ASCII character with a numeric character reference

Found and replaced as bytes. The same work done in characters, with a
UTF-8 `perl` regex, takes seconds on a document carrying the 1.8 MB
bundle, where this takes milliseconds: in bytes, a run of non-ASCII is a
run of bytes from 0x80 up, and nothing has to count characters to find
it.

## Usage

``` r
non_ascii_to_references(x)
```

## Arguments

- x:

  A single string whose bytes are UTF-8, marked or not

## Value

`x` in ASCII, or unchanged when it is already ASCII or its bytes are not
valid UTF-8
