# lattice System Initialization

Initialize and register the lattice system with the global registry.
This function sets up the lattice adapter and processor factory.

## Usage

``` r
initialize_lattice_system()
```

## Value

NULL (invisible)

## Details

Registered between ggplot2 and Base R. The order matters less than it
did: the Base R adapter used to claim any object whenever the current
device held a recorded call, so a trellis object reached it first and
was silently exported as the recorded Base R chart. It now declines the
objects another system draws (`BaseRAdapter$can_handle()`), and the
order is kept as a second line of defence.
