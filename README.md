# maidr <img src="man/figures/logo.svg" align="right" height="139" alt="maidr logo" />

<!-- badges: start -->
[![CRAN status](https://www.r-pkg.org/badges/version/maidr)](https://CRAN.R-project.org/package=maidr)
[![CRAN downloads](https://cranlogs.r-pkg.org/badges/grand-total/maidr)](https://CRAN.R-project.org/package=maidr)
[![R-CMD-check](https://github.com/xability/r-maidr/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/xability/r-maidr/actions/workflows/R-CMD-check.yaml)
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

## Overview

maidr (Multimodal Access and Interactive Data Representation) makes data visualizations accessible to users with visual impairments. It converts ggplot2 and Base R plots into interactive, accessible HTML/SVG formats with keyboard navigation, screen reader support, and sonification. maidr for R is the R binding of [MAIDR](https://maidr.ai/), the JavaScript core developed by the (x)Ability Design Lab at the University of Illinois Urbana-Champaign; the same accessibility layer is available for Python as [py-maidr](https://py.maidr.ai/).

The package provides two main functions:

- `show()` displays an interactive accessible plot in RStudio Viewer or browser
- `save_html()` writes a plot to an HTML file, with the MAIDR.js library in a `lib/` folder beside it

## Installation

maidr requires R 4.0.0 or later. Install the stable release from CRAN:

``` r
install.packages("maidr")
```

Or install the development version from GitHub:

``` r
# Using pak (recommended)
pak::pak("xability/r-maidr")

# Alternative: using pacman (auto-installs if missing)
pacman::p_load_gh("xability/r-maidr")
```

## Usage

### ggplot2

``` r
library(maidr)
library(ggplot2)

p <- ggplot(mpg, aes(x = class)) +
  geom_bar(fill = "steelblue") +
  labs(title = "Vehicle Classes", x = "Class", y = "Count")

# Display interactive accessible plot
show(p)

# Or save to file
save_html(p, "vehicle_classes.html")
```

### Base R

``` r
library(maidr)

# Create plot first
barplot(
  table(mtcars$cyl),
  main = "Cars by Cylinder Count",
  xlab = "Cylinders",
  ylab = "Count"
)

# Then call show() without arguments
show()
```

## How maidr hooks into your session

- **Console.** `library(maidr)` is all it takes. Printing a ggplot2 object,
  by typing `p` or `print(p)`, opens it in the maidr viewer; `show(p)` is the
  explicit form. Base R plotting calls are recorded, and `show()` with no
  argument opens the recorded chart. `save_html()` writes either kind to a
  file.
- **R Markdown and Quarto.** Call `maidr_on()` once in a setup chunk. It
  installs the knitr hooks that turn every plot the document draws into an
  accessible chart; `library(maidr)` alone does not install them.
- **Shiny.** Put `maidr_output()` in the UI and `render_maidr()` in the
  server; see `vignette("shiny-integration", package = "maidr")`.
- **Turning it off.** `maidr_off()` stops interception for the session and
  `maidr_on()` starts it again. `options(maidr.ggplot2 = FALSE)` leaves
  ggplot2 printing alone, `options(maidr.base_r = FALSE)` stops recording
  Base R calls, and `options(maidr.auto_show = FALSE)`, in `.Rprofile` to
  make it permanent, turns everything off. See `?"maidr-options"`.
- **What gets masked.** Attaching maidr puts its own copies of the Base R
  plotting functions, and of `methods::show()`, ahead of the originals; R
  lists them at `library(maidr)`. Each records the call and passes through
  to the original, and `show()` hands anything that is not a plot back to
  `methods::show()`. In a script or a package call `maidr::show()` by name,
  and attach vioplot, wordcloud or quantmod *before* maidr, or their own
  functions mask the wrappers and their charts go unrecorded. See
  [`?"base-r-wrappers"`](https://r.maidr.ai/reference/base-r-wrappers.html).

## Supported plot types

maidr supports a wide range of visualization types in both ggplot2 and Base R:

### Basic Plot Types
| Plot Type | ggplot2 | Base R |
|-----------|---------|--------|
| Bar charts | `geom_bar()`, `geom_col()` | `barplot()` |
| Grouped/Dodged bars | `position = "dodge"` | `beside = TRUE` |
| Stacked bars | `position = "stack"` | `beside = FALSE` |
| Pie charts | `geom_col()`/`geom_bar()` + `coord_polar("y")` | `pie()` |
| Histograms | `geom_histogram()` | `hist()` |
| Scatter plots | `geom_point()` | `plot()` |
| Line plots | `geom_line()` | `plot(type = "l")`, `lines()` |
| Step plots | `geom_step()` | `plot(type = "s")`, `plot(type = "S")` |
| Box plots | `geom_boxplot()` | `boxplot()` |
| Heatmaps | `geom_tile()` | `image()` |
| Contour plots | — (`geom_contour()` is [experimental], see below) | `contour()` |
| Violin plots | `geom_violin()` | — (`vioplot::vioplot()` is [experimental], see below) |
| Candlestick (OHLC) | `tidyquant::geom_candlestick()` (+ `geom_ma()`, + patchwork volume) | `quantmod::chartSeries()` (OHLC-only; no TA / no volume) |
| Density/Smooth | `geom_smooth()`, `geom_density()` | `lines(density())` |

Note: Volume bars and moving-average overlays for candlestick charts are
supported only on the ggplot2 + {tidyquant} + {patchwork} path. On the
Base R path, `quantmod::chartSeries()` `TA` overlays (`addVo()`,
`addSMA()`, `addEMA()`) — and the default `TA` whenever the input `xts`
carries a `Volume` column — fall back to native (non-accessible)
graphics with a one-time advisory.

### Advanced Plot Types
| Plot Type | ggplot2 | Base R |
|-----------|---------|--------|
| Faceted plots | `facet_wrap()`, `facet_grid()` | `par(mfrow/mfcol)` + loops |
| Multi-panel layouts | `patchwork` package | `par(mfrow)`, `par(mfcol)` |
| Multi-layered plots | Multiple `geom_*` layers | Sequential plot calls |

### Experimental Plot Types

> [!WARNING]
> **These are prototypes. Treat them as prototypes.** They are under active
> development, they are unstable, and **none of them has been through a user
> study**. Field names, announcement wording and navigation may change without
> a deprecation period, including in a patch release. If you are building
> something that has to keep working, build it on the plot types above.

Everything in the two tables above predates the plot coverage roadmap
([#137](https://github.com/xability/r-maidr/issues/137)) and has been exercised
by real readers over real charts. Everything below was added by that roadmap
and the base R sweeps that followed it
([#251](https://github.com/xability/r-maidr/issues/251),
[#262](https://github.com/xability/r-maidr/issues/262)), most inside a few
weeks.

Each was measured against the chart it reads — that is what the issues and the
tests record. But measuring that a reading is *faithful to the drawing* is a
different claim from establishing that it is *useful to a reader*. Nobody has
asked a blind or low-vision reader whether hearing `stars()` as a radar, or
navigating a `termplot()` panel by panel, is the right way to read one. Until
that happens these are proposals about how a chart could be read, not answers.

Feedback is exactly what would move one of these into the tables above.

Elsewhere in these docs — the example articles, the getting-started vignette
and the package help — an experimental type is marked **[experimental]** after
its name; a type with no mark is stable.

#### ggplot2

| Layer type | Drawn by |
|-----------|----------|
| `area` | `geom_area()`, `geom_ribbon(aes(ymin = 0, ...))` |
| `stacked_area` | stacked `geom_area()` |
| `stacked_normalized_area` | `geom_area(position = "fill")` |
| `stacked_normalized_bar` | `geom_bar(position = "fill")` |
| `contour` | `geom_contour()`, `geom_density_2d()` |
| `error_bar` | `geom_errorbar()`, `geom_errorbarh()`, `geom_linerange()`, `geom_pointrange()`, `geom_crossbar()`, `geom_ribbon()` as a band |
| `gantt` | `geom_segment()`, `geom_curve()`, `maidr_gantt()` |
| `hexbin` | `geom_hex()`, `stat_bin_2d()` |
| `polygon` | `geom_polygon()` |
| `roc` | `maidr_roc()`, `pROC::ggroc()`, `autoplot()` of a `yardstick::roc_curve()` |
| `rug` | `geom_rug()` |

#### Base R

| Layer type | Drawn by |
|-----------|----------|
| `biplot` | `biplot()` |
| `box_stats` | `bxp()` |
| `conditional_density` | `cdplot()` |
| `correlogram` | `acf()`, `pacf()`, `ccf()` |
| `cumulative_periodogram` | `cpgram()` |
| `dot` | `dotchart()` (ungrouped) |
| `filled_contour` | `filled.contour()` |
| `fourfold` | `fourfoldplot()` (2x2 tables, `std = "ind.max"` / `"all.max"`) |
| `interaction` | `interaction.plot()` |
| `lag` | `lag.plot()` |
| `lollipop` | `plot(type = "h")` |
| `mosaic` | `mosaicplot()` (two-way tables) |
| `pairs` | `pairs()` |
| `qq` | `qqnorm()` |
| `qqline` | `qqline()` |
| `radar` | `stars()` |
| `residual` | `assocplot()` (two-way tables) |
| `spectral_density` | `spectrum()` |
| `spine` | `spineplot()` |
| `stacked_normalized_bar` | `barplot()` of proportions |
| `strip` | `stripchart()` |
| `subseries` | `monthplot()` |
| `termplot` | `termplot()` |
| `violin` | `vioplot::vioplot()` |
| `word_cloud` | `wordcloud::wordcloud()` |

The split is the diff of each factory's `get_supported_types()` against
`8de0e98`, the last commit on `main` before
[#137](https://github.com/xability/r-maidr/issues/137) was filed.
`tests/testthat/test-plot-type-stability.R` fails if a supported type appears
in neither the stable tables nor the experimental ones, so a new layer type has
to be placed deliberately rather than inherit either promise by being
forgotten.

The [JavaScript core](https://maidr.ai/) and the [Python binding](https://py.maidr.ai/)
make the same distinction over their own type lists, with the same boundary and
for the same reason, and mark their docs the same way: see the JavaScript
core's [trace type stability](https://maidr.ai/docs/SCHEMA.html#trace-type-stability)
and the Python binding's [stability page](https://py.maidr.ai/stability.html).

See the [examples gallery](https://r.maidr.ai/articles/examples.html) for a
worked example of each plot type.

## Accessibility features

- **Keyboard navigation** - explore data points using arrow keys
- **Screen reader support** - full ARIA labels and live announcements
- **Sonification** - hear data patterns through sound
- **Text descriptions** - automatic statistical summaries

The keys a reader needs first, the same on every page of this documentation:

<!-- maidr-keys:start -->
| Key | Action |
|---|---|
| **Tab** | Focus the chart; **Shift + Tab** leaves it |
| **Left / Right** | Move between data points |
| **Up / Down** | Move between series, stacked segments, heat map rows or box plot sections, on a chart that has them |
| **Page Up / Page Down** | Switch between the layers of a chart that has several |
| **B** | Toggle braille mode |
| **T** | Toggle text mode |
| **S** | Toggle sonification |
| **R** | Toggle review mode |
| **C** | Toggle high contrast mode |
| **L**, then **X**, **Y** or **T** | Announce the x axis label, the y axis label or the title |
| **Space** | Repeat the current sound |
| **Ctrl + /** (**Cmd + /** on macOS) | Show or hide the full keyboard shortcut help |

Every other shortcut, including autoplay, jumping to the ends, the command palette, settings and the AI chat, is on the [MAIDR controls reference](https://maidr.ai/docs/CONTROLS.html).
<!-- maidr-keys:end -->

## Offline support

By default, `show()` and `save_html()` use the bundled maidr.js library, so
the result works offline. `save_html()` writes the library to a `lib/` folder
beside the file, and the two have to be shared together: zip the folder that
holds both, or copy both. An `.html` sent on its own loads no maidr.js and
shows a plain, inaccessible chart. Widgets, knitr documents and Shiny apps
auto-detect internet availability and use the CDN when online. A knitted R
Markdown or Quarto document rendered online, and any page holding a widget,
also carries its own copy of maidr.js, which its charts fall back on when the
CDN cannot be reached, so a `self_contained` / `embed-resources` document
works offline too. Use the
`use_cdn` parameter for explicit control:

``` r
# Force CDN: one self-contained file, needs internet whenever it is viewed
show(p, use_cdn = TRUE)
save_html(p, "plot.html", use_cdn = TRUE)

# Force bundled files: works offline, lib/ folder beside the saved file
show(p, use_cdn = FALSE)
save_html(p, "plot.html", use_cdn = FALSE)
```

The CDN paths load the **latest published maidr.js**, not the copy bundled
with this package, as the Python binding does. The first CDN document in an R
session asks jsDelivr (then the npm registry) which version that is, within 3
seconds, and every document in the session names that version. If the lookup
cannot be made it costs no error: the document names the bundled version
instead, the copy `use_cdn = FALSE` would serve. Pin a version when a document
has to load the same maidr.js whenever it is opened:

``` r
options(maidr.cdn_version = "bundled")  # the bundled version, no lookup
options(maidr.cdn_version = "4.9.0")    # a particular release
```

or set `MAIDR_CDN_VERSION` in the environment. `use_cdn = FALSE` never makes
a network request. See `?"maidr-options"`.

One path still reaches the network from an offline document: connecting a
[DotPad tactile display](https://maidr.ai/docs/TACTILE_DISPLAY.html). maidr.js
does not bundle the DotPad SDK, whose braille engine is a 14 MB liblouis build,
and imports the vendor's copy from jsDelivr the first time a DotPad is
connected. Rendering, sonification and braille work offline regardless. To keep
the DotPad offline too, download the pinned SDK once and every `use_cdn = FALSE`
document carries it in its `lib/` folder:

``` r
maidr_download_dotpad_sdk()          # ~14 MB, once, into a per-user cache
save_html(p, "plot.html", use_cdn = FALSE)   # lib/dotpad-sdk-<version>/ beside it
```

A page served from elsewhere, or a knitr document (whose charts live in
`srcdoc` frames with no base URL), names its copy by URL instead, through
options or the environment variables of the same names:

``` r
options(
  maidr.dotpad_sdk_url = "https://intranet.example/dotpad/DotPadSDK-3.0.3.js",
  maidr.dotpad_asset_base_url = "https://intranet.example/dotpad/lib/"
)
# or: Sys.setenv(MAIDR_DOTPAD_SDK_URL = "...", MAIDR_DOTPAD_ASSET_BASE_URL = "...")
```

Every document maidr produces then declares `window.MAIDR_DOTPAD_SDK_URL` and
`window.MAIDR_DOTPAD_ASSET_BASE_URL` ahead of maidr.js. See `?"maidr-options"`.

## Getting help

- Report bugs or request features at [GitHub Issues](https://github.com/xability/r-maidr/issues)
- Browse the [function reference](https://r.maidr.ai/reference/index.html), or run `help(package = "maidr")` offline

## Learning more
- `vignette("getting-started", package = "maidr")` for an introduction
- The [examples gallery](https://r.maidr.ai/articles/examples.html) for supported visualizations
- `vignette("shiny-integration", package = "maidr")` for Shiny apps
- The [maidr skill](https://github.com/xability/maidr-skill) for AI coding agents (Claude Code, Codex, Cursor, and others): once installed with `npx skills add xability/maidr-skill`, an agent that writes ggplot2 or base R plotting code routes the result through this package so the chart comes out accessible

## Related projects

maidr for R is one of three MAIDR packages, all developed by the (x)Ability
Design Lab at the University of Illinois Urbana-Champaign:

- [MAIDR JavaScript core](https://maidr.ai/), the TypeScript engine (npm package
  `maidr`) that renders every accessible chart, including the ones this package
  produces.
- [py-maidr for Python](https://py.maidr.ai/), the Python binding for
  matplotlib, seaborn, Plotly and Altair (PyPI package `maidr`).
- [maidr for R](https://r.maidr.ai/), this package, for ggplot2 and Base R
  graphics (CRAN package `maidr`; source at
  [xability/r-maidr](https://github.com/xability/r-maidr)).

## Citation

If you use maidr in research, please cite the MAIDR papers:

- Seo, J., Xia, Y., Lee, B., Mccurry, S., & Yam, Y. J. (2024). MAIDR: Making
  Statistical Visualizations Accessible with Multimodal Data Representation. In
  Proceedings of the CHI Conference on Human Factors in Computing Systems
  (CHI '24). ACM. <https://doi.org/10.1145/3613904.3642730>
- Seo, J., O'Modhrain, S., Xia, Y., Kamath, S., Lee, B., & Coughlan, J. M.
  (2024). Designing Born-Accessible Courses in Data Science and Visualization:
  Challenges and Opportunities of a Remote Curriculum Taught by Blind
  Instructors to Blind Students. In EuroVis 2024 - Education Papers. The
  Eurographics Association. <https://doi.org/10.2312/eved.20241053>

`citation("maidr")` prints both, plus an entry for the package itself, in
text and BibTeX form.
