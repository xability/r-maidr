# Turn a horizontal box-family layer round for the frontend

`BoxTrace`, `ViolinBoxTrace` and `ViolinTrace` each reverse a horizontal
layer on the way in – "reverse points to match visual order (lower-left
start)", as `src/model/box.ts` puts it. The reversal is unconditional,
so the producer has to hand them the *opposite* order for the result to
come out lower-left first, and a layer emitted in its own natural
bottom-to-top order is read from the top down instead.

## Usage

``` r
reverse_horizontal_box_layer(layer)
```

## Arguments

- layer:

  A layer list carrying `data`, `selectors` and `orientation`

## Value

The layer, with both halves reversed when it is horizontal

## Details

Both halves move together. The frontend reverses the resolved highlight
alongside the points (`BoxTrace` explicitly, `ViolinTrace` by reversing
the selectors before it resolves them), so a layer that reversed only
its data would trade a correct outline for a wrong one.

Only the emission order changes. Each entry keeps its own category name
and its own statistics, and `orientation` still says which axis the
values are drawn along.

Worth stating what this does not settle: the frontend's reversal may
exist *because* py-maidr reverses, in which case the cleaner fix is to
drop it there and let every producer emit in its own natural order. That
is a three-repository change and a released-behaviour change for
py-maidr readers, so it is left to the maintainer. Until then the two
bindings agree, which is the part a reader can feel.
