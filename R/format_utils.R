#' Format Extraction Utilities
#'
#' Utility functions for extracting and converting axis format configuration
#' from ggplot2 scale objects to MAIDR format specifications.
#'
#' @name format-utils
#' @keywords internal
NULL

# ============================================================================
# Format Extraction from Built Plot
# ============================================================================

#' Extract Format Configuration from Built Plot
#'
#' Extracts MAIDR format configuration from the scale objects in a built
#' ggplot2 plot. This looks for the \code{maidr_format} attribute attached
#' by the maidr label functions.
#'
#' @param built A built ggplot2 object from \code{ggplot2::ggplot_build()}
#' @return A list with \code{x} and/or \code{y} format configurations,
#'   or NULL if no format config is found
#' @keywords internal
extract_format_config <- function(built) {
  if (is.null(built)) {
    return(NULL)
  }

  config <- list()

  # Extract X-axis format
  x_format <- extract_axis_format(built, "x")
  if (!is.null(x_format)) {
    config$x <- x_format
  }

  # Extract Y-axis format
  y_format <- extract_axis_format(built, "y")
  if (!is.null(y_format)) {
    config$y <- y_format
  }

  if (length(config) == 0) {
    return(NULL)
  }

  config
}

#' Extract Format Configuration for a Single Axis
#'
#' Extracts formatting configuration by inspecting the closure environment
#' of scales label functions (e.g., scales::label_dollar, scales::label_percent).
#'
#' @param built A built ggplot2 object
#' @param axis Either "x" or "y"
#' @return Format configuration list or NULL
#' @keywords internal
extract_axis_format <- function(built, axis = "x") {
  # Get the appropriate scale
  scale <- tryCatch(
    {
      if (axis == "x") {
        built$layout$panel_scales_x[[1]]
      } else if (axis == "y") {
        built$layout$panel_scales_y[[1]]
      } else {
        NULL
      }
    },
    error = function(e) NULL
  )

  if (is.null(scale)) {
    return(NULL)
  }

  # Get the labels function (may be ggproto_method)
  labels_func <- scale$labels

  if (is.null(labels_func) || !is.function(labels_func)) {
    return(NULL)
  }

  # Get the original function if wrapped in ggproto_method
  func_to_inspect <- labels_func
  labels_env <- tryCatch(environment(labels_func), error = function(e) NULL)
  if (!is.null(labels_env) && "f" %in% ls(labels_env)) {
    original_func <- tryCatch(get("f", labels_env), error = function(e) NULL)
    if (!is.null(original_func)) {
      func_to_inspect <- original_func
    }
  }

  # Extract format config from scales closure
  extract_from_scales_closure(func_to_inspect)
}

#' Extract Format Configuration from scales Package Closure
#'
#' Inspects the closure environment of a scales label function to extract
#' formatting parameters. This allows users to use scales:: functions directly
#' without needing maidr:: wrappers.
#'
#' @param label_func A label function (e.g., from scales::label_dollar)
#' @return Format configuration list or NULL
#' @keywords internal
extract_from_scales_closure <- function(label_func) {
  if (!is.function(label_func)) {
    return(NULL)
  }

  # Get the function's closure environment
  env <- tryCatch(environment(label_func), error = function(e) NULL)
  if (is.null(env)) {
    return(NULL)
  }

  # Helper to safely get a variable from environment
  safe_get <- function(name) {
    tryCatch(
      if (exists(name, envir = env, inherits = FALSE)) {
        get(name, envir = env)
      } else {
        NULL
      },
      error = function(e) NULL
    )
  }

  # Extract key parameters from closure
  prefix <- safe_get("prefix")
  suffix <- safe_get("suffix")
  accuracy <- safe_get("accuracy")
  digits <- safe_get("digits")
  scale <- safe_get("scale")

  # Detect format type based on closure contents
  format_type <- detect_scales_format_type(prefix, suffix, digits, scale, accuracy)

  if (is.null(format_type)) {
    return(NULL)
  }

  # Build format config based on detected type
  build_format_config(format_type, prefix, suffix, accuracy, digits)
}

