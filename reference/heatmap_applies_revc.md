# Does This heatmap() Call Apply revC?

\`heatmap()\` normally puts reordered row 1 at the bottom of the y axis,
but its \`revC\` argument flips the drawing so row 1 lands at the top.
\`revC\` is not part of the ordering \`heatmap()\` returns, and it
defaults to \`identical(Colv, "Rowv")\` – which is TRUE for every \`symm
= TRUE\` call, since \`Colv\` itself defaults to \`"Rowv"\` there.

## Usage

``` r
heatmap_applies_revc(args)
```

## Arguments

- args:

  Recorded heatmap() arguments

## Value

TRUE when \`revC\` applies, i.e. the drawn rows read top-down
