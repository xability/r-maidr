# Name a layer after the group it holds

A chart that draws one group per colour says in its legend which group
is which: a title, and an entry per group. A layer holding one group is
named with both, `"Cylinders 6"`, so a reader moving between layers is
told what they are on; the entry alone, `"6"`, says nothing about what
the number counts. An entry that already begins with the title, as
`"Group B"` does under the title "Group", is the name on its own.

## Usage

``` r
group_layer_name(level, title = NULL)
```

## Arguments

- level:

  The group's legend entry

- title:

  The legend's title, or NULL when it has none

## Value

The layer's name
