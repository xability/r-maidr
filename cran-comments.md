## Resubmission

This is a resubmission addressing all reviewer comments from the previous
submission. The following changes were made:

### Reviewer comment 1: DESCRIPTION references
* Added a project reference to the Description field using the required
  format with angle brackets and no space after `https:`:
  `<https://maidr.ai/>`

### Reviewer comment 2: Replace \dontrun{} with \donttest{}
* Removed all `\dontrun{}` wrappers across the entire package (9 occurrences
  in 4 source files, 7 generated .Rd files).
* Examples executable in < 5 sec are now unwrapped (e.g., `maidr_get_fallback()`,
  `maidr_set_fallback()`, `run_example()` with no arguments).
* Slow or side-effect-producing examples use `\donttest{}` (e.g., `show()`,
  `save_html()`, `maidr_on()`).
* Shiny functions (`maidr_output()`, `render_maidr()`) use `if (interactive())`
  as they are inherently interactive.
* Base R examples that require function patching (only active in interactive
  sessions) use `if (interactive())`.

### Reviewer comment 3: Replace if(interactive()){} in run_example.Rd
* `run_example()` with no arguments (lists available examples) now runs
  unwrapped during R CMD check since it only prints text and completes
  in < 1 sec.
* Only the browser-opening calls (`run_example("bar")`, etc.) remain in
  `if (interactive())` since they source scripts that call `show()` which
  opens a browser.

### Reviewer comment 4: Restore par() with on.exit() in base_r_plot_orchestrator.R
* Added `oldpar <- graphics::par(no.readonly = TRUE)` followed immediately
  by `on.exit(graphics::par(oldpar), add = TRUE)` before any `par()`
  modifications in the `composite_func` closure within `get_gtable()`.


## R CMD check results

0 errors | 0 warnings | 0 notes

## Test environments

* local macOS Sequoia 15.5, R 4.5.1
* win-builder (R-devel, R-release)

## Downstream dependencies

This is a new package with no reverse dependencies.
