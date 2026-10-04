# Note a chart whose page is being replayed

The callback of every marker (`mark_knit_page()`), through the
`maidr.knit.replayed` option. A chart something else was drawn over is
noted under a token no chart has, so its figure stays knitr's
(`knit_marker_overdrawn()`).

## Usage

``` r
knit_page_replayed(token, page)
```

## Arguments

- token:

  The chart's token

- page:

  The page it was drawn on, `NA` for several

## Value

NULL (invisible)