#' Detect Format Type from scales Closure Parameters
#'
#' @param prefix Prefix string from closure
#' @param suffix Suffix string from closure
#' @param digits Digits parameter (only in label_scientific)
#' @param scale Scale parameter
#' @param accuracy Accuracy parameter
#' @return Format type string or NULL
#' @keywords internal
detect_scales_format_type <- function(prefix, suffix, digits, scale, accuracy) {
  # Scientific: only label_scientific has "digits" parameter
  if (!is.null(digits)) {
    return("scientific")
  }

  # Percent: suffix is "%"
  if (!is.null(suffix) && suffix == "%") {
    return("percent")
  }

  # Currency: common currency symbols as prefix
  currency_symbols <- c("$", "\u20ac", "\u00a3", "\u00a5", "\u20b9",
                        "\u20a9", "\u20bd", "\u20aa", "\u20b1", "\u0e3f")
  if (!is.null(prefix) && (prefix %in% currency_symbols ||
      grepl("^[A-Z]{0,2}\\$", prefix))) {
    return("currency")
  }

  # Number: has accuracy or scale parameters (from label_number, label_comma)
  if (!is.null(accuracy) || !is.null(scale)) {
    return("number")
  }

  NULL
}

#' Build Format Config from Detected Type and Parameters
#'
#' @param format_type Detected format type
#' @param prefix Prefix from closure
#' @param suffix Suffix from closure
#' @param accuracy Accuracy from closure
#' @param digits Digits from closure
#' @return Format configuration list
#' @keywords internal
build_format_config <- function(format_type, prefix, suffix, accuracy, digits) {
  config <- list(type = format_type)

  if (format_type == "currency") {
    config$currency <- prefix_to_currency_code(prefix %||% "$")
    config$decimals <- accuracy_to_decimals(accuracy)
    config$locale <- "en-US"
  } else if (format_type == "percent") {
    config$decimals <- accuracy_to_decimals(accuracy)
  } else if (format_type == "scientific") {
    config$decimals <- as.integer(digits %||% 3L)
  } else if (format_type == "number") {
    config$type <- "number"
    config$decimals <- accuracy_to_decimals(accuracy)
    config$locale <- "en-US"
  }

  config
}

# ============================================================================
# Conversion Utilities
# ============================================================================

#' Convert Accuracy to Decimal Places
#'
#' Converts the scales package \code{accuracy} parameter to a decimal count.
#' For example, accuracy = 0.01 becomes decimals = 2.
#'
#' @param accuracy The accuracy value (e.g., 0.01 for 2 decimal places)
#' @return Integer number of decimal places
#' @keywords internal
accuracy_to_decimals <- function(accuracy) {
  if (is.null(accuracy)) {
    return(2L) # Default to 2 decimal places

  }

  if (accuracy >= 1) {
    return(0L)
  }

  # Calculate decimal places from accuracy
  # 0.1 -> 1, 0.01 -> 2, 0.001 -> 3, etc.
  decimals <- -floor(log10(accuracy))
  as.integer(max(0, decimals))
}

