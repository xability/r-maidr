# Get Current MAIDR Fallback Settings

Retrieves the current fallback configuration for MAIDR.

## Usage

``` r
maidr_get_fallback()
```

## Value

A list with the current fallback settings:

- `enabled`: Logical indicating if fallback is enabled

- `format`: Character string of the image format

- `warning`: Logical indicating if warnings are shown

## See also

\[maidr_set_fallback()\] to configure settings

## Examples

``` r
# Get current settings
settings <- maidr_get_fallback()
print(settings)
#> $enabled
#> [1] TRUE
#> 
#> $format
#> [1] "png"
#> 
#> $warning
#> [1] TRUE
#> 
```
