# Adaptively simplify a 2D curve to a target number of points

Uses binary search on epsilon to find the smallest tolerance that yields
at most \`target\` retained points.

## Usage

``` r
simplify_curve(points, target, min_epsilon = 0, max_iterations = 50L)
```

## Arguments

- points:

  Nx2 numeric matrix of ordered (x, y) points

- target:

  Desired maximum number of retained points

- min_epsilon:

  Lower bound for epsilon search (default 0)

- max_iterations:

  Maximum binary-search iterations (default 50)

## Value

Logical vector of length N (TRUE = keep this point)
