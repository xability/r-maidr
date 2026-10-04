# Install maidr's knitr hooks

Each hook is installed over the one in place, unless that one is
maidr's. The plot hook is looked up when a figure is written, after its
chunk has run, and the chunk hook after that, so hooks installed while a
chunk runs already cover that chunk. knitr looks the `evaluate` hook up
before it runs a chunk, so it covers the chunks after the one that
installs it.

## Usage

``` r
install_knitr_integration()
```

## Value

NULL (invisible)

## Details

What was recorded on the chunk's device before the first install of a
knit – Base R calls, charts queued for a figure – belongs to no chart of
it, and is dropped. A knit whose hooks are already maidr's is a child
document, which put its parent's `opts_knit` back when it ended: the
current device's records are then this chunk's, and are kept. Calls on
any other open device, such as the session's own, are left for the
session: a figure is shown as a chart only for the tokens its page
carries, which only a knit gives (`resolve_figure_chart()`).
