# Get paths to local MAIDR assets

Returns the file paths to the locally bundled MAIDR JavaScript and KaTeX
stylesheet. The stylesheet is `maidr-math.css`, with its base64 web
fonts stripped by `.github/scripts/fetch-maidr-bundle.sh` to keep the
installed package under CRAN's size limit; KaTeX's layout rules are
intact and only the glyphs fall back to system fonts.

## Usage

``` r
maidr_local_assets()
```

## Value

A named list with 'js' and 'math_css' file paths
