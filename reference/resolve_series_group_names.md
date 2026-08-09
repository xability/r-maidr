# Name each series after the category its built group id stands for

[`ggplot_build()`](https://ggplot2.tidyverse.org/reference/ggplot_build.html)
replaces the grouping column with integer group ids, so the user-facing
name has to be recovered from the plot's own data. The ids are assigned
in the sorted order of the grouping column's values, which is the order
this function relies on. Falls back to "Series " when the mapped column
is not present on the plot data (for example an expression such as
`aes(colour = paste(a, b))`).

## Usage

``` r
resolve_series_group_names(plot, group_ids, column = "group")
```

## Arguments

- plot:

  The ggplot2 object

- group_ids:

  The layer's built `group` column

- column:

  Name of the mapped grouping column

## Value

Character vector, one name per distinct group id in ascending order
