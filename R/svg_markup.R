#' SVG markup without libxml2
#'
#' Under webR the chart's SVG is finished here, with string operations, rather
#' than with xml2. webR links every package's compiled code into one table of
#' symbols, and its builds of xml2 and of systemfonts (which svglite loads)
#' each carry a libxml2 of their own: whichever loads first supplies the
#' symbols both use. Loaded after systemfonts, xml2 parses the chart with
#' systemfonts' copy, the wasm reads out of bounds and R's worker dies (#380,
#' #388). maidr loads xml2 first when it can ([maidr_webr_load_xml2_first()]),
#' but a session that loaded svglite, systemfonts or textshaping before maidr
#' has already decided it, and nothing R can do afterwards changes which
#' library answers. So `show()` and `save_html()` do not ask libxml2 at all
#' there.
#'
#' What comes out is what the xml2 path writes, byte for byte: the document
#' xml2 would parse (blank text dropped as libxml2's `NOBLANKS` drops it), the
#' same edits, and libxml2's own formatted serialisation (two spaces per
#' level, at most 60; no indentation inside an element that holds text; a
#' childless element as `<name/>`; attributes and text escaped as libxml2
#' escapes them). `test-svg-markup.R` holds the two paths to the same output
#' on real charts, so this cannot drift from xml2 unnoticed.
#'
#' It reads the documents maidr's own export writes, and refuses what those
#' never contain -- a DOCTYPE, CDATA, processing instructions, entities other
#' than XML's five -- rather than guess how libxml2 would have written it.
#'
#' A document is a list of tokens in document order: `kind` (`start`,
#' `empty`, `end`, `text` or `comment`), `name`, and `tok`, which holds a
#' start or empty tag as its canonical `<name attr="value"` (without the
#' closing `>` or `/>`), text already escaped as libxml2 writes it, and a
#' comment as it was.
#'
#' @noRd
NULL

# A comment, CDATA, a declaration or processing instruction, or a tag whose
# quoted attribute values may hold `>`.
svg_markup_token_re <- paste0(
  "(?s)<!--.*?-->|<!\\[CDATA\\[.*?\\]\\]>|<[?!][^>]*+>|",
  "<(?:[^>\"']++|\"[^\"]*+\"|'[^']*+')*+>"
)

# A tag already in the form libxml2 writes it: double quotes, one space
# before each attribute, and nothing in a value that libxml2 would write
# differently.
svg_markup_canonical_tag_re <- paste0(
  "^<[^\\s/>\"'=]+",
  "(?: [^\\s/>\"'=]+=\"(?:[^\"<>&\\t\\n]|&(?:amp|lt|gt|quot|#10|#13|#9);)*\")*",
  "/?>$"
)

#' Stop: the SVG holds something this reader does not handle
#' @noRd
svg_markup_refuse <- function(what) {
  stop("Cannot finish the chart's SVG without libxml2: ", what, call. = FALSE)
}

#' Mark a string as bytes, so substring() indexes it in constant time
#' @noRd
svg_markup_bytes <- function(x) {
  x <- enc2utf8(as.character(x))
  Encoding(x) <- "bytes"
  x
}

#' Escape text content as libxml2 writes it
#' @noRd
svg_markup_escape_text <- function(x) {
  x <- gsub("&", "&amp;", x, fixed = TRUE, useBytes = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE, useBytes = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE, useBytes = TRUE)
  gsub("\r", "&#13;", x, fixed = TRUE, useBytes = TRUE)
}

#' Escape an attribute value as libxml2 writes it
#' @noRd
svg_markup_escape_attr <- function(x) {
  x <- svg_markup_escape_text(x)
  x <- gsub("\"", "&quot;", x, fixed = TRUE, useBytes = TRUE)
  x <- gsub("\n", "&#10;", x, fixed = TRUE, useBytes = TRUE)
  gsub("\t", "&#9;", x, fixed = TRUE, useBytes = TRUE)
}

