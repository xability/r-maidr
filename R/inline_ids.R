# Page-unique ids for a maidr SVG that is inlined into an HTML page.
#
# In an iframe every chart has a document of its own. Inlined into a knitr
# page, the charts share one: maidr.js resolves a layer's selectors against
# the whole page, `url(#..)` and `href="#.."` resolve to the first element on
# the page with that id, and Base R and lattice charts -- and ggplot2 charts
# drawn in different R sessions -- reuse the same ids. A second Base R
# barplot on a page then highlights nothing, and a gradient chart can paint
# with another chart's gradient.
#
# `inline_prefix_svg_ids()` gives every id of one chart a prefix no other
# chart on the page has, and rewrites everything that points at an id: the
# references inside the SVG, the selectors in its maidr-data, and the figure
# id maidr.js derives its own DOM ids from. The rewrite only ever inserts the
# prefix. Deleting it gives the chart back unchanged, which the tests check
# on real charts, and replacing it with another prefix re-keys the chart in
# one fixed-string substitution.

#' A Prefix for the Ids of One Chart Inlined into a Page
#'
#' Unique across the R sessions whose output one page can merge (bookdown's
#' `new_session`, the knitr cache, child documents). Like
#' [generate_unique_id()] it is built from the time in milliseconds, a
#' per-session counter and the process id, so it never draws on the user's
#' random number stream.
#'
#' The shape is fixed: `m`, the three numbers in base 36 at widths of 9, 6
#' and 5 digits, and `-`. The fixed widths keep the joined fields unambiguous
#' without separators, and every prefix the same length, so no prefix is the
#' start of another and `[id^='<prefix>...']` cannot reach into another
#' chart. A separator would also split the prefix into tokens, and maidr.js's
#' tactile view drops every shape whose id holds a token naming axis
#' furniture (`axis`, `grid`, `text`, `tick`, ...): process id 1376804 is
#' `tick` in base 36. One token starting with `m` can never be such a word.
#'
#' @return A string such as `"m0musl8x2k00002h00ahl-"`.
#' @keywords internal
inline_id_prefix <- function() {
  .maidr_id_counter$value <- .maidr_id_counter$value + 1L
  ms <- floor(unclass(Sys.time()) * 1000)
  paste0(
    "m",
    base36_fixed(ms, 9L),
    base36_fixed(.maidr_id_counter$value, 6L),
    base36_fixed(Sys.getpid(), 5L),
    "-"
  )
}

#' A Whole Number in Base 36 at a Fixed Width
#'
#' Zero-padded on the left. A number too large for the width keeps its low
#' digits, so the width never changes: the milliseconds wrap in the year 5188
#' and a process id only past 60 million.
#'
#' @param n A non-negative whole number; a double holds the milliseconds
#'   since 1970 exactly.
#' @param width The number of digits.
#' @return A string of `width` characters from `0-9a-z`.
#' @keywords internal
#' @noRd
base36_fixed <- function(n, width) {
  digits <- c(0:9, letters)
  n <- floor(n) %% 36^width
  out <- character(width)
  for (i in rev(seq_len(width))) {
    out[i] <- digits[n %% 36 + 1]
    n <- n %/% 36
  }
  paste(out, collapse = "")
}

#' Check a Prefix Can Be Given to a Chart's Ids
#'
#' The rewrite inserts the prefix into ids, CSS selectors and JSON strings
#' without escaping it, so it is held to the shape `inline_id_prefix()`
#' makes: `m`, lowercase letters and digits, and one final `-`. `maidr-` is
#' refused because maidr.js reads `g[id^="maidr-"]` across the whole page.
#'
#' @param prefix The prefix to check.
#' @return `NULL`, invisibly; an error when the prefix has another shape.
#' @keywords internal
#' @noRd
check_inline_prefix <- function(prefix) {
  ok <- is.character(prefix) && length(prefix) == 1L && !is.na(prefix) &&
    grepl("^m[a-z0-9]+-$", prefix) && prefix != "maidr-"
  if (!ok) {
    stop(
      "`prefix` must be one string of `m`, lowercase letters and digits, ",
      "and a final `-`, other than `maidr-`.",
      call. = FALSE
    )
  }
  invisible(NULL)
}

