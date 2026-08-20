# The name of the lane at one position on the lane axis

A discrete scale lays its levels out at 1, 2, 3 and so on, so the name
is the level at that index. A continuous lane axis has no names and the
position itself is what a reader is told – `GanttPoint$x` takes a number
or a string for exactly this reason.

## Usage

``` r
lane_name(slot, lane_names = NULL)
```

## Arguments

- slot:

  One or more positions on the lane axis

- lane_names:

  The lane names in drawn order, or NULL

## Value

The lane names, or the positions unchanged
