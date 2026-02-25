# Disable MAIDR Plot Interception

Disables automatic MAIDR rendering and restores normal plot behavior.
After calling this, Base R plots display in the standard graphics window
and ggplot2 objects render with the default ggplot2 method.

## Usage

``` r
maidr_off()
```

## Value

Invisible TRUE on success

## See also

\[maidr_on()\] to enable MAIDR rendering