#' Refuse a Chart the Id Rewrite Cannot Vouch For
#'
#' Signals an error of class `maidr_inline_unsupported`. A chart refused
#' here is not inlined half-rewritten; the caller keeps it on the iframe
#' path, where it has a document of its own.
#'
#' @param fmt A [sprintf()] format for the message.
#' @param ... Values for `fmt`.
#' @return Does not return.
#' @keywords internal
#' @noRd
inline_refuse <- function(fmt, ...) {
  rlang::abort(
    paste("Cannot inline this chart:", sprintf(fmt, ...)),
    class = "maidr_inline_unsupported",
    call = NULL
  )
}

#' Prefix Every Id of One maidr SVG, and Everything That Refers to One
#'
#' The SVG is read with xml2 rather than edited as text, so text content is
#' never touched: libxml2 leaves `"` unescaped in text, and a chart title can
#' read `id="clip.1" url(#clip.1)` literally. The maidr-data JSON is edited
#' in place rather than parsed and written again, so no data value is
#' re-serialized; only the selectors and the figure id change.
#'
#' What is rewritten:
#' * every `id` attribute;
#' * every `url(#X)` in any attribute but `maidr-data`, quoted or not, and
#'   every `href` or `xlink:href` of `#X`, when `X` is an id of this SVG;
#' * every id in an ARIA reference list (none are emitted today);
#' * every selector string under a `selectors` or `selector` key of the
#'   maidr-data JSON, at any depth;
#' * the JSON figure id (the top-level `id`), which maidr.js derives the ids
#'   of the article and figure it wraps the chart in from.
#'
#' Subplot and layer ids never reach the DOM and are left alone.
#'
#' @param svg One `<svg>` element carrying a `maidr-data` attribute, as
#'   `create_maidr_html(plot, shiny = TRUE)` returns it: a string, an
#'   `htmltools::HTML` string or a character vector of lines, with or without
#'   an `<?xml?>` prolog.
#' @param prefix The chart's prefix, from `inline_id_prefix()`.
#' @return The SVG as one string, without the prolog. A chart this function
#'   cannot fully scope -- not one well-formed SVG with valid maidr-data, a
#'   `<style>`, `<script>` or `<foreignObject>` in it, or a selector outside
#'   the forms the package builds -- is refused with an error of class
#'   `maidr_inline_unsupported`.
#' @keywords internal
inline_prefix_svg_ids <- function(svg, prefix) {
  inline_svg_markup(inline_prefix_svg_document(svg, prefix))
}

#' Prefix Every Id of One maidr SVG, Keeping the Parsed Document
#'
#' What `inline_prefix_svg_ids()` does, returning the xml2 document rather
#' than its markup, for a caller that sets attributes of its own on the
#' `<svg>` before writing it out with `inline_svg_markup()`: the knitr
#' emitter names the chart and moves its maidr-data aside.
#'
#' @param svg,prefix As for `inline_prefix_svg_ids()`.
#' @return The SVG document, an `xml_document`.
#' @keywords internal
#' @noRd
inline_prefix_svg_document <- function(svg, prefix) {
  check_inline_prefix(prefix)
  text <- paste(as.character(svg), collapse = "\n")
  # read_xml() takes a string without `<` for a file path or a URL.
  if (!grepl("<", text, fixed = TRUE)) {
    inline_refuse("it is not SVG markup.")
  }
  # HUGE because a large chart's maidr-data is longer than libxml2's default
  # limit on one attribute value.
  doc <- tryCatch(
    xml2::read_xml(text, options = c("NOBLANKS", "HUGE")),
    error = function(e) {
      inline_refuse("it is not well-formed XML (%s).", conditionMessage(e))
    }
  )
  root <- xml2::xml_root(doc)
  if (!identical(xml2::xml_name(root), "svg")) {
    inline_refuse("its root element is <%s>, not <svg>.", xml2::xml_name(root))
  }
  json <- xml2::xml_attr(root, "maidr-data")
  if (is.na(json)) {
    inline_refuse("the <svg> carries no maidr-data.")
  }
  if (!isTRUE(jsonlite::validate(json)) || !startsWith(trimws(json, "left"), "{")) {
    inline_refuse("its maidr-data is not a JSON object.")
  }
  # A <style> in an inline SVG styles the whole page, and a <script> or
  # <foreignObject> can hold ids and selectors this rewrite does not read.
  leaky <- xml2::xml_find_all(
    doc,
    "//*[local-name() = 'style' or local-name() = 'script' or local-name() = 'foreignObject']"
  )
  if (length(leaky) > 0L) {
    inline_refuse("it holds a <%s> element.", xml2::xml_name(leaky[[1L]]))
  }

  id_nodes <- xml2::xml_find_all(doc, "//*[@id]")
  ids <- xml2::xml_attr(id_nodes, "id")
  if (length(ids) > 0L) {
    xml2::xml_attr(id_nodes, "id") <- paste0(prefix, ids)
  }

  prefix_url_references(doc, prefix, ids)
  prefix_href_references(doc, prefix, ids)
  prefix_aria_references(doc, prefix, ids)

  xml2::xml_attr(root, "maidr-data") <- prefix_maidr_data_ids(json, prefix)

  doc
}

