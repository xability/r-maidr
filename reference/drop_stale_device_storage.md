# Drop what was recorded on devices that are no longer open

The Base R calls, and the ggplot2 and lattice charts queued for a figure
(`draw_as_knit_figure()`). Calls are kept by device number, and knitr
gives every chunk the same number: the layout calls a chunk recorded
would govern the next chunk's charts, and a chunk's records would be
kept for the whole knit.

## Usage

``` r
drop_stale_device_storage(include_current = FALSE)
```

## Arguments

- include_current:

  Drop the current device's records as well

## Value

NULL (invisible)
