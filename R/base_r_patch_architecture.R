#' Base R Patch Architecture
#'
#' Modular system for patching Base R plotting functions with chain of responsibility pattern
#'
#' @keywords internal

# Abstract base class for all patchers
BaseRPatcher <- R6::R6Class(
  "BaseRPatcher",
  public = list(
    can_patch = function(function_name, args) {
      stop("Abstract method - must be implemented by subclass")
    },
    apply_patch = function(function_name, args) {
      stop("Abstract method - must be implemented by subclass")
    },

    # Get the patcher name for debugging
    get_name = function() {
      stop("Abstract method - must be implemented by subclass")
    }
  )
)

# Sorting patcher for consistent ordering
SortingPatcher <- R6::R6Class(
  "SortingPatcher",
  inherit = BaseRPatcher,
  public = list(
    can_patch = function(function_name, args) {
      # Handle barplot function
      if (function_name == "barplot") {
        height <- args[[1]]
        # Only patch if height is a vector or matrix
        is.vector(height) || is.matrix(height)
      } else {
        FALSE
      }
    },
    apply_patch = function(function_name, args) {
      if (function_name == "barplot") {
        self$patch_barplot(args)
      } else {
        args
      }
    },
    patch_barplot = function(args) {
      height <- args[[1]]

      if (is.vector(height)) {
        # Simple bar plot - sort by x values (names)
        self$patch_simple_barplot(args)
      } else if (is.matrix(height)) {
        # Matrix bar plot - determine if dodged or stacked
        if (self$is_dodged_barplot(args)) {
          self$patch_dodged_barplot(args)
        } else {
          self$patch_stacked_barplot(args)
        }
      } else {
        args
      }
    },
    patch_simple_barplot = function(args) {
      height <- args[[1]]

      names_arg <- args$names.arg
      if (is.null(names_arg)) {
        names_arg <- names(height)
      }

      if (!is.null(names_arg)) {
        sorted_indices <- order(names_arg)

        # Reorder height vector
        height <- height[sorted_indices]
        args[[1]] <- height

        if ("names.arg" %in% names(args)) {
          args$names.arg <- names_arg[sorted_indices]
        }

        if (!is.null(names(height))) {
          names(height) <- names_arg[sorted_indices]
        }
      }

      args
    },
    patch_dodged_barplot = function(args) {
      height_matrix <- args[[1]]

      # Sort fill values (rows) in ascending order for consistent visual ordering
      if (!is.null(rownames(height_matrix))) {
        sorted_fill_values <- sort(rownames(height_matrix))
        reordered_matrix <- height_matrix[sorted_fill_values, , drop = FALSE]
      } else {
        # No row names - keep original order
        reordered_matrix <- height_matrix
      }

      if (!is.null(colnames(height_matrix))) {
        sorted_x_values <- sort(colnames(height_matrix))
        reordered_matrix <- reordered_matrix[, sorted_x_values, drop = FALSE]

        if ("names.arg" %in% names(args)) {
          original_indices <- match(sorted_x_values, colnames(height_matrix))
          args$names.arg <- args$names.arg[original_indices]
        }
      }

      args[[1]] <- reordered_matrix
      args
    },
    patch_stacked_barplot = function(args) {
      # For stacked bar plots, we might want different sorting logic
      # For now, apply same logic as dodged bars
      self$patch_dodged_barplot(args)
    },
    is_dodged_barplot = function(args) {
      if (!is.null(args$beside) && args$beside == TRUE) {
        return(TRUE)
      }

      if (is.null(args$beside)) {
        return(FALSE) # Default is stacked
      }

      FALSE
    },
    get_name = function() {
      "SortingPatcher"
    }
  )
)

# Patch Manager - orchestrates all patchers
PatchManager <- R6::R6Class(
  "PatchManager",
  private = list(
    .patchers = list()
  ),
  public = list(
    initialize = function() {
      # Register default patchers
      private$.patchers <- list(
        SortingPatcher$new()
      )
    },
    add_patcher = function(patcher) {
      if (!inherits(patcher, "BaseRPatcher")) {
        stop("Patcher must inherit from BaseRPatcher")
      }
      private$.patchers[[length(private$.patchers) + 1]] <- patcher
    },
    apply_patches = function(function_name, args) {
      for (patcher in private$.patchers) {
        if (patcher$can_patch(function_name, args)) {
          args <- patcher$apply_patch(function_name, args)
        }
      }
      args
    },
    get_patcher_names = function() {
      sapply(private$.patchers, function(p) p$get_name())
    }
  )
)

# Global patch manager instance
global_patch_manager <- NULL

get_patch_manager <- function() {
  if (is.null(global_patch_manager)) {
    global_patch_manager <<- PatchManager$new()
  }
  global_patch_manager
}