#' The Markup of an SVG Document, Without the Prolog
#'
#' @param doc An `xml_document` whose root is the `<svg>`.
#' @return The SVG as one string.
#' @keywords internal
#' @noRd
inline_svg_markup <- function(doc) {
  # `no_declaration` drops the prolog; the sub() keeps it dropped whatever
  # the xml2 release.
  out <- as.character(doc, options = c("format", "no_declaration"))
  sub("\\s+$", "", sub("^\\s*<\\?xml[^>]*\\?>\\s*", "", out))
}

#' Point Every `url(#X)` at the Prefixed Id
#'
#' In any attribute but `maidr-data`, whose data labels may read `url(#..)`:
#' `clip-path`, `fill`, `mask`, `filter`, `style`, ... The attributes are
#' grouped by name so each name is read and written for all its elements at
#' once; a chart can carry thousands of `clip-path`s.
#'
#' @param doc The SVG document, modified in place.
#' @param prefix The chart's prefix.
#' @param ids The SVG's ids before prefixing.
#' @return `NULL`, invisibly.
#' @keywords internal
#' @noRd
prefix_url_references <- function(doc, prefix, ids) {
  holders <- xml2::xml_find_all(
    doc, "//@*[name() != 'maidr-data' and contains(., 'url(')]"
  )
  attribute_names <- unique(xml2::xml_find_chr(holders, "name()"))
  # A namespaced attribute holding url() is never emitted; refuse it rather
  # than leave a reference this rewrite did not read.
  namespaced <- grepl(":", attribute_names, fixed = TRUE)
  if (any(namespaced)) {
    inline_refuse("its attribute %s holds a url().", attribute_names[namespaced][1L])
  }
  for (name in attribute_names) {
    elements <- xml2::xml_find_all(
      doc, sprintf("//*[@%s[contains(., 'url(')]]", name)
    )
    old <- xml2::xml_attr(elements, name)
    new <- prefix_url_values(old, prefix, ids)
    changed <- old != new
    if (any(changed)) {
      xml2::xml_attr(elements[changed], name) <- new[changed]
    }
  }
  invisible(NULL)
}

#' Prefix the Fragment of Each `url(#X)` That Names an Id of the Chart
#'
#' Reads the fragment of a url() whether it is quoted with `'`, with `"` or
#' not at all, and with or without spaces inside the parentheses. A fragment
#' naming no id of the chart is left as it is.
#'
#' @param values Attribute values.
#' @param prefix The chart's prefix.
#' @param ids The SVG's ids before prefixing.
#' @return `values`, rewritten.
#' @keywords internal
#' @noRd
prefix_url_values <- function(values, prefix, ids) {
  pattern <- "url\\(\\s*(['\"]?)\\s*#([^)'\"\\s]+)\\s*\\1\\s*\\)"
  found <- gregexpr(pattern, values, perl = TRUE)
  refs <- regmatches(values, found)
  flat <- unlist(refs, use.names = FALSE)
  if (length(flat) == 0L) {
    return(values)
  }
  own <- sub(pattern, "\\2", flat, perl = TRUE) %in% ids
  flat[own] <- sub("#", paste0("#", prefix), flat[own], fixed = TRUE)
  owner <- factor(rep(seq_along(refs), lengths(refs)), levels = seq_along(refs))
  regmatches(values, found) <- unname(split(flat, owner))
  values
}

