# Describe a Panel-scoped Fallback

Builds the warning text used when only some panels of a multi-panel
figure lose their accessible data. Naming the panels matters: the rest
of the figure still sonifies and navigates, so the user needs to know
which panel went quiet rather than assuming the whole figure did.

## Usage

``` r
format_panel_fallback_warning(panels)
```

## Arguments

- panels:

  Integer vector of 1-based panel numbers, in drawing order

## Value

A single warning string
