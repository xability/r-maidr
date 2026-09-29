# A trellis object carrying the theme of the device the reader looks at

lattice keeps a theme per kind of device and draws with the theme of the
device it draws on, so a chart MAIDR draws off-screen to read it would
be drawn with that device's own. A theme the reader set with
[`trellis.par.set()`](https://rdrr.io/pkg/lattice/man/trellis.par.get.html)
on the current device – larger text, colours they can tell apart – goes
with the chart as its own `par.settings`, which lattice applies for that
drawing only, under whatever settings the chart was given itself. With
no device open nothing has been set, and asking lattice would open a
device.

## Usage

``` r
lattice_carry_theme(plot)
```

## Arguments

- plot:

  A trellis object

## Value

The trellis object, carrying the theme.