#' Point Every `href` and `xlink:href` of `#X` at the Prefixed Id
#'
#' @param doc The SVG document, modified in place.
#' @param prefix The chart's prefix.
#' @param ids The SVG's ids before prefixing.
#' @return `NULL`, invisibly.
#' @keywords internal
#' @noRd
prefix_href_references <- function(doc, prefix, ids) {
  # Bound to the namespace rather than to the prefix the SVG declares.
  ns <- c(xlink = "http://www.w3.org/1999/xlink")
  for (attribute in c("href", "xlink:href")) {
    elements <- xml2::xml_find_all(
      doc, sprintf("//*[starts-with(@%s, '#')]", attribute), ns
    )
    if (length(elements) == 0L) {
      next
    }
    target <- substring(xml2::xml_attr(elements, attribute, ns = ns), 2L)
    own <- target %in% ids
    if (any(own)) {
      xml2::xml_attr(elements[own], attribute, ns = ns) <-
        paste0("#", prefix, target[own])
    }
  }
  invisible(NULL)
}

#' Prefix the Chart's Own Ids in Every ARIA Reference List
#'
#' None are emitted today; keeping them right costs a lookup per attribute.
#'
#' @param doc The SVG document, modified in place.
#' @param prefix The chart's prefix.
#' @param ids The SVG's ids before prefixing.
#' @return `NULL`, invisibly.
#' @keywords internal
#' @noRd
prefix_aria_references <- function(doc, prefix, ids) {
  attributes <- c(
    "aria-activedescendant", "aria-controls", "aria-describedby",
    "aria-details", "aria-errormessage", "aria-flowto", "aria-labelledby",
    "aria-owns"
  )
  for (attribute in attributes) {
    elements <- xml2::xml_find_all(doc, sprintf("//*[@%s]", attribute))
    if (length(elements) == 0L) {
      next
    }
    lists <- strsplit(xml2::xml_attr(elements, attribute), "\\s+")
    xml2::xml_attr(elements, attribute) <- vapply(lists, function(refs) {
      refs <- refs[nzchar(refs)]
      paste(ifelse(refs %in% ids, paste0(prefix, refs), refs), collapse = " ")
    }, character(1))
  }
  invisible(NULL)
}

#' Prefix the Selectors and the Figure Id in maidr-data JSON, in Place
#'
#' The JSON is never parsed and written again as a whole. Its strings and
#' brackets are located, the value of every `selectors` or `selector` key is
#' found by its brackets, and only the string tokens inside it -- and the
#' top-level `id` -- are replaced. Every other byte stays as the producer
#' wrote it.
#'
#' A key pattern such as `[{,]\s*"selectors"\s*:` cannot match inside a JSON
#' string, where every `"` is escaped, so every match is a real key. Keys
#' come from the package's code, never from data, so a data column named
#' `selectors` cannot reach this.
#'
#' @param json The maidr-data, a valid JSON object.
#' @param prefix The chart's prefix.
#' @return The JSON, rewritten.
#' @keywords internal
#' @noRd
prefix_maidr_data_ids <- function(json, prefix) {
  # Work on bytes: on a string holding any non-ASCII character, substring()
  # walks from the start for every range, which is quadratic in a chart
  # carrying thousands of selectors. Every position used below is the byte
  # position of an ASCII delimiter, so every piece cut out is valid UTF-8.
  Encoding(json) <- "bytes"
  as_utf8 <- function(x) {
    Encoding(x) <- "UTF-8"
    x
  }
  lex <- json_lexical_map(json)
  if (length(lex$open) == 0L) {
    return(as_utf8(json))
  }

  # The figure id: the top-level `id` key, at bracket depth 1.
  id_key <- gregexpr('[{,]\\s*"id"\\s*:\\s*"', json, perl = TRUE, useBytes = TRUE)[[1L]]
  id_at <- integer()
  if (id_key[1L] != -1L) {
    depth <- lex$depth[findInterval(as.integer(id_key), lex$brackets)]
    top <- which(depth == 1L)
    if (length(top) > 0L) {
      id_at <- as.integer(id_key)[top[1L]] + attr(id_key, "match.length")[top[1L]] - 1L
    }
  }

  token_open <- json_selector_tokens(json, lex)
  token_close <- lex$close[match(token_open, lex$open)]
  replacement <- character()
  if (length(token_open) > 0L) {
    encoded <- as_utf8(substring(json, token_open, token_close))
    replacement <- encoded
    decoded <- unlist(jsonlite::parse_json(paste0("[", paste(encoded, collapse = ","), "]")))
    rewritten <- prefix_selectors(decoded, prefix)
    changed <- rewritten != decoded
    replacement[changed] <- json_encode_like(
      rewritten[changed], decoded[changed], encoded[changed]
    )
  }

  # The figure id needs no re-encoding: the prefix is plain ASCII.
  if (length(id_at) > 0L) {
    id_close <- lex$close[match(id_at, lex$open)]
    token_open <- c(token_open, id_at)
    token_close <- c(token_close, id_close)
    replacement <- c(
      replacement,
      paste0('"', prefix, as_utf8(substring(json, id_at + 1L, id_close)))
    )
  }
  if (length(token_open) == 0L) {
    return(as_utf8(json))
  }

  # Interleave the text between the tokens with the rewritten tokens.
  by_position <- order(token_open)
  token_open <- token_open[by_position]
  token_close <- token_close[by_position]
  plain <- as_utf8(substring(
    json,
    c(1L, token_close + 1L),
    c(token_open - 1L, nchar(json, type = "bytes"))
  ))
  pieces <- character(2L * length(token_open) + 1L)
  pieces[c(TRUE, FALSE)] <- plain
  pieces[c(FALSE, TRUE)] <- replacement[by_position]
  paste(pieces, collapse = "")
}