#' Convert Currency Prefix to ISO 4217 Code
#'
#' Maps common currency symbols to their ISO 4217 codes for use in
#' JavaScript's Intl.NumberFormat.
#'
#' @param prefix Currency symbol (e.g., "$", "\u20ac", "\u00a3")
#' @return ISO 4217 currency code (e.g., "USD", "EUR", "GBP")
#' @keywords internal
prefix_to_currency_code <- function(prefix) {
  if (is.null(prefix) || prefix == "") {
    return("USD")
  }

  # Common currency mappings
  currency_map <- list(
    "$" = "USD",
    "\u20ac" = "EUR", # Euro sign
    "\u00a3" = "GBP", # Pound sign
    "\u00a5" = "JPY", # Yen sign
    "\u20b9" = "INR", # Indian Rupee sign
    "\u20a9" = "KRW", # Korean Won sign
    "\u20bd" = "RUB", # Russian Ruble sign
    "R$" = "BRL", # Brazilian Real
    "CHF" = "CHF", # Swiss Franc
    "C$" = "CAD", # Canadian Dollar
    "A$" = "AUD", # Australian Dollar
    "NZ$" = "NZD", # New Zealand Dollar
    "HK$" = "HKD", # Hong Kong Dollar
    "S$" = "SGD", # Singapore Dollar
    "\u20aa" = "ILS", # Israeli Shekel sign
    "\u20b1" = "PHP", # Philippine Peso sign
    "\u0e3f" = "THB", # Thai Baht sign
    "kr" = "SEK", # Swedish Krona (also NOK, DKK)
    "z\u0142" = "PLN" # Polish Zloty
  )

  # Return mapped code or the prefix itself as fallback
  if (prefix %in% names(currency_map)) {
    return(currency_map[[prefix]])
  }

  # If prefix looks like an ISO code (3 uppercase letters), use it directly
  if (grepl("^[A-Z]{3}$", prefix)) {
    return(prefix)
  }

  # Default fallback
  "USD"
}

#' Convert R Date Format to Intl.DateTimeFormat Options
#'
#' Converts R strftime format strings to JavaScript Intl.DateTimeFormat options.
#'
#' @param format R date format string (e.g., "\%Y-\%m-\%d")
#' @return List of Intl.DateTimeFormat options
#' @keywords internal
r_date_format_to_intl_options <- function(format) {
  if (is.null(format)) {
    return(list(year = "numeric", month = "2-digit", day = "2-digit"))
  }

  options <- list()

  # Year formats
  if (grepl("%Y", format)) {
    options$year <- "numeric"
  } else if (grepl("%y", format)) {
    options$year <- "2-digit"
  }

  # Month formats
  if (grepl("%B", format)) {
    options$month <- "long"
  } else if (grepl("%b", format)) {
    options$month <- "short"
  } else if (grepl("%m", format)) {
    options$month <- "2-digit"
  }


  # Day formats
  if (grepl("%d", format)) {
    options$day <- "2-digit"
  } else if (grepl("%e", format)) {
    options$day <- "numeric"
  }

  # Weekday formats
  if (grepl("%A", format)) {
    options$weekday <- "long"
  } else if (grepl("%a", format)) {
    options$weekday <- "short"
  }

  # Time formats
  if (grepl("%H", format) || grepl("%I", format)) {
    options$hour <- "2-digit"
  }
  if (grepl("%M", format)) {
    options$minute <- "2-digit"
  }
  if (grepl("%S", format)) {
    options$second <- "2-digit"
  }

  # If no options matched, provide defaults

  if (length(options) == 0) {
    options <- list(year = "numeric", month = "2-digit", day = "2-digit")
  }

  options
}

#' Convert R Date Format to JavaScript Function
#'
#' Creates a JavaScript function string that formats dates according to
#' an R strftime format string. Used for complex date formats that cannot
#' be represented by Intl.DateTimeFormat options alone.
#'
#' @param format R date format string
#' @param tz Timezone
#' @return JavaScript function body string
#' @keywords internal
r_date_format_to_js_function <- function(format, tz = "UTC") {
  # For simple formats, return NULL (use dateOptions instead)
  # For complex formats, generate a JS function

  # Check if format can be handled by Intl.DateTimeFormat
  simple_formats <- c("%Y-%m-%d", "%Y/%m/%d", "%m/%d/%Y", "%d/%m/%Y",
                      "%b %d, %Y", "%B %d, %Y", "%Y", "%b %Y", "%B %Y")

  if (format %in% simple_formats) {
    return(NULL)
  }

  # For complex formats, create a JS function
  # This is a simplified implementation - may need expansion
  sprintf(
    "var d = new Date(value); return d.toLocaleDateString('en-US', %s);",
    jsonlite::toJSON(r_date_format_to_intl_options(format), auto_unbox = TRUE)
  )
}

# ============================================================================
# Null-coalescing operator (if not already defined)
# ============================================================================

#' @keywords internal
`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}
