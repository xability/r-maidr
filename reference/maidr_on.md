# Enable MAIDR Rendering in RMarkdown

Enables automatic accessible rendering of ggplot2 and Base R plots in
RMarkdown documents. When enabled, plots are automatically converted to
interactive MAIDR widgets with keyboard navigation and screen reader
support.

## Usage

``` r
maidr_on()
```

## Value

Invisible TRUE on success

## See also

\[maidr_off()\] to disable MAIDR rendering

## Examples

``` r
if (FALSE) { # \dontrun{
# In RMarkdown setup chunk:
library(maidr)
maidr_on()

# Now all plots render as accessible MAIDR widgets
library(ggplot2)
ggplot(mtcars, aes(x = factor(cyl))) +
  geom_bar()

barplot(table(mtcars$cyl))
} # }
```