#' Where the Strings and Brackets of a JSON Text Are
#'
#' @param json Valid JSON, marked as `"bytes"`.
#' @return A list: `open` and `close`, the positions of the quotes that open
#'   and close each string; `brackets`, the positions of the brackets
#'   outside strings; and `depth`, the nesting depth just after each of
#'   those brackets.
#' @keywords internal
#' @noRd
json_lexical_map <- function(json) {
  # A quote preceded by an even number of backslashes delimits a string.
  runs <- gregexpr('\\\\*"', json, perl = TRUE, useBytes = TRUE)[[1L]]
  if (runs[1L] == -1L) {
    return(list(open = integer(), close = integer(), brackets = integer(), depth = integer()))
  }
  run_length <- attr(runs, "match.length")
  quotes <- (as.integer(runs) + run_length - 1L)[(run_length - 1L) %% 2L == 0L]
  open <- quotes[c(TRUE, FALSE)]
  close <- quotes[c(FALSE, TRUE)]

  brackets <- as.integer(gregexpr("[][{}]", json, useBytes = TRUE)[[1L]])
  brackets <- brackets[brackets > 0L]
  inside <- findInterval(brackets, open)
  brackets <- brackets[!(inside > 0L & brackets < close[pmax(inside, 1L)])]
  opens <- substring(json, brackets, brackets) %in% c("[", "{")
  list(
    open = open,
    close = close,
    brackets = brackets,
    depth = cumsum(ifelse(opens, 1L, -1L))
  )
}

#' The Selector Strings Under Every `selectors` or `selector` Key
#'
#' A value is a string, an array or an object (a box plot's named
#' selectors), nested to any depth; `null` and other scalars hold no
#' selector. Object keys inside a value are not selectors and are skipped.
#'
#' @param json Valid JSON, marked as `"bytes"`.
#' @param lex `json_lexical_map(json)`.
#' @return The positions of the opening quotes of those strings.
#' @keywords internal
#' @noRd
json_selector_tokens <- function(json, lex) {
  keys <- gregexpr('[{,]\\s*"selectors?"\\s*:\\s*', json, perl = TRUE, useBytes = TRUE)[[1L]]
  if (keys[1L] == -1L) {
    return(integer())
  }
  starts <- as.integer(keys) + attr(keys, "match.length")
  first <- substring(json, starts, starts)
  ends <- starts - 1L
  is_string <- first == '"'
  ends[is_string] <- lex$close[match(starts[is_string], lex$open)]
  for (i in which(first %in% c("[", "{"))) {
    j <- match(starts[i], lex$brackets)
    later <- which(lex$depth[-seq_len(j)] == lex$depth[j] - 1L)
    ends[i] <- lex$brackets[j + later[1L]]
  }
  keep <- ends >= starts
  starts <- starts[keep]
  ends <- ends[keep]
  if (length(starts) == 0L) {
    return(integer())
  }
  # Spans are nested or disjoint; a key inside another key's value is
  # covered by the outer one.
  outer <- starts > c(0L, cummax(ends)[-length(ends)])
  starts <- starts[outer]
  ends <- ends[outer]

  span <- findInterval(lex$open, starts)
  inside <- span > 0L & lex$close <= ends[pmax(span, 1L)]
  if (!any(inside)) {
    return(integer())
  }
  open <- lex$open[inside]
  close <- lex$close[inside]
  # jsonlite writes no whitespace between a key and its colon; a key that
  # had more than this window would be read as a selector, and refused.
  is_key <- grepl("^\\s*:", substring(json, close + 1L, close + 64L), useBytes = TRUE)
  open[!is_key]
}

