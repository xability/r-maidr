#' Register JS/CSS dependencies for maidr from CDN
#'
#' Internal function to create HTML dependencies for MAIDR JavaScript and CSS files.
#'
#' @return A list of htmlDependency objects for maidr.js and maidr_style.css
#' @keywords internal
maidr_html_dependencies <- function() {
  js_dep <- htmltools::htmlDependency(
    name = "maidr-js",
    version = "1.0.0",
    src = c(href = "https://cdn.jsdelivr.net/npm/maidr@latest/dist/"),
    script = "maidr.js"
  )
  css_dep <- htmltools::htmlDependency(
    name = "maidr-css",
    version = "1.0.0",
    src = c(href = "https://cdn.jsdelivr.net/npm/maidr@latest/dist/"),
    stylesheet = "maidr_style.css"
  )

  list(js_dep, css_dep)
}
