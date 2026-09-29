# Why a trellis object cannot be read, before it is drawn

Each reason is something a stock chart never carries: a high-level
function the lattice system does not read, a panel function other than
that function's own, a superpanel or `panel.groups` a stock call never
sets, the marker latticeExtra leaves on a panel it has layered, or no
packets at all. The grobs drawn are audited as well, after drawing
([`lattice_panel_audit()`](https://r.maidr.ai/reference/lattice_panel_audit.md)),
because some of these draw exactly what a stock chart does.

## Usage

``` r
lattice_static_check(plot)
```

## Arguments

- plot:

  A trellis object

## Value

Character vector of reasons, empty when the object can be read.