#' Replace XML's entity and character references with what they stand for
#' @noRd
svg_markup_unescape <- function(x) {
  hit <- grepl("&", x, fixed = TRUE, useBytes = TRUE)
  if (!any(hit)) {
    return(x)
  }
  sub_x <- x[hit]
  found <- gregexpr(
    "&(#[0-9]+|#x[0-9A-Fa-f]+|lt|gt|amp|quot|apos);", sub_x,
    perl = TRUE, useBytes = TRUE
  )
  ampersands <- lengths(regmatches(sub_x, gregexpr("&", sub_x, fixed = TRUE, useBytes = TRUE)))
  matched <- vapply(found, function(m) sum(m > 0L), integer(1))
  if (any(ampersands != matched)) {
    svg_markup_refuse("an entity other than XML's own, or a bare '&'.")
  }
  regmatches(sub_x, found) <- lapply(regmatches(sub_x, found), function(refs) {
    out <- vapply(refs, function(ref) {
      body <- substr(ref, 2L, nchar(ref, type = "bytes") - 1L)
      switch(body,
        lt = "<", gt = ">", amp = "&", quot = "\"", apos = "'",
        {
          code <- if (startsWith(body, "#x")) {
            strtoi(substring(body, 3L), 16L)
          } else {
            strtoi(substring(body, 2L), 10L)
          }
          if (is.na(code) || code == 0L) {
            svg_markup_refuse(paste0("the character reference ", ref, "."))
          }
          intToUtf8(code)
        }
      )
    }, character(1), USE.NAMES = FALSE)
    svg_markup_bytes(out)
  })
  x[hit] <- sub_x
  x
}

#' Read the attributes of a start or empty tag
#'
#' @param tag The tag, from `<` up to (and optionally including) its `>`.
#' @return A named character vector of the values, unescaped.
#' @noRd
svg_markup_tag_attrs <- function(tag) {
  inner <- sub("/?>$", "", tag, useBytes = TRUE)
  inner <- sub("^<[^\\s/>]+", "", inner, perl = TRUE, useBytes = TRUE)
  pattern <- "\\s*([^\\s=/>\"']+)\\s*=\\s*(\"[^\"]*\"|'[^']*')"
  found <- gregexpr(pattern, inner, perl = TRUE, useBytes = TRUE)
  pieces <- regmatches(inner, found)[[1]]
  trimmed <- sub("\\s+$", "", inner, perl = TRUE, useBytes = TRUE)
  if (!identical(paste(pieces, collapse = ""), trimmed)) {
    svg_markup_refuse(paste0("a tag it cannot read: ", substr(tag, 1L, 80L)))
  }
  if (!length(pieces)) {
    return(stats::setNames(character(0), character(0)))
  }
  names <- sub(pattern, "\\1", pieces, perl = TRUE, useBytes = TRUE)
  values <- sub(pattern, "\\2", pieces, perl = TRUE, useBytes = TRUE)
  values <- substr(values, 2L, nchar(values, type = "bytes") - 1L)
  if (anyDuplicated(names)) {
    svg_markup_refuse("an attribute given twice.")
  }
  # Attribute-value normalisation: literal whitespace becomes a space; a
  # character reference keeps the character.
  values <- gsub("[\t\n]", " ", values, useBytes = TRUE)
  stats::setNames(svg_markup_unescape(values), names)
}

#' Write a start tag's head, `<name attr="value"`, as libxml2 does
#'
#' Namespace declarations come first, as libxml2 keeps them apart from the
#' other attributes.
#' @noRd
svg_markup_tag_head <- function(name, attrs) {
  if (!length(attrs)) {
    return(paste0("<", name))
  }
  is_ns <- names(attrs) == "xmlns" | startsWith(names(attrs), "xmlns:")
  attrs <- c(attrs[is_ns], attrs[!is_ns])
  values <- svg_markup_escape_attr(svg_markup_bytes(attrs))
  paste0("<", name, paste0(" ", names(attrs), "=\"", values, "\"", collapse = ""))
}

