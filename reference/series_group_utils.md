# Series-Group Helpers

A layer whose grouping aesthetic is mapped (for example
`aes(colour = g)`) draws one curve per group. MAIDR describes that as
one series per group, each point carrying the group's name as `z`, and
names those values with the legend title as the z axis label. These
helpers are shared by the ggplot2 line and smooth layer processors so
that a grouped
[`geom_line()`](https://ggplot2.tidyverse.org/reference/geom_path.html)
and a grouped
[`geom_smooth()`](https://ggplot2.tidyverse.org/reference/geom_smooth.html)
are described the same way.
