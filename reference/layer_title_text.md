# A layer `title` as maidr.js reads it: one string, or none

maidr.js reads a layer's `title` as text. A layer processor that names
no title leaves `NULL` in the slot the orchestrator gives it, and
[`jsonlite::toJSON()`](https://jeroen.r-universe.dev/jsonlite/reference/fromJSON.html)
writes `NULL` as an empty object,
[`{}`](https://rdrr.io/r/base/Paren.html). maidr.js took that object for
a title and failed on it: `d` opened no description, and `L` then `T`
said nothing and left the reader in label mode, where every other key
was refused. A ggplot2 box plot, heat map, scatter plot, smooth, violin,
volcano and gantt chart all carried one.

## Usage

``` r
layer_title_text(title)
```

## Arguments

- title:

  A layer's `title`, as a processor returned it

## Value

One string, or `NULL`

## Details

A value that is not a string, a factor level for instance, is written as
the string it prints as, and lines given as several strings are joined
with a space. Anything else is dropped, and a layer without a title is
read under the figure's.
