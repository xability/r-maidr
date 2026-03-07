# Ramer-Douglas-Peucker algorithm for 2D polylines

Iterative stack-based implementation to avoid R recursion limits.

## Usage

``` r
rdp(points, epsilon)
```

## Arguments

- points:

  Nx2 numeric matrix of ordered (x, y) points

- epsilon:

  Maximum allowed perpendicular distance. Larger values yield fewer
  retained points.

## Value

Logical vector of length N (TRUE = keep this point)
