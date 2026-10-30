# Create the wrapper that records barplot()

Draws the bars from the arguments the author wrote, in their order, and
records those same arguments: the chart maidr exports is drawn again
from the record, and the bars are read from it. The wrapper used to sort
the categories and the series alphabetically first, so the chart was
drawn and read in an order the author had not chosen, and `legend.text`
and `col`, which it left as they were, named and coloured another row's
bars.

## Usage

``` r
create_barplot_wrapper(original_function)
```

## Arguments

- original_function:

  Original barplot function

## Value

Wrapped function
