# Functions maidr masks on attach

[`library(maidr)`](https://github.com/xability/r-maidr) puts maidr's own
copies of the Base R plotting functions ahead of the originals on the
search path, and R says so with its "The following objects are masked"
notice. Each copy is a wrapper: it records the call so that
[`show()`](https://r.maidr.ai/reference/show.md) and
[`save_html()`](https://r.maidr.ai/reference/save_html.md) can render an
accessible chart, then calls the original and returns what the original
returns. With interception off
([`maidr_off()`](https://r.maidr.ai/reference/maidr_off.md), or
`options(maidr.base_r = FALSE)`) the wrappers pass straight through.

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

persp(...)

sunflowerplot(...)

fourfoldplot(...)

spineplot(...)

cdplot(...)

qqnorm(...)

qqplot(...)

qqline(...)

filled.contour(...)

acf(...)

pacf(...)

ccf(...)

cpgram(...)

spectrum(...)

monthplot(...)

termplot(...)

lag.plot(...)

biplot(...)

interaction.plot(...)

bxp(...)

stars(...)

vioplot(...)

wordcloud(...)

chartSeries(...)

lines(...)

points(...)

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

- side, at, labels:

  `axis()`'s own arguments, which its wrapper names so that the tick
  labels a chart is given can be recorded; passed on to
  [`graphics::axis()`](https://rdrr.io/r/graphics/axis.html) unchanged.

## Value

Same as the original Base R function (invisibly when applicable).

## Details

### What is masked

From graphics: the high-level plotting functions `barplot()`, `plot()`,
`hist()`, `boxplot()`, `image()`, `contour()`, `matplot()`, `curve()`,
`dotchart()`, `stripchart()`, `stem()`, `pie()`, `mosaicplot()`,
`assocplot()`, `pairs()`, `coplot()`, `persp()`, `sunflowerplot()`,
`fourfoldplot()`, `spineplot()`, `cdplot()`, `filled.contour()`, `bxp()`
and `stars()`; the low-level additions `lines()`, `points()`, `text()`,
`mtext()`, `abline()`, `segments()`, `arrows()`, `polygon()`, `rect()`,
`symbols()`, `legend()`, `axis()`, `title()` and `grid()`; and the
layout functions `par()`, `layout()` and `split.screen()`.

From stats: `heatmap()`, `qqnorm()`, `qqplot()`, `qqline()`, `acf()`,
`pacf()`, `ccf()`, `cpgram()`, `spectrum()`, `monthplot()`,
`termplot()`, `lag.plot()`, `biplot()` and `interaction.plot()`.

`plot()` is also masked from base, where its generic has lived since R
4.0, and [`show()`](https://r.maidr.ai/reference/show.md) from methods:
the S4 display generic, which maidr's
[`show()`](https://r.maidr.ai/reference/show.md) hands back any object
that is not a plot.

[`vioplot::vioplot()`](https://rdrr.io/pkg/vioplot/man/vioplot.html),
[`wordcloud::wordcloud()`](https://rdrr.io/pkg/wordcloud/man/wordcloud.html)
and
[`quantmod::chartSeries()`](https://rdrr.io/pkg/quantmod/man/chartSeries.html)
are wrapped as well, once their package is loaded.

### [`show()`](https://r.maidr.ai/reference/show.md) and [`methods::show()`](https://rdrr.io/r/methods/show.html)

maidr's [`show()`](https://r.maidr.ai/reference/show.md) takes a ggplot2
object or, with no argument, the last recorded Base R chart. Anything
else it is given goes to
[`methods::show()`](https://rdrr.io/r/methods/show.html), so `show(x)`
on an S4 object prints as it did before maidr was attached. In a script
or a package, where what is masked depends on what else is attached,
call [`maidr::show()`](https://r.maidr.ai/reference/show.md) and
[`methods::show()`](https://rdrr.io/r/methods/show.html) by name.

### Attach order for vioplot, wordcloud and quantmod

These three are wrapped into maidr's namespace when their package loads,
so a bare call reaches the wrapper only while `package:maidr` sits ahead
of the package on the search path. Attach them *before* maidr:

    library(vioplot)
    library(maidr)

Attached after it, the package masks the wrapper, a bare `vioplot()`,
`wordcloud()` or `chartSeries()` draws without being recorded, and
[`show()`](https://r.maidr.ai/reference/show.md) reports that no Base R
plot was detected. maidr says so at the moment the package is attached
and again in that error. The other way round it is `maidr::vioplot()`,
`maidr::wordcloud()` or `maidr::chartSeries()`, called explicitly.

### Calling an original directly

The wrappers add nothing to the drawing and return what the original
returns, so there is rarely a reason to go around them.
[`graphics::barplot()`](https://rdrr.io/r/graphics/barplot.html) does,
and draws a chart maidr does not record.

## See also

[`show()`](https://r.maidr.ai/reference/show.md) and
[`save_html()`](https://r.maidr.ai/reference/save_html.md);
[`maidr_on()`](https://r.maidr.ai/reference/maidr_on.md) and
[`maidr_off()`](https://r.maidr.ai/reference/maidr_off.md) for turning
interception on and off;
[`?"maidr-options"`](https://r.maidr.ai/reference/maidr-options.md).
