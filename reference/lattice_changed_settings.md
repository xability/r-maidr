# The settings in which one lattice theme differs from another

Compared setting by setting, down to the leaves: `plot.symbol$pch`
changed is that alone, not the whole of `plot.symbol`. A function
compares without its environment, as lattice builds a new one for
`shade.colors$palette` every time it builds a theme.

## Usage

``` r
lattice_changed_settings(theme, base)
```

## Arguments

- theme:

  The theme in use

- base:

  The theme it started from

## Value

A list of the settings of `theme` that differ from `base`.
