# Why the grobs drawn in a chart's panels cannot be read

The reading of each panel function is written against what it draws. A
grob a panel draws that is not in `LATTICE_PANEL_ROLES` – an error
message a panel function printed instead of its marks, a primitive a
custom `identifier =` renamed, a region lattice fills with polygons
rather than cells – is something the reading would silently leave out,
and a name drawn twice in one panel is two overlays the selectors cannot
tell apart – unless it is decoration, which no selector addresses.

## Usage

``` r
lattice_panel_audit(entries)
```

## Arguments

- entries:

  The panel grobs, from
  [`lattice_panel_grobs()`](https://r.maidr.ai/reference/lattice_panel_grobs.md)

## Value

Character vector of reasons, empty when every panel can be read.
