# Enable MAIDR Plot Interception

Turns on the accessible rendering of ggplot2, lattice and Base R plots,
and installs the knitr hooks that an R Markdown or Quarto document
needs.

## Usage

``` r
maidr_on()
```

## Value

Invisible TRUE on success

## Details

Interception is on by default after
[`library(maidr)`](https://github.com/xability/r-maidr): printing a
ggplot2 or lattice object opens it in the MAIDR viewer, and Base R
plotting calls are recorded until
[`show()`](https://r.maidr.ai/reference/show.md) is called. lattice is
reached through its own hook, `lattice.options(print.function = )`,
which maidr sets once lattice's namespace is loaded; a print function
set before is kept, and draws the prints maidr leaves to lattice.
Calling `maidr_on()` yourself is needed in two places: after
[`maidr_off()`](https://r.maidr.ai/reference/maidr_off.md), to start
again, and once in the setup chunk of an R Markdown or Quarto document,
where it registers the `knit_print` methods and the plot hook that turn
every plot the document draws into an accessible chart.
[`library(maidr)`](https://github.com/xability/r-maidr) alone installs
neither.

## See also

[`maidr_off()`](https://r.maidr.ai/reference/maidr_off.md) to disable
MAIDR rendering

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
