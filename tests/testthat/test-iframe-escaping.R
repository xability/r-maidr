# ==============================================================================
# The escaper that carries a chart's document into an attribute
#
# The document travels into the frame as an attribute value, so what the
# escaper does to bytes decides whether a label -- or the inlined maidr.js --
# arrives as itself.
#
# Held here rather than through `create_maidr_iframe()` because the round-trip
# tests in test-widget.R can only exercise whatever locale the run happens to
# have, and the failures this pins happen under a C locale. Marking the
# inputs explicitly makes the cases independent of the ambient locale.
# ==============================================================================

is_ascii <- function(x) {
  !grepl("[^\\x01-\\x7F]", x, perl = TRUE, useBytes = TRUE)
}

testthat::test_that("the bytes of an unmarked string are read as UTF-8", {
  # Not handed to `enc2utf8()`, which would assume the native encoding and,
  # under a C locale, rewrite each byte as the text `<c3>`, `<a9>`.
  unmarked <- rawToChar(as.raw(c(0x63, 0x61, 0x66, 0xc3, 0xa9)))
  testthat::expect_identical(Encoding(unmarked), "unknown")

  escaped <- maidr:::escape_for_attribute(unmarked)

  testthat::expect_identical(escaped, "caf&#xE9;")
  testthat::expect_identical(Encoding(escaped), "unknown")
})

testthat::test_that("a UTF-8 marked string becomes character references", {
  marked <- rawToChar(as.raw(c(0xed, 0x95, 0x9c, 0x20, 0xe2, 0x80, 0xa6)))
  Encoding(marked) <- "UTF-8"

  testthat::expect_identical(
    maidr:::escape_for_attribute(marked), "&#xD55C; &#x2026;"
  )
})

testthat::test_that("a latin1 marked string is read as latin1", {
  # Converted because it says what it is: read as UTF-8, its bytes would be
  # invalid, and the document declares charset=UTF-8.
  latin1 <- rawToChar(as.raw(c(0x63, 0x61, 0x66, 0xe9)))
  Encoding(latin1) <- "latin1"

  testthat::expect_identical(maidr:::escape_for_attribute(latin1), "caf&#xE9;")
})

testthat::test_that("unmarked bytes that are not UTF-8 are left as they are", {
  # There is no telling what they spell, and guessing could only garble them
  # differently.
  bytes <- as.raw(c(0x61, 0xff, 0x62))
  escaped <- maidr:::escape_for_attribute(rawToChar(bytes))

  testthat::expect_identical(charToRaw(escaped), bytes)
})

testthat::test_that("a frame carrying the inlined bundle is pure ASCII", {
  # The failure this exists for. The bundle has non-ASCII in it (an ellipsis
  # among others); left as bytes, knitr's output and an htmlwidget's JSON
  # rewrote them under a C locale as `<e2><80><a6>`, the script no longer
  # parsed, and a chart rendered offline was a plain picture. ASCII leaves
  # nothing to rewrite, whatever the locale.
  iframe <- maidr:::create_maidr_iframe(
    '<svg maidr-data="{}"><text>한국어 …</text></svg>',
    use_cdn = FALSE
  )

  testthat::expect_true(is_ascii(iframe))
  testthat::expect_true(grepl("&#xD55C;&#xAD6D;&#xC5B4; &#x2026;", iframe, fixed = TRUE))
})

testthat::test_that("an HTML parser gets the original document back", {
  # A character reference in an attribute is decoded by the parser, so the
  # frame's document holds the characters themselves. A small document:
  # libxml2's parser, unlike a browser's, does not hand a 1.8 MB attribute
  # back verbatim, so the bundle's own round trip is left to the browser
  # checks this change was made with.
  document <- paste(
    '<!DOCTYPE html><html><head><meta charset="UTF-8"></head><body>',
    '<svg maidr-data="{&quot;t&quot;:1}"><text>한국어 … café</text></svg>',
    "<script>var s = \"it's\" + '<b>' && 1;</script>",
    "</body></html>",
    sep = "\n"
  )
  Encoding(document) <- "UTF-8"
  iframe <- sprintf('<iframe srcdoc="%s"></iframe>', maidr:::escape_for_attribute(document))
  testthat::expect_true(is_ascii(iframe))

  parsed <- xml2::read_html(iframe, encoding = "UTF-8")
  srcdoc <- xml2::xml_attr(xml2::xml_find_first(parsed, "//iframe"), "srcdoc")

  testthat::expect_identical(srcdoc, document)
})

testthat::test_that("ampersands are escaped before the entities that contain them", {
  # Ordering: `<` becomes `&lt;`, and an `&` pass running afterwards would
  # turn that into `&amp;lt;` and the reader would meet the entity as text.
  escaped <- maidr:::escape_for_attribute('a & b < c > d "e"')

  testthat::expect_identical(escaped, "a &amp; b &lt; c &gt; d &quot;e&quot;")
})

testthat::test_that("an ampersand already in the document survives one round", {
  # A label that legitimately contains an entity: it is escaped once, so the
  # frame's parser hands the original text back.
  testthat::expect_identical(
    maidr:::escape_for_attribute("&amp;"), "&amp;amp;"
  )
})

testthat::test_that("an apostrophe and a newline are left as they are", {
  # Neither can end a double-quoted attribute, and leaving them keeps the
  # document readable and smaller.
  testthat::expect_identical(
    maidr:::escape_for_attribute("it's\nfine"), "it's\nfine"
  )
})