#' Where each token sits in the tree
#'
#' @param kind The tokens' kinds.
#' @return A list: `level` (depth of each node, the root's being 0; an end
#'   tag has its element's), `match` (an element's other tag; an empty
#'   element's own index) and `parent` (the start tag of the element a node is
#'   in; 0 at the top).
#' @noRd
svg_markup_index <- function(kind) {
  n <- length(kind)
  is_start <- kind == "start"
  is_end <- kind == "end"
  depth <- cumsum(is_start - is_end)
  if (n == 0L || any(depth < 0L) || depth[[n]] != 0L) {
    svg_markup_refuse("its tags do not nest.")
  }
  before <- c(0L, depth[-n])
  level <- ifelse(is_end, depth, before)

  starts <- which(is_start)
  ends <- which(is_end)
  if (length(starts) != length(ends)) {
    svg_markup_refuse("its tags do not nest.")
  }
  # At any one depth, the start and end tags alternate.
  all_tags <- c(starts, ends)
  o <- order(level[all_tags], all_tags)
  sorted <- all_tags[o]
  type <- c(rep(1L, length(starts)), rep(2L, length(ends)))[o]
  if (length(type) && !identical(type, rep(c(1L, 2L), length(starts)))) {
    svg_markup_refuse("its tags do not nest.")
  }
  open <- sorted[type == 1L]
  close <- sorted[type == 2L]
  match <- seq_len(n)
  match[open] <- close
  match[close] <- open

  parent <- integer(n)
  for (l in seq_len(max(level))) {
    at <- which(level == l & !is_end)
    holders <- starts[level[starts] == l - 1L]
    parent[at] <- holders[findInterval(at, holders)]
  }
  parent[ends] <- parent[match[ends]]
  list(level = level, match = match, parent = parent)
}

#' Split a document into tokens: tags, text, comments
#'
#' @param svg_content The document, as lines or one string.
#' @return A list of `kind`, `tok` and the declaration's `version`.
#' @noRd
svg_markup_tokens <- function(svg_content) {
  text <- svg_markup_bytes(paste(svg_content, collapse = "\n"))
  text <- gsub("\r\n", "\n", text, fixed = TRUE, useBytes = TRUE)
  text <- gsub("\r", "\n", text, fixed = TRUE, useBytes = TRUE)

  found <- gregexpr(svg_markup_token_re, text, perl = TRUE, useBytes = TRUE)[[1]]
  if (found[[1]] == -1L) {
    svg_markup_refuse("it holds no element.")
  }
  starts <- as.integer(found)
  ends <- starts + attr(found, "match.length") - 1L
  markup <- substring(text, starts, ends)
  gaps <- substring(text, c(1L, ends + 1L), c(starts - 1L, nchar(text, type = "bytes")))
  if (any(grepl("<", gaps, fixed = TRUE, useBytes = TRUE))) {
    svg_markup_refuse("a '<' that starts no tag.")
  }

  m <- length(markup)
  tok <- c(rbind(gaps[seq_len(m)], markup), gaps[[m + 1L]])
  is_markup <- c(rep(c(FALSE, TRUE), m), FALSE)
  keep <- nzchar(tok)
  tok <- tok[keep]
  is_markup <- is_markup[keep]

  two <- substr(tok, 1L, 2L)
  kind <- rep("text", length(tok))
  kind[is_markup] <- "start"
  kind[is_markup & endsWith(tok, "/>")] <- "empty"
  kind[is_markup & two == "<!"] <- "other"
  kind[is_markup & two == "<?"] <- "pi"
  kind[is_markup & substr(tok, 1L, 4L) == "<!--"] <- "comment"
  kind[is_markup & two == "</"] <- "end"
  if (any(kind == "other")) {
    svg_markup_refuse("a DOCTYPE or CDATA section.")
  }

  # The XML declaration, first if anywhere.
  version <- "1.0"
  if (kind[[1]] == "pi" && grepl("^<\\?xml\\s", tok[[1]], perl = TRUE, useBytes = TRUE)) {
    decl <- tok[[1]]
    if (grepl("standalone", decl, fixed = TRUE)) {
      svg_markup_refuse("a standalone declaration.")
    }
    pattern <- "version\\s*=\\s*[\"']([^\"']*)[\"']"
    v <- regmatches(decl, regexec(pattern, decl, useBytes = TRUE))[[1]]
    if (length(v) == 2L) version <- v[[2]]
    kind <- kind[-1L]
    tok <- tok[-1L]
  }
  if (any(kind == "pi")) {
    svg_markup_refuse("a processing instruction.")
  }
  list(kind = kind, tok = tok, version = version)
}

