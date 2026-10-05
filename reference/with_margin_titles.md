# A layer's axes, titled as the `title()` and `mtext()` calls written on them

An author who blanks a plot's own titles, with `xlab = ""` or
`ann = FALSE`, often writes them with
[`title()`](https://r.maidr.ai/reference/base-r-wrappers.md) or
[`mtext()`](https://r.maidr.ai/reference/base-r-wrappers.md) instead, on
a line of their own choosing. R draws those on the axes, but a layer's
axes are read from the plot's own call, so the reader heard them
untitled: "X is 1.51" where R drew "Weight".

## Usage

``` r
with_margin_titles(axes, titles)
```

## Arguments

- axes:

  The layer's canonical axes, or NULL

- titles:

  The titles written on the axes of the layer's plot, from
  [`margin_titles()`](https://r.maidr.ai/reference/margin_titles.md), in
  the order they were written

## Value

`axes`, with those titles

## Details

- `title(xlab =, ylab =)` draws where the plot's own title goes, so it
  titles that axis, over whatever the plot drew there: the last one
  written is the one on top.

- [`mtext()`](https://r.maidr.ai/reference/base-r-wrappers.md) writes
  any text in a margin. One string centred on the side an axis is drawn
  on, as an axis title is, titles that axis where the layer has no title
  of its own, as `plot(x, y, ann = FALSE)` leaves it: maidr's "Category"
  and "Value", and a title
  [`hist()`](https://r.maidr.ai/reference/base-r-wrappers.md) or
  [`curve()`](https://r.maidr.ai/reference/base-r-wrappers.md) derives,
  are the layer's own. One set off to a side, with `adj` or `at`, is a
  note, and so is one written farther out than another on that side: a
  note under the title, such as where the data came from, is written on
  a line farther from the axis. Of those on one line the last one
  written is the one on top, and one inside the plot, on a line below 0,
  titles the axis only where the margin has none.

Which axis each one titles is
[`margin_titles()`](https://r.maidr.ai/reference/margin_titles.md)'s to
say.
