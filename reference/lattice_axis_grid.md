# The navigation grid of a numeric lattice axis

What the frontend's grid mode needs to lay a scatter out in cells: the
drawn range and the step between the ticks lattice draws. Those are
`pretty(limits, n = tick.number)` – the call lattice's own
`formattedTicksAndLabels()` makes – unless the chart placed them with
`at =`. Ticks placed unevenly have no one step, and the grid is left
without one rather than given a step the axis does not show.

## Usage

``` r
lattice_axis_grid(
  limits,
  log = FALSE,
  at = NULL,
  tick_number = NULL,
  packet = 1L
)
```

## Arguments

- limits:

  The packet's limits on this axis

- log:

  The axis' `log` scale component

- at:

  The axis' `at` scale component: `FALSE`, the tick positions, or a list
  of them with one element per packet

- tick_number:

  The axis' `tick.number` scale component

- packet:

  The packet, to pick its ticks from a per-packet `at`

## Value

A list with `min`, `max` and, when the ticks are evenly spaced,
`tickStep`; `NULL` for an axis that is not a finite numeric range on a
linear scale.