#' Each element's xml:space, inherited: 1 preserve, 0 default, -1 neither
#' @noRd
svg_markup_space <- function(kind, tok, level, parent) {
  n <- length(kind)
  space <- rep(-1L, n)
  is_open <- kind %in% c("start", "empty")
  spaced <- which(is_open & grepl("xml:space", tok, fixed = TRUE, useBytes = TRUE))
  if (!length(spaced)) {
    return(space)
  }
  own <- rep(NA_integer_, n)
  for (j in spaced) {
    value <- svg_markup_tag_attrs(tok[[j]])["xml:space"]
    if (!is.na(value)) own[[j]] <- if (identical(unname(value), "preserve")) 1L else 0L
  }
  for (l in 0:max(level)) {
    at <- which(is_open & level == l)
    inherited <- if (l == 0L) rep(-1L, length(at)) else space[parent[at]]
    space[at] <- ifelse(is.na(own[at]), ifelse(inherited >= 0L, inherited, -1L), own[at])
  }
  space
}

#' Which blank text libxml2's NOBLANKS drops
#'
#' As areBlanks() decides it: blank text is kept under xml:space="preserve",
#' as the only content of an element, after a first child that is text, or
#' after the element was marked (below). Text outside the root goes too.
#' @noRd
svg_markup_blanks <- function(kind, tok, level, parent, space) {
  n <- length(kind)
  top <- level == 0L
  is_text <- kind == "text"
  blank <- is_text & grepl("^[ \t\n]*$", tok, useBytes = TRUE)
  drop <- top & is_text
  inner_blank <- which(blank & !top)
  if (!length(inner_blank)) {
    return(drop)
  }
  p <- parent[inner_blank]
  nxt <- c(kind[-1L], "")
  prv <- c("", kind[-n])
  preserve <- space[p] == 1L
  only <- prv[inner_blank] == "start" & nxt[inner_blank] == "end"
  first <- p + 1L
  first_text <- kind[first] == "text" & (!blank[first] | preserve)
  # libxml2 (2.9) marks the element (its space becomes -2) when it hands
  # on character data from its slow path, which takes any non-ASCII text,
  # or a run that starts with a blank: a run starts the text or follows a
  # reference.
  runs <- gsub("&[^;]*;", "\001", tok, useBytes = TRUE)
  chardata <- is_text & !blank &
    grepl("(^|\\x01)[ \\t\\n]|[\\x80-\\xff]", runs, perl = TRUE, useBytes = TRUE)
  first_cd <- rep(Inf, n)
  cd_at <- which(chardata)
  if (length(cd_at)) {
    firsts <- tapply(cd_at, parent[cd_at], min)
    first_cd[as.integer(names(firsts))] <- firsts
  }
  after_cd <- space[p] == -1L & first_cd[p] < inner_blank
  drop[inner_blank] <- !(preserve | only | first_text | after_cd)
  drop
}

