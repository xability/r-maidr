# Whether the density half of a violin can be computed at all

`sm` is in vioplot's `Depends`, so it is attached wherever a violin can
have been drawn: in any normal installation this cannot fail, and the
branch is unreachable. Kept as a guard rather than an assumption only so
a broken or partial installation surfaces as no violin layer rather than
a bare "there is no package called 'sm'" thrown from inside a rendering
path.

## Usage

``` r
has_sm_package()
```

## Value

`TRUE` when `sm` can be loaded.
