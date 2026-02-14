## Resubmission

This package was archived on CRAN due to an R CMD check NOTE about
`assign(..., envir = .GlobalEnv)` in `base_r_function_patching.R`.

In this resubmission (0.1.1) I have:

* Completely removed all `.GlobalEnv` assignments. Base R function wrappers
  are now installed into the package namespace during `.onLoad()` (when the
  namespace is still open) and controlled via an active/inactive flag.
  `maidr_on()` activates recording; `maidr_off()` deactivates it. No
  modification of the user's global environment occurs at any point.
* Removed `attach()` usage (which also produced a NOTE).
* Fixed Rd documentation warning from unicode escape sequences.

## R CMD check results

0 errors | 0 warnings | 0 notes

## Test environments

* local macOS Sequoia 15.5, R 4.5.1
* win-builder (R-devel, R-release)

## Downstream dependencies

This is a new package with no reverse dependencies.
