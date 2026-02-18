# Configure MAIDR Fallback Behavior

Configure how MAIDR handles unsupported plot types or layers. When
fallback is enabled, unsupported plots are rendered as static images
instead of failing or returning empty data.

## Usage

``` r
maidr_set_fallback(enabled = TRUE, format = "png", warning = TRUE)
```

## Arguments

- enabled:

  Logical. If TRUE (default), unsupported plots fall back to image
  rendering. If FALSE, unsupported layers return empty data.

- format:

  Character. Image format for fallback: "png" (default), "svg", or
  "jpeg".

- warning:

  Logical. If TRUE (default), shows a warning message when falling back
  to image rendering.

## Value

Invisibly returns a list of the previous settings.

## See also

\[maidr_get_fallback()\] to retrieve current settings

## Examples

``` r
# Save current settings and restore on exit
old_settings <- maidr_get_fallback()
on.exit(maidr_set_fallback(
  enabled = old_settings$enabled,
  format = old_settings$format,
  warning = old_settings$warning
))

# Disable fallback (unsupported plots will have empty data)
maidr_set_fallback(enabled = FALSE)

# Use SVG format for fallback images
maidr_set_fallback(format = "svg")

# Disable warning messages
maidr_set_fallback(warning = FALSE)

# Configure multiple options
maidr_set_fallback(enabled = TRUE, format = "png", warning = TRUE)
```
