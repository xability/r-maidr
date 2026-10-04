# A Prefix for the Ids of One Chart Inlined into a Page

Unique across the R sessions whose output one page can merge (bookdown's
`new_session`, the knitr cache, child documents). Like
[`generate_unique_id()`](https://r.maidr.ai/reference/generate_unique_id.md)
it is built from the time in milliseconds, a per-session counter and the
process id, so it never draws on the user's random number stream.

## Usage

``` r
inline_id_prefix()
```

## Value

A string such as `"m0musl8x2k00002h00ahl-"`.

## Details

The shape is fixed: `m`, the three numbers in base 36 at widths of 9, 6
and 5 digits, and `-`. The fixed widths keep the joined fields
unambiguous without separators, and every prefix the same length, so no
prefix is the start of another and `[id^='<prefix>...']` cannot reach
into another chart. A separator would also split the prefix into tokens,
and maidr.js's tactile view drops every shape whose id holds a token
naming axis furniture (`axis`, `grid`, `text`, `tick`, ...): process id
1376804 is `tick` in base 36. One token starting with `m` can never be
such a word.
