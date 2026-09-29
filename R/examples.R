#' Run MAIDR Example Plots
#'
#' Launches example plots demonstrating MAIDR's accessible visualization
#' capabilities. Each example creates an interactive plot using `show()`.
#'
#' @param example Character string specifying which example to run. If `NULL`
#'   (the default), lists all available examples.
#' @param type Character string specifying the plot system to use:
#'   `"ggplot2"` (default), `"base_r"` or `"lattice"`.
#'
#' @return Invisibly returns `NULL`. Called for its side effect of displaying
#'   an interactive plot in the browser or listing available examples.
#'
#' @details
#' Available examples include various plot types such as bar charts,
#' histograms, scatter plots, line plots, boxplots, heatmaps, and more.
#'
#' The `"lattice"` examples are a bar chart \[experimental\], a histogram
#' \[experimental\], a scatter plot \[experimental\], a box plot
#' \[experimental\] and a conditioned (faceted) scatter plot
#' \[experimental\]. Every chart maidr reads from 'lattice' is
#' experimental: none has been through a user study, and each may change
#' without a deprecation period. They need the 'lattice' package.
#'
#' Each example script creates a plot and calls `show()` to display it
#' in your default web browser with full MAIDR accessibility features
#' including keyboard navigation and screen reader support.
#'
#' @examples
#' # List all available examples
#' run_example()
#'
#' if (interactive()) {
#'   # Run ggplot2 bar chart example
#'   run_example("bar")
#'
#'   # Run Base R histogram example
#'   run_example("histogram", type = "base_r")
#'
#'   # Run lattice box plot example [experimental]
#'   run_example("boxplot", type = "lattice")
#' }
#'
#' @seealso [show()] for displaying plots, [save_html()] for saving to file
#' @export
run_example <- function(example = NULL, type = c("ggplot2", "base_r", "lattice")) {
  type <- match.arg(type)

  # Get the examples directory

  examples_dir <- system.file("examples", type, package = "maidr")

  if (examples_dir == "") {
    stop(
      "Could not find examples directory. ",
      "Try re-installing the maidr package.",
      call. = FALSE
    )
  }

  # List all available examples

  example_files <- list.files(examples_dir, pattern = "\\.R$", full.names = FALSE)
  available_examples <- sub("\\.R$", "", example_files)

  # If no example specified, list all available

  if (is.null(example)) {
    message("Available MAIDR examples:\n")

    # Every lattice reading is experimental, so its heading says so, as the
    # rest of the docs mark an experimental type wherever they name it.
    headings <- c(
      ggplot2 = "ggplot2 examples:",
      base_r = "\nbase_r examples:",
      lattice = "\nlattice examples [experimental]:"
    )
    for (plot_system in names(headings)) {
      message(headings[[plot_system]])
      system_dir <- system.file("examples", plot_system, package = "maidr")
      if (system_dir != "") {
        system_examples <- sub("\\.R$", "", list.files(system_dir, pattern = "\\.R$"))
        if (length(system_examples) > 0) {
          for (ex in system_examples) {
            message("  - ", ex)
          }
        } else {
          message("  (no examples found)")
        }
      }
    }

    message("\nUsage:")
    message("  run_example(\"bar\")                 # Run ggplot2 bar chart")
    message("  run_example(\"histogram\", \"base_r\") # Run Base R histogram")
    message("  run_example(\"boxplot\", \"lattice\")  # Run lattice box plot [experimental]")

    return(invisible(NULL))
  }

  # Check that we're in interactive mode before running examples
  # This ensures examples don't execute in automated testing or package checks
  if (!interactive()) {
    warning(
      "run_example() is designed for interactive use only.\n",
      "Examples modify the global environment and require a browser/viewer.\n",
      "To see available examples, call run_example() without arguments.",
      call. = FALSE
    )
    return(invisible(NULL))
  }

  # Check if example exists
  if (!example %in% available_examples) {
    stop(
      sprintf("Example '%s' not found for type '%s'.\n", example, type),
      "Available examples: ", paste(available_examples, collapse = ", "),
      call. = FALSE
    )
  }

  # Run the example
  example_file <- file.path(examples_dir, paste0(example, ".R"))
  message(sprintf("Running %s example: %s", type, example))

  # Clear any leftover device storage from previous runs to prevent call accumulation
  clear_all_device_storage()

  # Source the example file in global environment
  # This ensures wrapped Base R functions are found for MAIDR patching
  source(example_file, local = FALSE)

  invisible(NULL)
}
