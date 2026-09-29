# Say what kind each named layer is, in a panel of more than one kind

A layer's `name` is announced on a layer switch in place of its type,
which is what a group's name is for when a panel's layers are all the
same kind of thing. Where they are not – a group's points and the line
through them, `type = "b"`; points under a fitted curve – the bare group
names would say "4", "6", "8", "4", "6", "8" with nothing to tell the
points from the lines, so each named layer says its type too: "4
(line)".

## Usage

``` r
lattice_qualify_layer_names(layers, kinds)
```

## Arguments

- layers:

  A subplot's layers

- kinds:

  What kind of curve or mark each layer is, from
  [`lattice_layer_kind()`](https://r.maidr.ai/reference/lattice_layer_kind.md)

## Value

The layers, their names qualified by type when the subplot's layers are
not all one type, and by kind where two would otherwise be announced
alike.

## Details

Two curves of one type – the line through the data and the line through
its averages, `type = c("l", "a")`; a loess and a spline – would still
be announced alike: by group alone or by group and type when they are
named, and by their type when they are not, as a curve whose groups
share an x is kept whole and unnamed
([`lattice_split_series()`](https://r.maidr.ai/reference/lattice_split_series.md)).
So those say which curve they are instead: "4 (line)" and "4 (average)",
"4 (loess)" and "4 (spline)", or, unnamed, "line" and "average"
([`lattice_layer_kind()`](https://r.maidr.ai/reference/lattice_layer_kind.md)).
