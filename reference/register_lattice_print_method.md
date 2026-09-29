# Set MAIDR's print function as lattice's print hook

Stores whatever print function was set before – `NULL` unless the user
or another package set one – so a print MAIDR does not render is drawn
the way it would have been without MAIDR. Does nothing until lattice's
namespace is loaded;
[`.maidr_lattice_onload_hook()`](https://r.maidr.ai/reference/dot-maidr_lattice_onload_hook.md)
calls it again then.

## Usage

``` r
register_lattice_print_method()
```

## Value

NULL (invisible)

## Details

Whether the hook is set is read from the option itself, not from a flag
kept here: the option goes when lattice's namespace is unloaded and
loaded again, and a user can set it to something else, and a flag would
then say the hook was set when it was not, so neither the onLoad hook
nor [`maidr_on()`](https://r.maidr.ai/reference/maidr_on.md) would set
it again.
