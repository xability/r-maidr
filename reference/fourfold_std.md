# Resolve a recorded `std` the way `fourfoldplot()` itself resolves it

[`graphics::fourfoldplot`](https://rdrr.io/r/graphics/fourfoldplot.html)
runs `std <- match.arg(std)`, so partial spellings are legal calls that
draw the counts. Measured on R 4.3.3, every one of these is admitted:

## Usage

``` r
fourfold_std(args)
```

## Arguments

- args:

  The arguments recorded from the
  [`fourfoldplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
  call.

## Value

One of `"margins"`, `"ind.max"` or `"all.max"`.

## Details


      <absent> -> margins   "margins" -> margins   "m"   -> margins
      "ma"     -> margins   "ind.max" -> ind.max   "ind" -> ind.max
      "i"      -> ind.max   "in"      -> ind.max   "all.max" -> all.max
      "all"    -> all.max   "a"       -> all.max
      c("margins", "ind.max", "all.max") -> margins

So `identical(args[["std"]], "ind.max")` would silently decline five
legal spellings. The one existing exact-comparison idiom in this
package, `base_r_subseries_layer_processor.R`'s `spikes()`, is complete
only because `monthplot`'s `type` choices are the single characters
`"l"` and `"h"`, where partial matching cannot produce a non-choice
string. `std`'s choices are multi-character, so the same idiom is
incomplete here.

Anything [`match.arg()`](https://rdrr.io/r/base/match.arg.html) rejects
resolves to `"margins"`, which declines: measured, `"IND.MAX"`, `"x"`,
`NA_character_`, `character(0)` and `c("ind.max", "margins")` all error
inside [`match.arg()`](https://rdrr.io/r/base/match.arg.html), and
[`fourfoldplot()`](https://r.maidr.ai/reference/base-r-wrappers.md)
itself raises the identical error first, so none of them is reachable
from a drawn chart. The `tryCatch` is there so that a reader never
[`stop()`](https://rdrr.io/r/base/stop.html)s and takes the whole figure
with it – the reason
[`recorded_flag()`](https://r.maidr.ai/reference/recorded_flag.md) gives
for the same shape.

A non-character `std` is refused before
[`match.arg()`](https://rdrr.io/r/base/match.arg.html) rather than
coerced. Measured, `fourfoldplot(tb, std = 1L)`, `std = TRUE` and
`std = factor("ind.max")` all stop with "'arg' must be NULL or a
character vector"; `as.character(factor("ind.max"))` would have been
accepted here and would have read a call that upstream refuses to draw.

`args[["std"]]`, not `args$std`: `$` partial-matches a list, the
collision recorded in
[`recorded_main_title()`](https://r.maidr.ai/reference/recorded_main_title.md).
