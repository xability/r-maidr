#' Run MAIDR Example Plots
#'
#' Launches example plots demonstrating MAIDR's accessible visualization
#' capabilities. Each example creates an interactive plot using `show()`.
#'
#' @param example Character string specifying which example to run. If `NULL`
#'   (the default), lists all available examples.
#' @param type Character string specifying the plot system to use.
#'   Either `"ggplot2"` (default) or `"base_r"`.
#'
#' @return Invisibly returns `NULL`. Called for its side effect of displaying
#'   an interactive plot in the browser or listing available examples.
#'
#' @details
#' Available examples include various plot types such as bar charts,
#' histograms, scatter plots, line plots, boxplots, heatmaps, and more.
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
#' }
#'
#' @seealso [show()] for displaying plots, [save_html()] for saving to file
#' @export
run_example <- function(example = NULL, type = c("ggplot2", "base_r")) {
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

    message("ggplot2 examples:")
    ggplot2_dir <- system.file("examples", "ggplot2", package = "maidr")
    if (ggplot2_dir != "") {
      ggplot2_examples <- sub("\\.R$", "", list.files(ggplot2_dir, pattern = "\\.R$"))
      if (length(ggplot2_examples) > 0) {
        for (ex in ggplot2_examples) {
          message("  - ", ex)
        }
      } else {
        message("  (no examples found)")
      }
    }

    message("\nbase_r examples:")
    base_r_dir <- system.file("examples", "base_r", package = "maidr")
    if (base_r_dir != "") {
      base_r_examples <- sub("\\.R$", "", list.files(base_r_dir, pattern = "\\.R$"))
      if (length(base_r_examples) > 0) {
        for (ex in base_r_examples) {
          message("  - ", ex)
        }
      } else {
        message("  (no examples found)")
      }
    }

    message("\nUsage:")
    message("  run_example(\"bar\")                 # Run ggplot2 bar chart")
    message("  run_example(\"histogram\", \"base_r\") # Run Base R histogram")

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
