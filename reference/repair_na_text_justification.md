# Repair NA text-grob justification so gridSVG can export the tree

\`gridGraphics::grid.echo()\` translates some base graphics text into
grid text grobs that leave \`vjust\` (and, in principle, \`hjust\`) as
NA and defer to the grob's \`just\` field instead. gridSVG 1.7.7 passes
the raw value to \`gridSVG:::justTovjust()\`, which branches on it
directly and fails with "missing value where TRUE/FALSE needed",
aborting \`gridSVG::grid.export()\` from \`devGrob.text\`.
\`graphics::pie()\` is the case that bites: it labels every wedge, so
before this repair no base R pie chart could be exported at all –
\`pie(..., labels = NA)\`, which draws no text, exported fine, which is
what pins the failure on these grobs. \`barplot()\` and friends are
unaffected because their text grobs already carry a numeric
justification.

## Usage

``` r
repair_na_text_justification(grob)
```

## Arguments

- grob:

  A grob, gTree, gList, or gtable (or NULL)

## Value

The same tree with NA \`hjust\`/\`vjust\` on text grobs set to 0.5

## Details

Only NA components of text grobs are rewritten, so a grob that already
has a usable justification passes through untouched. 0.5 is exactly what
grid resolves NA to for the \`just = "centre"\` these grobs declare, so
the drawn output is byte-identical.

This is an upstream gridSVG/gridGraphics incompatibility rather than
anything maidr introduced; drop this repair if gridSVG ever handles NA
justification itself.
