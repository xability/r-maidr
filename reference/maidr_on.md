# Enable MAIDR Plot Interception

Enables automatic accessible rendering of ggplot2 and Base R plots. In
interactive sessions, plots are displayed in the MAIDR interactive
viewer. In RMarkdown documents, plots are converted to accessible MAIDR
widgets with keyboard navigation and screen reader support.

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
# \donttest{
library(maidr)

# Enable interception (on by default after library(maidr))
maidr_on()

# Now all plots render as accessible MAIDR widgets
library(ggplot2)
ggplot(mtcars, aes(x = factor(cyl))) +
  geom_bar()

barplot(table(mtcars$cyl))

# }
```
