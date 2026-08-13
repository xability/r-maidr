# Distinct values of an aesthetic, in the order ggplot2 draws them

A factor follows its own level order, minus the levels nothing was drawn
for; anything else sorts in its own type's order. Sorting the values AS
TEXT reorders the columns twice over: against a factor whose levels are
not alphabetical, and against a number, where it puts 10 before 2.

## Usage

``` r
discrete_level_order(values)
```

## Arguments

- values:

  A vector of aesthetic values

## Value

Character vector of the observed levels, in drawn order, with
`NA_character_` last when the aesthetic has a missing value

## Details

The missing category comes last, which is where ggplot2 puts it for a
character column, a numeric one and an ordinary factor alike.
