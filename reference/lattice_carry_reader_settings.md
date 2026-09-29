# A trellis object carrying what the reader changed on MAIDR's hidden device

A chart MAIDR moves off its hidden device onto a screen
([`lattice_draw_on_screen()`](https://r.maidr.ai/reference/lattice_draw_on_screen.md))
is drawn with the screen's own lattice theme, which holds whatever the
reader set on a screen of that kind before. What they set while the
hidden device was current went to the hidden device's kind, `pdf`, since
they had no other device. So only that goes with the chart, as its own
`par.settings`: the settings in which the hidden device's theme differs
from the theme lattice starts a device of its kind with
([`lattice_starting_theme()`](https://r.maidr.ai/reference/lattice_starting_theme.md)).
Carried whole, the `pdf` defaults would replace what the reader set on
the screen's kind.

## Usage

``` r
lattice_carry_reader_settings(plot)
```

## Arguments

- plot:

  A trellis object

## Value

The trellis object, carrying the settings the reader changed.
