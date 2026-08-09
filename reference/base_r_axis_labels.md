# Base R Axis-Title Defaults

Base R's high-level plotting functions derive their axis titles inside
the call ([`hist()`](https://r.maidr.ai/reference/base-r-wrappers.md)
names the y axis "Frequency", `boxplot.formula()` reads both titles off
the formula) instead of recording them, and
[`barplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) and
[`pie()`](https://r.maidr.ai/reference/base-r-wrappers.md) draw no title
at all. Either way the recorded call carries no `xlab=`/`ylab=`, so a
processor that only reads those arguments announces a nameless axis.

## Details

What a chart can honestly put there is a property of the chart type
rather than of the data, so the shapes shared by several processors are
resolved here once.
