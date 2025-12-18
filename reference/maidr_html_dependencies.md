# Register JS/CSS dependencies for maidr with auto-detection

Creates HTML dependencies for MAIDR JavaScript and CSS files.
Automatically detects internet availability: - If internet is available:
uses CDN (smaller HTML, better caching) - If offline: uses local bundled
files (works without internet)

## Usage

``` r
maidr_html_dependencies()
```

## Value

A list containing one htmlDependency object
