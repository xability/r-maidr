# Whether ggplot2 evaluates a mapping after the stat

As ggplot2 decides it: an
[`after_stat()`](https://ggplot2.tidyverse.org/reference/aes_eval.html),
a [`stage()`](https://ggplot2.tidyverse.org/reference/aes_eval.html)
given an `after_stat` argument, or the older
[`stat()`](https://ggplot2.tidyverse.org/reference/aes_eval.html) and
`..count..` spellings, anywhere in the expression; not an
[`after_scale()`](https://ggplot2.tidyverse.org/reference/aes_eval.html),
which is evaluated on the colours.

## Usage

``` r
heat_after_stat(mapping)
```

## Arguments

- mapping:

  A quosure or expression from
  [`aes()`](https://ggplot2.tidyverse.org/reference/aes.html), or NULL

## Value

`TRUE` or `FALSE`
