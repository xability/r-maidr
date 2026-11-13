# The title a position scale gives its axis, or NULL

ggplot2 titles an axis by its scale's name before
[`labs()`](https://ggplot2.tidyverse.org/reference/labs.html) and the
mapping: `scale_x_continuous("Month")` draws "Month" whatever
`labs(x = )` or `aes(month, ...)` say. A scale given no name, or NULL,
leaves the title to them.

## Usage

``` r
axis_scale_title(built, aes_name)
```

## Arguments

- built:

  The built ggplot2 object, or NULL

- aes_name:

  `"x"` or `"y"`

## Value

The name, or NULL

## Details

ggplot2 3.5 and later also take a function as the name, or a formula for
one, as `scale_x_continuous(toupper)` or `~ paste(.x, "(kg)")`: the axis
is titled by what it returns for the title the axis would otherwise
have. It is called on that title here too, as a legend's is
(`legend_title_value()`). Coerced as a string, the function stopped the
reading with "cannot coerce type 'closure' to vector of type
'character'". One that fails leaves the title to
[`labs()`](https://ggplot2.tidyverse.org/reference/labs.html) and the
mapping.

A name written in plotmath, as `quote(alpha^2)` or
`bquote(Delta ~ .(n) ~ m)`, is read as written (`plotmath_text()`):
coerced to text, a call was one string per part, and a two-sided formula
was taken for a function, and either was dropped for the title from
[`labs()`](https://ggplot2.tidyverse.org/reference/labs.html).
