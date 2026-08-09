# Serialize maidr_data and set it as the SVG root's maidr-data attribute

Mutates `svg_doc` in place.

## Usage

``` r
set_maidr_data_attr(svg_doc, maidr_data)
```

## Arguments

- svg_doc:

  Parsed SVG document (xml2)

- maidr_data:

  The maidr-data structure

## Value

NULL (invisible)
