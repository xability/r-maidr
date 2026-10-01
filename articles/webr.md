# Using MAIDR in webR

## Overview

[webR](https://docs.r-wasm.org/webr/latest/) runs R in the browser, with
no R server behind the page. maidr runs there too:
[`show()`](https://r.maidr.ai/reference/show.md) adds the chart to the
page the session runs in, and a reader uses it there, with the keyboard,
sound, text and braille, as anywhere else.

webR’s own binary repository carries an old maidr, from before it could
do this. A release that can do it reaches that repository only after a
CRAN release, which webR’s builds then pick up. Until then, install the
development version, which [r-universe](https://xability.r-universe.dev)
builds for webR, or build maidr for webR yourself.

## Install maidr in webR

r-universe builds maidr for webR from its development branch. List it
before webR’s own repository, so that its newer maidr is the one found:

``` js
await webR.installPackages(["maidr"], {
  repos: ["https://xability.r-universe.dev/", "https://repo.r-wasm.org/"],
});
```

or, from R in a webR session:

``` r

webr::install(
  "maidr",
  repos = c("https://xability.r-universe.dev/", "https://repo.r-wasm.org/")
)
```

maidr contains compiled code (through ‘Rcpp’), so a build is for one
version of webR. r-universe builds for the webR release it currently
runs, which is R 4.6.0, webR 0.6.0 at the time of writing; [its page for
maidr](https://xability.r-universe.dev/maidr) shows what has been built.
When your page loads another webR, or you want a build that is not the
latest, build it yourself.

## Build maidr for webR yourself

[rwasm](https://r-wasm.github.io/rwasm/) builds R packages for webR. Its
[container](https://docs.r-wasm.org/webr/latest/building.html) carries
the toolchain:

``` sh
docker run --rm -v "$PWD":/src -w /src ghcr.io/r-wasm/webr:v0.6.0 \
  Rscript -e 'pak::local_install_deps(".", dependencies = c("Depends", "Imports", "LinkingTo"))' \
          -e 'rwasm::add_pkg(".", repo_dir = "webr-repo", remotes = NULL)'
```

`remotes = NULL` skips rwasm’s look-up of the packages webR patches,
which maidr is not one of. `webr-repo/` is a package repository. Serve
it from any static host and use its address in place of r-universe’s
above. The other packages maidr needs come from webR’s own repository,
so list both when you install. Build with the container of the webR
release your page loads.

## Show a chart on a page

``` html
<button id="before">Before the chart</button>
<div id="maidr-output"></div>
<script type="module">
  import { WebR } from "https://webr.r-wasm.org/v0.6.0/webr.mjs";

  const webR = new WebR();
  await webR.init();
  await webR.installPackages(["maidr"], {
    repos: ["https://xability.r-universe.dev/", "https://repo.r-wasm.org/"],
  });
  await webR.evalRVoid(`
    library(maidr)
    library(ggplot2)
    show(ggplot(mtcars, aes(factor(cyl), mpg)) + geom_col())
  `);
</script>
```

[`show()`](https://r.maidr.ai/reference/show.md) adds an iframe holding
the chart to the element with id `maidr-output`, or to the end of
`<body>` when the page has none. The frame is sized to the chart. Tab
from the control before it enters the chart, the arrow keys read it, and
Shift+Tab goes back to that control.

The same works for lattice charts and for Base R charts, which are
recorded as they are drawn and shown with
[`show()`](https://r.maidr.ai/reference/show.md) and no argument. Charts
of these kinds become a document in webR that a keyboard reads in the
page: a ggplot2 bar chart, a faceted scatter plot and a patchwork of a
scatter plot and a bar chart, lattice
[`xyplot()`](https://rdrr.io/pkg/lattice/man/xyplot.html) and
[`barchart()`](https://rdrr.io/pkg/lattice/man/xyplot.html), and Base R
[`barplot()`](https://r.maidr.ai/reference/base-r-wrappers.md),
`plot(type = "l")`,
[`boxplot()`](https://r.maidr.ai/reference/base-r-wrappers.md) and a
two-panel layout.

## The page must be able to run code for R

R runs in a web worker, which cannot touch the page.
[`show()`](https://r.maidr.ai/reference/show.md) asks webR to run a
small script on the page’s own thread, and webR can do that only over a
channel that can wait for the page: the `SharedArrayBuffer` or service
worker channel. The `SharedArrayBuffer` channel needs the page to be
served with

    Cross-Origin-Opener-Policy: same-origin
    Cross-Origin-Embedder-Policy: require-corp

The script is added with `new Function()`, so a page whose
`Content-Security-Policy` forbids `unsafe-eval` cannot take it either.

Where either is not possible,
[`show()`](https://r.maidr.ai/reference/show.md) cannot reach the page
and says why, in a message, and saves the document to a temporary file
in webR’s file system. Take the document from R yourself instead, which
works over every channel:

``` js
await webR.evalRVoid(`
  options(maidr.webr_display = function(html) assign(".maidr_html", html, globalenv()))
`);
await webR.evalRVoid("show(ggplot(mtcars, aes(wt, mpg)) + geom_point())");
const html = await (await webR.evalR(".maidr_html")).toString();

const frame = document.createElement("iframe");
frame.srcdoc = html;
frame.allow = "bluetooth; serial";
document.getElementById("maidr-output").append(frame);
```

The document is a complete page with maidr.js in it, about 1.8 MB, so it
does not depend on a CDN and works offline.

## Show charts your own way

Two hooks replace the iframe, and both receive the document as a string.

- `globalThis.maidrWebRShow = (html) => { ... }`, defined on the page,
  which runs on the page’s thread.
- `options(maidr.webr_display = function(html) { ... })`, set in R.

The option comes first. Either is used instead of the iframe.

## What is not covered

htmlwidget outputs (`show(as_widget = TRUE)`, the plotly, highcharter
and echarts4r adapters) are not run under webR.
