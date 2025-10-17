linters <- lintr::linters_with_defaults(
  object_name_linter = NULL,  # Disabled for R6 classes (use PascalCase)
  return_linter = NULL,       # Disabled to allow explicit returns
  object_usage_linter = NULL, # Disabled for global functions
  line_length_linter = lintr::line_length_linter(100L),
  object_length_linter = NULL # Disabled for long functions
)

exclusions <- list(
  "inst/",
  "man/",
  "RcppExports.R"
)

