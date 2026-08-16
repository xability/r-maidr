# Position classes that displace a point from where its data puts it

`PositionJitterdodge` does **not** inherit from `PositionJitter` – both
descend straight from `Position` – so it has to be named rather than
caught by inheritance. Its dodge is removed along with its jitter, which
is correct for the same reason: the offset that separates hue groups is
drawn geometry, and the group itself is carried as an aesthetic, so
nothing is lost by putting the point back on its category.

## Usage

``` r
JITTER_POSITION_CLASSES
```
