# Hand `jsonlite` each run of flat records as a data frame

A layer's `data` is usually one small named list per point, and
[`jsonlite::toJSON()`](https://jeroen.r-universe.dev/jsonlite/reference/fromJSON.html)
serializes a list element by element through S4 dispatch: 10,000 points
took 2 s of a 5 s ggplot2 render, more than the SVG export. A data frame
with the same columns is serialized row-wise in one vectorised pass and
yields byte-identical JSON under the options
[`set_maidr_data_attr()`](https://r.maidr.ai/reference/set_maidr_data_attr.md)
uses (`auto_unbox`, `na = "null"`, `digits = NA`), in about a hundredth
of the time.

## Usage

``` r
records_as_frames(node)
```

## Arguments

- node:

  A maidr-data node (list, or a leaf)

## Value

The node with record runs replaced by data frames

## Details

Only a run that is certain to serialize identically is converted: an
unnamed list of named lists that all have the same field names in the
same order, each field one attribute-free logical, integer, double or
character value of the same type in every record. Anything else – a
nested value, a ragged or mixed-type field, a factor or date, a
zero-length value (which serializes as `[]`, not `null`) – is left as a
list and recursed into, so the output never changes, only its cost.
