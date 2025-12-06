## R CMD check results

0 errors | 0 warnings | 1 note

## Notes

* checking R code for possible problems ... NOTE
  Found the following assignments to the global environment:
  File 'maidr/R/base_r_function_patching.R':
    assign(function_name, wrapper, envir = .GlobalEnv)
    assign("lines", lines_wrapper, envir = .GlobalEnv)
    assign("points", points_wrapper, envir = .GlobalEnv)
    assign(function_name, original_function, envir = .GlobalEnv)

  **Explanation**: These global environment assignments are intentional and
  necessary for the package's core functionality. The maidr package needs to
  intercept Base R plotting functions (barplot, hist, plot, lines, points,
  boxplot, image) to capture their arguments and graphical output. This
  interception mechanism:

  1. Temporarily wraps the original functions during a plotting session
  2. Captures the function calls and their arguments
  3. Restores the original functions after processing

  This approach is similar to how other R packages implement function

  interception (e.g., devtools, testthat). The modifications are always
  cleaned up after use, ensuring no persistent changes to the user's
  environment.

## Test environments

* local macOS Sequoia 15.5, R 4.5.1
* win-builder (devel, release)
* R-hub (multiple platforms)

## Downstream dependencies

This is a new package with no reverse dependencies.