#' Encode Strings the Way the Producer Encoded Their Originals
#'
#' The rewritten strings differ from the originals only by inserted
#' prefixes, so encoding them as their originals were encoded keeps every
#' other byte. Escaping `\` and `"` is all jsonlite does to a string without
#' control characters; that is checked against each original's encoding, and
#' a string it does not reproduce is encoded by jsonlite itself.
#'
#' @param x The rewritten strings.
#' @param original The strings before rewriting.
#' @param original_encoded How the producer encoded `original`, quotes
#'   included.
#' @return `x`, encoded as JSON strings.
#' @keywords internal
#' @noRd
json_encode_like <- function(x, original, original_encoded) {
  escape <- function(s) {
    paste0('"', gsub('"', '\\"', gsub("\\", "\\\\", s, fixed = TRUE), fixed = TRUE), '"')
  }
  out <- escape(x)
  differs <- escape(original) != original_encoded
  out[differs] <- vapply(x[differs], function(s) {
    as.character(jsonlite::toJSON(s, auto_unbox = TRUE))
  }, character(1), USE.NAMES = FALSE)
  out
}

# One CSS token per capture group, and the group's number is the token's kind
# in `prefix_selectors()`: 1 a comma, 2 a combinator, 3 descendant
# whitespace, 4 an id (with CSS escapes), 5 an attribute test, 6 a structural
# pseudo-class with an argument, 7 one without, 8 a type or `*`. Anything
# else -- a class, a pseudo-element, :not(), :is(), :has(), a namespace --
# leaves a gap, and the selector is refused.
inline_css_token_pattern <- paste0(
  "(\\s*,\\s*)",
  "|(\\s*[>+~]\\s*)",
  "|(\\s+)",
  "|(#(?:[A-Za-z0-9_-]|[^\\x00-\\x7F]|\\\\[0-9A-Fa-f]{1,6}\\s?|\\\\[^\\r\\n\\f0-9A-Fa-f])+)",
  "|(\\[\\s*[A-Za-z_][A-Za-z0-9_-]*\\s*",
  "(?:[~|^$*]?=\\s*(?:'(?:[^'\\\\\\n]|\\\\.)*'|\"(?:[^\"\\\\\\n]|\\\\.)*\"",
  "|-?[A-Za-z_][A-Za-z0-9_-]*)\\s*)?\\])",
  "|(:(?:nth-child|nth-last-child|nth-of-type|nth-last-of-type)\\(\\s*",
  "(?:odd|even|[+-]?\\d*n(?:\\s*[+-]\\s*\\d+)?|[+-]?\\d+)\\s*\\))",
  "|(:(?:first-child|last-child|only-child|first-of-type|last-of-type|only-of-type))",
  "|(\\*|[A-Za-z][A-Za-z0-9_-]*)"
)

