#' Global Variables and Internal Function Declarations
#'
#' This file declares global variables and internal functions to avoid
#' "no visible binding for global variable" and "no visible global function
#' definition" NOTEs during R CMD check.
#'
#' @keywords internal

# Suppress R CMD check NOTEs for R6 internal references
if (getRversion() >= "2.15.1") {
  utils::globalVariables(c(
    "self",
    "private",
    "super"
  ))
}

# Suppress R CMD check NOTEs for internal package functions
# These are defined and used within the package but not exported
utils::globalVariables(c(
  "classify_function",
  "get_functions_by_class",
  "on_high_level_call",
  "on_layout_call",
  "reset_device_state"
))
