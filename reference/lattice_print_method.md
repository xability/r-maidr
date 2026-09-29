# lattice Print Interception

Printing a trellis object at the console – typing its name, or calling
[`print()`](https://rdrr.io/r/base/print.html) on it – renders it in the
MAIDR interactive viewer, as printing a ggplot2 object does.

## Details

The hook is lattice's own: `print.trellis()` draws with
`lattice.getOption("print.function")` when one is set, and with
`plot.trellis()` otherwise. Setting that option intercepts every print
without touching the S3 method table, and is undone by setting it back.
lattice is only in Suggests, so the option is set when lattice's
namespace loads
([`.maidr_lattice_onload_hook()`](https://r.maidr.ai/reference/dot-maidr_lattice_onload_hook.md)),
or at once when it is already loaded.
