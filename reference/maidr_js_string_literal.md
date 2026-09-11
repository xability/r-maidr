# Encode a string as a JavaScript literal safe inside a `<script>` element

JSON is a subset of JavaScript, so `jsonlite` does the quoting. It
leaves `/` alone, though, and an HTML parser ends the surrounding
`<script>` at the first `</` it sees whatever the JavaScript around it
says, so that sequence is escaped too.

## Usage

``` r
maidr_js_string_literal(x)
```

## Arguments

- x:

  A single string

## Value

The quoted literal
