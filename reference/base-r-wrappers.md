# Base R Graphics Function Wrappers

MAIDR wraps standard Base R graphics functions to intercept plot calls
and enable accessible, interactive visualizations. When the maidr
package is loaded, these wrappers automatically replace the standard
functions on the search path, recording plot data so that \[show()\] can
render accessible versions.

The wrappers are transparent: they call the original graphics functions
and return the same results. When patching is disabled (via
\[maidr_off()\]), they pass through directly to the originals with no
overhead.

## Usage

``` r
barplot(...)

plot(...)

hist(...)

boxplot(...)

image(...)

heatmap(...)

contour(...)

matplot(...)

curve(...)

dotchart(...)

stripchart(...)

stem(...)

pie(...)

mosaicplot(...)

assocplot(...)

pairs(...)

coplot(...)

lines(x, ...)

points(x, ...)

text(...)

mtext(...)

abline(...)

segments(...)

arrows(...)

polygon(...)

rect(...)

symbols(...)

legend(...)

axis(side, at = NULL, labels = TRUE, ...)

title(...)

grid(...)

par(...)

layout(...)

# S3 method for class 'screen'
split(...)
```

## Arguments

- ...:

  Arguments passed to the original graphics function.

## Value

Same as the original Base R function (invisibly when applicable).

## Details

These stub definitions are overwritten during package loading by the
actual wrapper implementations created in
\[initialize_base_r_patching()\]. They exist here solely to generate the
necessary NAMESPACE exports via roxygen2.

## See also

\[show()\] for displaying accessible plots, \[maidr_on()\],
\[maidr_off()\] for controlling patching
