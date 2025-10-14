#' Base R Patch Architecture
#'
#' Modular system for patching Base R plotting functions with chain of responsibility pattern
#'
#' @keywords internal

# Abstract base class for all patchers
BaseRPatcher <- R6::R6Class("BaseRPatcher",
  public = list(
    # Check if this patcher should handle the given function
    can_patch = function(function_name, args) {
      stop("Abstract method - must be implemented by subclass")
    },
    
    # Apply the patch transformation
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
SortingPatcher <- R6::R6Class("SortingPatcher",
  inherit = BaseRPatcher,
  public = list(
    can_patch = function(function_name, args) {
      # Handle barplot function
      if (function_name == "barplot") {
        height <- args[[1]]
        # Only patch if height is a vector or matrix
        return(is.vector(height) || is.matrix(height))
      }
      return(FALSE)
    },
    
    apply_patch = function(function_name, args) {
      if (function_name == "barplot") {
        return(self$patch_barplot(args))
      }
      return(args)
    },
    
    patch_barplot = function(args) {
      height <- args[[1]]
      
      if (is.vector(height)) {
        # Simple bar plot - sort by x values (names)
        return(self$patch_simple_barplot(args))
      } else if (is.matrix(height)) {
        # Matrix bar plot - determine if dodged or stacked
        if (self$is_dodged_barplot(args)) {
          return(self$patch_dodged_barplot(args))
        } else {
          return(self$patch_stacked_barplot(args))
        }
      }
      
      return(args)
    },
    
    patch_simple_barplot = function(args) {
      height <- args[[1]]
      
      # Get names (x-axis values)
      names_arg <- args$names.arg
      if (is.null(names_arg)) {
        names_arg <- names(height)
      }
      
      if (!is.null(names_arg)) {
        # Sort by names (x-axis values)
        sorted_indices <- order(names_arg)
        
        # Reorder height vector
        height <- height[sorted_indices]
        args[[1]] <- height
        
        # Update names.arg if it exists
        if ("names.arg" %in% names(args)) {
          args$names.arg <- names_arg[sorted_indices]
        }
        
        # Update names attribute if it exists
        if (!is.null(names(height))) {
          names(height) <- names_arg[sorted_indices]
        }
      }
      
      return(args)
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
      
      # Sort by x values (columns) for consistent category ordering
      if (!is.null(colnames(height_matrix))) {
        sorted_x_values <- sort(colnames(height_matrix))
        reordered_matrix <- reordered_matrix[, sorted_x_values, drop = FALSE]
        
        # Update names.arg if it exists to match reordered columns
        if ("names.arg" %in% names(args)) {
          original_indices <- match(sorted_x_values, colnames(height_matrix))
          args$names.arg <- args$names.arg[original_indices]
        }
      }
      
      args[[1]] <- reordered_matrix
      return(args)
    },
    
    patch_stacked_barplot = function(args) {
      # For stacked bar plots, we might want different sorting logic
      # For now, apply same logic as dodged bars
      return(self$patch_dodged_barplot(args))
    },
    
    is_dodged_barplot = function(args) {
      # Check if beside = TRUE (explicit dodged)
      if (!is.null(args$beside) && args$beside == TRUE) {
        return(TRUE)
      }
      
      # Check if beside is NULL (default for matrix is FALSE, but let's be explicit)
      if (is.null(args$beside)) {
        return(FALSE)  # Default is stacked
      }
      
      return(FALSE)
    },
    
    get_name = function() {
      return("SortingPatcher")
    }
  )
)

# Patch Manager - orchestrates all patchers
PatchManager <- R6::R6Class("PatchManager",
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
      # Apply patches in sequence (chain of responsibility)
      for (patcher in private$.patchers) {
        if (patcher$can_patch(function_name, args)) {
          args <- patcher$apply_patch(function_name, args)
        }
      }
      return(args)
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
  return(global_patch_manager)
}