#' Parse an SVG document into tokens, as xml2 reads it
#'
#' @param svg_content The document, as lines or one string.
#' @return The document (see the file's header).
#' @noRd
svg_markup_parse <- function(svg_content) {
  tokens <- svg_markup_tokens(svg_content)
  kind <- tokens$kind
  tok <- tokens$tok

  name <- rep(NA_character_, length(tok))
  tagged <- which(kind %in% c("start", "empty", "end"))
  head <- regexpr("^</?[^\\s/>]+", tok[tagged], perl = TRUE, useBytes = TRUE)
  from <- ifelse(kind[tagged] == "end", 3L, 2L)
  name[tagged] <- substring(tok[tagged], from, attr(head, "match.length"))
  idx <- svg_markup_index(kind)
  level <- idx$level
  parent <- idx$parent

  top <- level == 0L
  if (sum(top & kind %in% c("start", "empty")) != 1L) {
    svg_markup_refuse("it has no single root element.")
  }
  if (any(top & kind == "text" & !grepl("^[ \t\n]*$", tok, useBytes = TRUE))) {
    svg_markup_refuse("text outside the root element.")
  }
  if (any(top & kind == "comment")) {
    svg_markup_refuse("a comment outside the root element.")
  }
  space <- svg_markup_space(kind, tok, level, parent)
  drop <- svg_markup_blanks(kind, tok, level, parent, space)

  # Canonical heads for the tags; text escaped as libxml2 writes it.
  tag_at <- which(kind %in% c("start", "empty"))
  canonical <- grepl(svg_markup_canonical_tag_re, tok[tag_at], perl = TRUE, useBytes = TRUE) &
    !grepl("=\"[^\"]*\" xmlns", tok[tag_at], perl = TRUE, useBytes = TRUE)
  tok[tag_at[canonical]] <- sub("/?>$", "", tok[tag_at[canonical]], useBytes = TRUE)
  for (j in tag_at[!canonical]) {
    tok[[j]] <- svg_markup_tag_head(name[[j]], svg_markup_tag_attrs(tok[[j]]))
  }
  tok[kind == "end"] <- name[kind == "end"]
  text_at <- which(kind == "text" & !drop)
  plain <- !grepl(">|&(?!(?:amp|lt|gt);)", tok[text_at], perl = TRUE, useBytes = TRUE)
  rewrite <- text_at[!plain]
  if (length(rewrite)) {
    tok[rewrite] <- svg_markup_escape_text(svg_markup_unescape(tok[rewrite]))
  }

  keep <- !drop
  list(kind = kind[keep], name = name[keep], tok = tok[keep], version = tokens$version)
}

#' Write a document as xml2's `as.character()` does
#'
#' @param doc A document from `svg_markup_parse()`.
#' @return The document as lines, as `strsplit(as.character(doc), "\n")`
#'   gives them from xml2.
#' @noRd
svg_markup_lines <- function(doc) {
  kind <- doc$kind
  tok <- doc$tok
  n <- length(kind)
  idx <- svg_markup_index(kind)
  level <- idx$level
  match <- idx$match
  parent <- idx$parent

  # An element holding text is written as it is, and so is all inside it.
  is_start <- kind == "start"
  loose <- logical(n)
  loose[parent[kind == "text"]] <- TRUE
  for (l in seq_len(max(level))) {
    at <- which(is_start & level == l)
    loose[at] <- loose[at] | loose[parent[at]]
  }
  # Whether the node's parent lays its children out: always at the top.
  laid <- rep(TRUE, n)
  inner <- level > 0L
  laid[inner] <- !loose[parent[inner]]

  indent <- strrep(" ", 2L * pmin(level, 30L))
  lead <- ifelse(laid & inner, indent, "")
  nl <- ifelse(laid, "\n", "")
  childless <- is_start & match == seq_len(n) + 1L
  closes_childless <- kind == "end" & childless[match]

  out <- character(n)
  at <- which(is_start & !childless)
  out[at] <- paste0(lead[at], tok[at], ">", ifelse(loose[at], "", "\n"))
  at <- which(childless | kind == "empty")
  out[at] <- paste0(lead[at], tok[at], "/>", nl[at])
  at <- which(kind == "end" & !closes_childless)
  out[at] <- paste0(
    ifelse(loose[match[at]], "", indent[at]), "</", tok[at], ">", nl[at]
  )
  at <- which(kind == "text")
  out[at] <- tok[at]
  at <- which(kind == "comment")
  out[at] <- paste0(lead[at], tok[at], nl[at])

  text <- paste0(
    "<?xml version=\"", doc$version, "\" encoding=\"UTF-8\"?>\n",
    paste(out, collapse = "")
  )
  Encoding(text) <- "UTF-8"
  strsplit(text, "\n", fixed = TRUE)[[1]]
}

#' The attributes of the tag at `i`
#' @noRd
svg_markup_attrs <- function(doc, i) {
  svg_markup_tag_attrs(doc$tok[[i]])
}

