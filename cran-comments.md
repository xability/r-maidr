## Resubmission

This is a resubmission. Changes made based on CRAN feedback:

* Single-quoted 'ggplot2' in DESCRIPTION as requested.

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
  necessary for the package's accessibility functionality:

  1. **Why patching is needed**: Unlike 'ggplot2' (which returns plot objects
     suitable for S3 method dispatch), Base R graphics functions like `barplot()`,
     `hist()`, and `boxplot()` are imperative - they draw directly to the graphics
     device and don't return plot objects. This makes traditional S3 print method
     overriding infeasible.

  2. **User control**: The patching is fully opt-in via `maidr_on()` and
     reversible via `maidr_off()`. Original functions are preserved and restored.

  3. **Safe fallback**: Unsupported plot types automatically fall back to R's
     native graphics rendering with a warning.

  4. **Accessibility purpose**: maidr enables blind and visually impaired users
     to explore data visualizations through keyboard navigation, sonification,
     and screen reader support. Minimizing required code changes reduces barriers
     for these users.

## Test environments

* local macOS Sequoia 15.5, R 4.5.1
* win-builder (devel, release)
* R-hub (multiple platforms)

## Downstream dependencies

This is a new package with no reverse dependencies.