#' Prefix the Ids a Vector of CSS Selectors Names
#'
#' Reads only the selector forms the package builds, and refuses (with a
#' `maidr_inline_unsupported` error) anything else rather than guess. Each
#' selector is cut into the tokens of `inline_css_token_pattern`, which must
#' cover it end to end, and then:
#' * `#id` becomes `#<prefix>id`;
#' * `[id=v]`, `[id^=v]` and `[id|=v]` get the prefix at the start of `v`;
#'   `[id*=v]`, `[id$=v]` and `[id~=v]` are refused, since no prefix can scope
#'   a match in the middle or at the end of an id;
#' * a test of `href`, of an ARIA reference or of a value holding `#` is
#'   refused: the rewrite may change such a value, and the test would stop
#'   matching;
#' * every part of a comma list has to name an id, or it would match the
#'   same shapes in every chart on the page.
#'
#' Vectorized over all of a chart's selectors, because a 50 x 50 Base R
#' `image()` carries 2500 of them.
#'
#' @param selectors A character vector of selectors. Empty strings are
#'   returned as they are.
#' @param prefix The chart's prefix.
#' @return `selectors`, rewritten.
#' @keywords internal
#' @noRd
prefix_selectors <- function(selectors, prefix) {
  out <- selectors
  todo <- which(!is.na(selectors) & nzchar(trimws(selectors)))
  if (length(todo) == 0L) {
    return(out)
  }
  unique_selectors <- unique(selectors[todo])
  refuse <- function(i, why = "is not a form the package builds") {
    inline_refuse(
      "its selector %s %s.", encodeString(unique_selectors[i[1L]], quote = "'"), why
    )
  }

  found <- gregexpr(inline_css_token_pattern, unique_selectors, perl = TRUE)
  owner <- rep.int(seq_along(unique_selectors), lengths(found))
  start <- unlist(found, use.names = FALSE)
  len <- unlist(lapply(found, attr, "match.length"), use.names = FALSE)
  if (any(start == -1L)) {
    refuse(owner[start == -1L])
  }
  # The tokens must tile each selector: start at its first character, abut,
  # and end at its last.
  first <- !duplicated(owner)
  last <- !duplicated(owner, fromLast = TRUE)
  gap <- (first & start != 1L) |
    (!first & start != c(0L, (start + len)[-length(start)])) |
    (last & start + len - 1L != nchar(unique_selectors)[owner])
  if (any(gap)) {
    refuse(owner[gap])
  }
  capture <- do.call(rbind, lapply(found, attr, "capture.start"))
  kind <- max.col(capture > 0L, ties.method = "first")
  token <- substring(unique_selectors[owner], start, start + len - 1L)

  scoped <- kind == 4L
  token[scoped] <- paste0("#", prefix, substring(token[scoped], 2L))

  at <- which(kind == 5L)
  if (length(at) > 0L) {
    parts <- do.call(rbind, regmatches(token[at], regexec(
      "^\\[\\s*([A-Za-z_][A-Za-z0-9_-]*)\\s*(?:([~|^$*]?=)\\s*(['\"]?)(.*?)\\3\\s*)?\\]$",
      token[at],
      perl = TRUE
    )))
    name <- tolower(parts[, 2L])
    op <- parts[, 3L]
    on_id <- name == "id" & nzchar(op)
    unscopable <- on_id & !op %in% c("=", "^=", "|=")
    if (any(unscopable)) {
      refuse(
        owner[at][unscopable],
        sprintf("tests [id%s], which matches inside other ids", op[unscopable][1L])
      )
    }
    rewritten_value <- !on_id & nzchar(op) &
      (name == "href" | startsWith(name, "aria-") | grepl("#", parts[, 5L], fixed = TRUE))
    if (any(rewritten_value)) {
      refuse(owner[at][rewritten_value], "tests a value the rewrite changes")
    }
    hit <- at[on_id]
    token[hit] <- sub("(=\\s*['\"]?)", paste0("\\1", prefix), token[hit], perl = TRUE)
    scoped[hit] <- TRUE
  }

  # Every part of a comma list has to hold an id constraint.
  comma <- kind == 1L
  part <- cumsum(comma)
  part <- part - (part - comma)[first][owner]
  body <- !comma
  part_key <- paste(owner, part)[body]
  part_scoped <- tapply(scoped[body], part_key, any)
  scoped_parts <- tabulate(
    owner[body][match(names(part_scoped)[part_scoped], part_key)],
    nbins = length(unique_selectors)
  )
  n_parts <- tabulate(owner[comma], nbins = length(unique_selectors)) + 1L
  unscoped <- which(scoped_parts != n_parts)
  if (length(unscoped) > 0L) {
    refuse(unscoped, "has a part that names no id")
  }

  rewritten <- vapply(split(token, owner), paste, character(1), collapse = "")
  out[todo] <- rewritten[match(selectors[todo], unique_selectors)]
  out
}