#' Set an attribute on the element at `i`, in place or after the others
#' @return The document
#' @noRd
svg_markup_set_attr <- function(doc, i, name, value) {
  attrs <- svg_markup_attrs(doc, i)
  attrs[[name]] <- svg_markup_bytes(value)
  doc$tok[[i]] <- svg_markup_tag_head(doc$name[[i]], attrs)
  doc
}

#' Tokens for a new element with only empty children
#'
#' @param name,attrs The element.
#' @param children A list of `list(name, attrs)`, each written `<name .../>`.
#' @noRd
svg_markup_element <- function(name, attrs, children = list()) {
  heads <- vapply(children, function(child) svg_markup_tag_head(child$name, child$attrs), "")
  list(
    kind = c("start", rep("empty", length(children)), "end"),
    name = c(name, vapply(children, function(child) child$name, ""), name),
    tok = c(svg_markup_tag_head(name, attrs), heads, name)
  )
}

#' Insert tokens after the token at `after`
#' @noRd
svg_markup_insert <- function(doc, after, new) {
  n <- length(doc$kind)
  head <- seq_len(after)
  tail <- if (after < n) (after + 1L):n else integer(0)
  for (field in c("kind", "name", "tok")) {
    doc[[field]] <- c(doc[[field]][head], new[[field]], doc[[field]][tail])
  }
  doc
}

#' Remove the elements whose tags start at `at`, with all they hold
#' @noRd
svg_markup_remove <- function(doc, at) {
  if (!length(at)) {
    return(doc)
  }
  match <- svg_markup_index(doc$kind)$match
  gone <- logical(length(doc$kind))
  for (i in at) gone[i:match[[i]]] <- TRUE
  for (field in c("kind", "name", "tok")) {
    doc[[field]] <- doc[[field]][!gone]
  }
  doc
}

#' The elements named `name` (start or empty tags), in document order
#' @noRd
svg_markup_elements <- function(doc, name) {
  which(doc$kind %in% c("start", "empty") & doc$name == name)
}

#' One attribute of each element at `at`, `NA` where it has none
#'
#' Reads the canonical heads directly: walking whole `name="value"` pairs
#' from the start, so text inside a value is never taken for a name.
#' @noRd
svg_markup_attr_of <- function(doc, at, attr) {
  heads <- doc$tok[at]
  pattern <- paste0(
    "^<[^\\s/>]+(?: [^\\s=]+=\"[^\"]*\")*? \\Q", attr, "\\E=\"([^\"]*)\""
  )
  has <- grepl(pattern, heads, perl = TRUE, useBytes = TRUE)
  out <- rep(NA_character_, length(heads))
  out[has] <- svg_markup_unescape(
    sub(paste0(pattern, ".*$"), "\\1", heads[has], perl = TRUE, useBytes = TRUE)
  )
  Encoding(out) <- "UTF-8"
  out
}

#' The text inside the element at `i`, as `xml2::xml_text()` reads it
#' @noRd
svg_markup_text <- function(doc, i, match) {
  if (match[[i]] == i) {
    return("")
  }
  inside <- seq.int(i, match[[i]])
  texts <- doc$tok[inside][doc$kind[inside] == "text"]
  out <- paste(svg_markup_unescape(texts), collapse = "")
  Encoding(out) <- "UTF-8"
  out
}

#' Finish the chart's SVG without libxml2
#'
#' Does what [create_enhanced_svg()] does with xml2 once the chart is drawn:
#' for a candlestick chart the open and close marks, the chartSeries header
#' and the stripped axes, then the `maidr-data` attribute.
#'
#' @param svg_content Character vector of SVG lines.
#' @param maidr_data The maidr-data structure.
#' @param candlestick Whether the chart has a candlestick layer.
#' @return The SVG lines, as the xml2 path writes them.
#' @keywords internal
finish_svg_markup <- function(svg_content, maidr_data, candlestick = FALSE) {
  doc <- svg_markup_parse(svg_content)
  if (candlestick) {
    doc <- add_candlestick_marks_markup(doc, maidr_data)
    doc <- chartseries_bracket_markup(doc)
    doc <- svg_markup_remove(doc, chartseries_axis_groups_markup(doc, chartseries_date_axis_ids))
    doc <- svg_markup_remove(doc, chartseries_axis_groups_markup(doc, chartseries_right_axis_ids))
  }
  root <- which(doc$kind %in% c("start", "empty"))[[1]]
  doc <- svg_markup_set_attr(doc, root, "maidr-data", maidr_data_json(maidr_data))
  svg_markup_lines(doc)
}

