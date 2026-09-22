# Layer types whose frontend model reads `selectors` as ONE selector for every mark

In maidr.js 4.x the shape of `selectors` is a contract, not a
convenience. A plain string is handed to `document.querySelectorAll()`
and the matches are aligned to the layer's points in document order. An
ARRAY means something else for these types: one selector per data point
for `bar` and `hist` (`src/model/bar.ts`), a per-series grid for the
segmented bars and `mosaic` (`src/model/segmented.ts`), and nothing at
all for `point` and `pie`, whose models read `layer.selectors as string`
(`src/model/scatter.ts`, `src/model/pie.ts`). `dot` and `lollipop` are
built by the `bar` model; `heat` reads a string or a per-cell grid
(`src/model/heatmap.ts`). maidr.js 3.x read a one-element array as the
string it held, which is why every processor here that returns
`list(selector)` was fine until the bundle moved to 4.0 (#316).

## Usage

``` r
SINGLE_SELECTOR_LAYER_TYPES
```

## Details

Types NOT listed keep whatever shape their processor built, because
their models want the array: one selector per series for `line`,
`smooth`, `step`, `area`, `roc` and `violin_kde`, one per level for
`contour`, one per box for `box` and `violin_box`, one per tick for a
rug, and `error_bar`, `gantt`, `word_cloud` and `candlestick` accept
either.
