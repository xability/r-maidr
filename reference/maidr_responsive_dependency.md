# Responsive page CSS dependency for MAIDR HTML output

Returns an htmltools::htmlDependency() whose \`head\` payload injects a
viewport meta tag, a minimal CSS reset, and rules that make the embedded
SVG fill (or proportionally fit) the browser viewport. This is purely a
presentational layer; the SVG content, selectors, viewBox, and embedded
\`maidr-data\` attribute are untouched and the maidr JS frontend behaves
identically. We use a dependency (rather than an inline \`\<style\>\`
tag in the body) so the meta and style land in the document \`\<head\>\`
produced by \`htmltools::save_html()\`.

## Usage

``` r
maidr_responsive_dependency()
```

## Value

A single htmltools::htmlDependency() object