#' [inject_candlestick_open_close_doc()] on a markup document
#' @return The document
#' @noRd
add_candlestick_marks_markup <- function(doc, maidr_data) {
  for (layer in collect_candlestick_layers(maidr_data)) {
    body_sel <- layer$selectors$body
    if (is.null(body_sel) || !is.character(body_sel)) next
    body_id <- extract_body_grob_id(body_sel[[1L]])
    if (is.null(body_id)) next
    rect_index <- extract_rect_index_from_id(body_id)
    if (is.null(rect_index)) next

    groups <- svg_markup_elements(doc, "g")
    ids <- svg_markup_attr_of(doc, groups, "id")
    body <- groups[which(ids == body_id)[1L]]
    if (is.na(body)) next

    match <- svg_markup_index(doc$kind)$match
    rects <- svg_markup_elements(doc, "rect")
    rects <- rects[rects > body & rects < match[[body]]]
    n_use <- min(length(rects), length(layer$data))
    if (n_use == 0L) next

    marks <- candlestick_open_close_marks(
      x = svg_markup_attr_of(doc, rects[seq_len(n_use)], "x"),
      y = svg_markup_attr_of(doc, rects[seq_len(n_use)], "y"),
      width = svg_markup_attr_of(doc, rects[seq_len(n_use)], "width"),
      height = svg_markup_attr_of(doc, rects[seq_len(n_use)], "height"),
      layer = layer,
      rect_index = rect_index
    )
    as_children <- function(lines) lapply(lines, function(a) list(name = "line", attrs = a))
    opens <- svg_markup_element(
      "g", c(id = sprintf("maidr-cs-opens-%s", rect_index)), as_children(marks$opens)
    )
    closes <- svg_markup_element(
      "g", c(id = sprintf("maidr-cs-closes-%s", rect_index)), as_children(marks$closes)
    )
    both <- Map(c, opens, closes)
    doc <- svg_markup_insert(doc, match[[body]], both)
  }
  doc
}

#' [adjust_chartseries_bracket_doc()] on a markup document
#' @return The document
#' @noRd
chartseries_bracket_markup <- function(doc) {
  root <- which(doc$kind %in% c("start", "empty"))[[1]]
  safe_x <- chartseries_bracket_x(svg_markup_attrs(doc, root)["viewBox"])
  if (is.null(safe_x)) {
    return(doc)
  }
  idx <- svg_markup_index(doc$kind)
  for (i in svg_markup_elements(doc, "text")) {
    if (!grepl(chartseries_bracket_re, svg_markup_text(doc, i, idx$match))) next
    offset <- 0
    p <- idx$parent[[i]]
    while (p > 0L) {
      if (identical(doc$name[[p]], "g")) {
        transform <- svg_markup_attrs(doc, p)["transform"]
        if (!is.na(transform)) offset <- offset + translate_x(unname(transform))
      }
      p <- idx$parent[[p]]
    }
    doc <- svg_markup_set_attr(doc, i, "x", format(safe_x - offset, trim = TRUE))
    doc <- svg_markup_set_attr(doc, i, "text-anchor", "end")
    break
  }
  doc
}

#' The `<g>` elements whose id holds any of `id_parts`
#' @noRd
chartseries_axis_groups_markup <- function(doc, id_parts) {
  groups <- svg_markup_elements(doc, "g")
  ids <- svg_markup_attr_of(doc, groups, "id")
  hit <- !is.na(ids) & Reduce(`|`, lapply(id_parts, function(part) grepl(part, ids, fixed = TRUE)))
  groups[hit]
}
