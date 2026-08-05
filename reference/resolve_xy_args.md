# Resolve x/y data arguments from a recorded call's argument list

Mirrors how plot()/points()/lines() match their arguments: named
\`x\`/\`y\` win, then the first two UNNAMED arguments in order. Blind
positional access (\`args\[\[2\]\]\`) would grab graphical parameters
instead (plot(x, type = "l") -\> y = "l") or error for single-argument
calls (plot(v), lines(v)).

## Usage

``` r
resolve_xy_args(args)
```

## Arguments

- args:

  Recorded argument list

## Value

List with \`x\` and \`y\` (either may be NULL)
