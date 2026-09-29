# The grob-name prefix the lattice system draws with

lattice names every grob it draws `<prefix>.<name>...`, with the prefix
`plot_01`, `plot_02`, ... counted across prints unless one is given.
Drawing with a fixed prefix gives the same ids every time, so selectors
can be written before the chart is exported.

## Usage

``` r
LATTICE_PREFIX
```
