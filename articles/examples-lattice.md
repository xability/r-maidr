# lattice Chart Examples

lattice draws Trellis graphics: a high-level function such as
[`barchart()`](https://rdrr.io/pkg/lattice/man/xyplot.html) or
[`xyplot()`](https://rdrr.io/pkg/lattice/man/xyplot.html) turns a
formula into one or more panels, and a panel function draws each of
them. maidr reads a chart that one of the high-level functions on this
page made by looking at what its panel function drew and mapping that
onto a layer type it already knows: a
[`barchart()`](https://rdrr.io/pkg/lattice/man/xyplot.html) becomes a
bar layer, a [`bwplot()`](https://rdrr.io/pkg/lattice/man/xyplot.html) a
box layer, an [`xyplot()`](https://rdrr.io/pkg/lattice/man/xyplot.html)
points, a line or steps according to its `type`. Arrow-key navigation
and sonification carry over from those types. Every reading on this page
is an experimental plot type (see “Experimental Plot Types” in the
README), even where the layer type is a stable one for ggplot2 and Base
R: none has been through a user study, and each may change without a
deprecation period. The [examples
hub](https://r.maidr.ai/articles/examples.md) lists every other plot
family.

> **Note:** Each chunk below ends with the chart itself, which is how
> knitr hands a lattice chart to maidr. A chart that a chunk draws with
> `print(p)`, lattice’s idiom inside a loop or a function, stays a
> static image; draw it in a chunk of its own, or after the chunk’s Base
> R charts, since a Base R chart later in the same chunk takes its
> place. At the console, printing a lattice chart opens it in the maidr
> viewer; see “How maidr hooks into your session” in the
> [getting-started
> vignette](https://r.maidr.ai/articles/getting-started.md).

## Bar Chart \[experimental\]

[`barchart()`](https://rdrr.io/pkg/lattice/man/xyplot.html) without
`groups` draws one bar per category. maidr reads it as a **bar** layer,
the reading
[`barplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) gets,
with each bar’s value taken from the data lattice drew it from.

> **Note:** lattice starts a bar at the bottom of the axis unless it is
> given an `origin`. `origin = 0` draws each bar from zero, so its
> length is the value a reader hears.

``` r

sales <- data.frame(
  product = factor(c("A", "B", "C", "D", "E")),
  units = c(30, 45, 25, 60, 35)
)
barchart(units ~ product,
  data = sales, origin = 0,
  xlab = "Product", ylab = "Units sold", main = "Units sold by product"
)
```

## Dodged Bar Chart \[experimental\]

With `groups`,
[`barchart()`](https://rdrr.io/pkg/lattice/man/xyplot.html) draws the
groups’ bars side by side within each category. maidr reads a **dodged
bar** layer: one series per group, navigated category by category, with
Up and Down moving between the groups.

``` r

titanic <- aggregate(Freq ~ Class + Survived,
  data = as.data.frame(Titanic), FUN = sum
)
barchart(Freq ~ Class,
  data = titanic, groups = Survived, origin = 0,
  auto.key = list(title = "Survived", columns = 2),
  ylab = "Passengers", main = "Titanic passengers by class"
)
```

## Stacked Bar Chart \[experimental\]

`stack = TRUE` piles the same bars on top of one another, and maidr
reads a **stacked bar** layer, in which each segment is announced with
its own count.
[`barchart()`](https://rdrr.io/pkg/lattice/man/xyplot.html) of a table
or a matrix stacks its bars by default.

``` r

barchart(Freq ~ Class,
  data = titanic, groups = Survived, stack = TRUE,
  auto.key = list(title = "Survived", columns = 2),
  ylab = "Passengers", main = "Titanic passengers by class"
)
```

## Histogram \[experimental\]

[`histogram()`](https://rdrr.io/pkg/lattice/man/histogram.html) bins a
variable and draws a bar per bin. maidr reads a **hist** layer, one bin
per bar, with the bin’s edges and its height as lattice drew them.

> **Note:** lattice’s y axis is each bin’s percent of the total unless
> it is asked for counts with `type = "count"`, as here. The reading
> follows whichever one is drawn, but the chart description (**D**)
> takes every bin height for a count: it calls the heights “counts” and
> adds them up as the total number of observations, so a percent
> histogram is described as holding 100 observations whatever its size.
> Ask for `type = "count"` when that total matters.

``` r

histogram(~waiting,
  data = faithful, type = "count",
  xlab = "Minutes between eruptions", main = "Old Faithful waiting times"
)
```

## Scatter Plot \[experimental\]

[`xyplot()`](https://rdrr.io/pkg/lattice/man/xyplot.html) draws points
by default, and maidr reads them as a **point** layer. With `groups` it
reads one point layer per group, named after it, so a reader moves
between the groups with Page Up and Page Down.

``` r

xyplot(mpg ~ wt,
  data = mtcars, groups = factor(cyl),
  auto.key = list(title = "Cylinders", columns = 3),
  xlab = "Weight (1000 lbs)", ylab = "Miles per gallon",
  main = "Fuel economy by weight"
)
```

## Line Plot \[experimental\]

`type = "l"` joins the points in the order of the data. maidr reads a
**line** layer, with one series per group, and Up and Down move between
the groups at each x they share. Groups whose lines never meet at an x
are read as a layer each instead, which Page Up and Page Down move
between.

``` r

xyplot(circumference ~ age,
  data = Orange, groups = Tree, type = "l",
  auto.key = list(title = "Tree", lines = TRUE, points = FALSE, columns = 5),
  xlab = "Age (days)", ylab = "Trunk circumference (mm)",
  main = "Growth of five orange trees"
)
```

A time series needs no formula:
[`xyplot()`](https://rdrr.io/pkg/lattice/man/xyplot.html) draws it
against its own time, and maidr reads it as a **line** named after the
series – one panel per series for several, or one layer of several
series with `superpose = TRUE`.

``` r

xyplot(ldeaths,
  xlab = "Year", main = "Monthly deaths from lung disease in the UK"
)
```

## Step Plot \[experimental\]

`type = "s"` draws a staircase that runs across to the next x and then
up or down to its value; `type = "S"` goes up or down first. maidr reads
a **step** layer, one point per value, and says which way the steps
turn.

``` r

tickets <- data.frame(day = 1:10, open = c(2, 3, 3, 5, 4, 4, 6, 7, 7, 5))
xyplot(open ~ day,
  data = tickets, type = "s",
  xlab = "Day", ylab = "Open tickets", main = "Open support tickets"
)
```

## Lollipop \[experimental\]

`type = "h"` draws a vertical spike up to each value. maidr reads it as
a **lollipop**, one spike per value, the reading Base R’s
`plot(type = "h")` gets.

``` r

spikes <- data.frame(index = 1:8, value = c(2, 5, 3, 9, 4, 7, 6, 8))
xyplot(value ~ index,
  data = spikes, type = "h", lwd = 2,
  xlab = "Index", ylab = "Value", main = "Spikes"
)
```

## Box Plot \[experimental\]

[`bwplot()`](https://rdrr.io/pkg/lattice/man/xyplot.html) draws a box
and whiskers per level. maidr reads a **box** layer, with each box’s
whiskers, quartiles, median and outliers computed as
[`panel.bwplot()`](https://rdrr.io/pkg/lattice/man/panel.bwplot.html)
computes them, with
[`boxplot.stats()`](https://rdrr.io/r/grDevices/boxplot.stats.html), so
a reader hears the numbers the drawing was made from.

``` r

bwplot(voice.part ~ height,
  data = singer,
  xlab = "Height (inches)", main = "Heights of singers by voice part"
)
```

## Heat Map \[experimental\]

[`levelplot()`](https://rdrr.io/pkg/lattice/man/levelplot.html) colours
a cell for each pair of row and column. maidr reads a **heat** layer: a
grid navigated row by row and cell by cell, with each cell’s value on
the z axis.

``` r

levelplot(cor(mtcars[, c("mpg", "disp", "hp", "wt", "qsec")]),
  xlab = "Variable", ylab = "Variable",
  main = "Correlations between five mtcars variables"
)
```

## Contour Plot \[experimental\]

[`contourplot()`](https://rdrr.io/pkg/lattice/man/levelplot.html) draws
the level curves of a surface. maidr reads a **contour** layer, one
curve for each line lattice draws, with every point on it carrying its
level, so a reader walks the curves rather than the grid; a level that
crosses the surface more than once is drawn, and read, as several
curves. `levelplot(contour = TRUE)` draws the same curves over a heat
map, and is read as a heat layer and a contour layer.

``` r

# Every fourth row and column of the 87 x 61 grid: the curves read much the
# same, and the page carries a fraction of the points.
volcano_coarse <- volcano[
  seq(1, nrow(volcano), by = 4), seq(1, ncol(volcano), by = 4)
]
contourplot(volcano_coarse,
  cuts = 6,
  xlab = "Row", ylab = "Column", main = "Maunga Whau volcano"
)
```

## Density and Smooth Curves \[experimental\]

[`densityplot()`](https://rdrr.io/pkg/lattice/man/histogram.html) draws
a kernel density estimate, and maidr reads the curve as a **smooth**
layer. Each group’s curve spans its own range of values, so grouped
curves are read as a layer each, named after the group. The points
lattice scatters beneath the curve are drawn but not navigated.

``` r

densityplot(~waiting,
  data = faithful,
  xlab = "Minutes between eruptions", main = "Old Faithful waiting times"
)
```

[`xyplot()`](https://rdrr.io/pkg/lattice/man/xyplot.html) with
`type = "r"`, `"smooth"` or `"spline"` adds a fitted curve to the
points, and maidr reads that curve as a **smooth** layer beside the
point layer.

``` r

xyplot(mpg ~ wt,
  data = mtcars, type = c("p", "r"),
  xlab = "Weight (1000 lbs)", ylab = "Miles per gallon",
  main = "Fuel economy with a least-squares line"
)
```

## Dot Plot \[experimental\]

[`dotplot()`](https://rdrr.io/pkg/lattice/man/xyplot.html) of one value
per category is Cleveland’s dot plot, and maidr reads it as a **dot**
layer, as it reads Base R’s
[`dotchart()`](https://r.maidr.ai/reference/base-r-wrappers.md). Given
several values on a level, the same function draws a strip of points
instead, and maidr reads those as points.

``` r

deaths <- data.frame(
  age = factor(rownames(VADeaths), levels = rownames(VADeaths)),
  rate = VADeaths[, "Rural Male"]
)
dotplot(age ~ rate,
  data = deaths,
  xlab = "Deaths per 1000", main = "Virginia death rates, rural males"
)
```

## Strip Plot \[experimental\]

[`stripplot()`](https://rdrr.io/pkg/lattice/man/xyplot.html) draws every
observation of each level along one axis. maidr reads a **point** layer,
and each point carries the name of its level.

``` r

stripplot(spray ~ count,
  data = InsectSprays, jitter.data = TRUE,
  xlab = "Insect count", main = "Insect counts by spray"
)
```

## Q-Q Plot \[experimental\]

[`qqmath()`](https://rdrr.io/pkg/lattice/man/qqmath.html) plots a
sample’s quantiles against those of a theoretical distribution, the
normal unless told otherwise. maidr reads the points as a **point**
layer on those two axes.
[`qq()`](https://rdrr.io/pkg/lattice/man/qq.html), which sets two
samples against each other, is read the same way.

``` r

qqmath(~mpg,
  data = mtcars,
  ylab = "Miles per gallon", main = "Normal Q-Q plot of fuel economy"
)
```

## Conditioned Plots \[experimental\]

A formula with `|` draws one panel per level of the conditioning
variable. maidr reads each panel as a subplot of its own, laid out as
lattice lays them out and named after its strip. A figure with several
panels opens at the lobby, where the arrow keys choose a panel,
**Enter** goes into it and **Escape** comes back out; see the [MAIDR
controls reference](https://maidr.ai/docs/CONTROLS.html).

> **Note:** A chart laid out over several pages, with more panels than
> its `layout` holds, is read from its first page only, with a warning.
> Set `layout` so that every panel fits on one page.

``` r

xyplot(mpg ~ wt | paste(cyl, "cylinders"),
  data = mtcars, layout = c(3, 1),
  xlab = "Weight (1000 lbs)", ylab = "Miles per gallon",
  main = "Fuel economy by weight and cylinders"
)
```

## Charts That Stay Images

maidr reads a chart only while it can account for everything the panel
function drew. Anything else is shown as a static image, the way lattice
draws it, rather than read wrongly:
[`cloud()`](https://rdrr.io/pkg/lattice/man/cloud.html),
[`wireframe()`](https://rdrr.io/pkg/lattice/man/cloud.html),
[`splom()`](https://rdrr.io/pkg/lattice/man/splom.html) and
[`parallelplot()`](https://rdrr.io/pkg/lattice/man/splom.html); a panel
function of your own, or one such as `panel.violin`, in place of the
stock one; `levelplot(useRaster = TRUE)`; latticeExtra layers and
compositions; a fit (`type = "r"`, `"smooth"` or `"spline"`) over a
factor axis, as on a
[`stripplot()`](https://rdrr.io/pkg/lattice/man/xyplot.html) or
[`dotplot()`](https://rdrr.io/pkg/lattice/man/xyplot.html); and a panel
that fails to draw. Printed at the console, such a chart is drawn by
lattice as it always was.
