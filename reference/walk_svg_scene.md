# Walk a grabbed scene, redrawing it with batch markers

Walk a grabbed scene, redrawing it with batch markers

## Usage

``` r
walk_svg_scene(scene, one_at_a_time = FALSE)
```

## Arguments

- scene:

  The gTree `grid.grab()` returned.

- one_at_a_time:

  Draw rect and circle grobs one element at a time.

## Value

The walk state (events per marker, symbol use).
