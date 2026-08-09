# Name a recorded call's arguments the way R matched them

A wrapper declared \`function(...)\` sees only the names the user typed,
so \`hist(x, 20)\` records an unnamed \`20\` and every processor asking
for \`args\[\["breaks"\]\]\` comes up empty. Running the recorded
arguments through \`match.call()\` against the definition R actually
dispatched to restores the names R itself assigned, once, for every
processor.

## Usage

``` r
match_recorded_args(function_name, definition, args)
```

## Arguments

- function_name:

  Name of the recorded function

- definition:

  The original (unwrapped) function that was called

- args:

  Recorded argument list of evaluated values

## Value

\`args\` with the names R matched, in the recorded order

## Details

Two properties are preserved deliberately:

\* \*\*Order.\*\* \`match.call()\` reorders arguments into formal order;
the recorded list keeps the user's order and only gains names. Replay
does \`do.call()\`, which honours names regardless of position, while
\`apply_barplot_sorting()\` and friends still find the height in slot 1.
\* \*\*The dispatch argument stays exactly as written.\*\* S3 dispatch
happens on the first argument of the \*generic\*, and methods are free
to rename it: \`plot.formula()\` calls it \`formula\`, not \`x\`. Naming
a positional first argument would therefore break replay in one
direction or the other (\`plot(x = mpg ~ wt)\` never reaches
\`plot.formula()\`, and \`plot(formula = ...)\` never satisfies the
generic). Leaving it untouched makes the replayed call dispatch
byte-identically to the user's.
