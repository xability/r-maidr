# ==============================================================================
# The escaper that carries a chart's document into an attribute
#
# The document travels into the frame as an attribute value, so what the
# escaper does to bytes decides whether a label arrives as itself.
#
# Held here rather than through `create_maidr_iframe()` because the round-trip
# tests in test-widget.R can only exercise whatever locale the run happens to
# have. The conditional this pins --- convert only a string that says what it
# is --- is invisible under a UTF-8 locale, which is exactly where CI runs, and
# is the line whose absence garbled every non-ASCII label before. Marking the
# inputs explicitly makes the cases independent of the ambient locale.
# ==============================================================================

testthat::test_that("bytes of an unmarked string are left alone", {
  # The case that was broken. `enc2utf8()` on an unmarked string assumes the
  # native encoding, and under a C locale it cannot represent these bytes, so
  # it rewrites each one as the text `<c3>`, `<a9>`.
  raw_bytes <- as.raw(c(0x63, 0x61, 0x66, 0xc3, 0xa9))
  unmarked <- rawToChar(raw_bytes)
  testthat::expect_identical(Encoding(unmarked), "unknown")

  escaped <- maidr:::escape_for_attribute(unmarked)

  testthat::expect_identical(charToRaw(escaped), raw_bytes)
  testthat::expect_false(grepl("<c3>", escaped, fixed = TRUE, useBytes = TRUE))

  # And it comes back unmarked. This is what makes the case discriminate under
  # a UTF-8 locale as well, where the bytes survive an unconditional
  # `enc2utf8()` and only the mark gives it away --- the mark being what makes
  # the `sprintf` that builds the tag transliterate the string afterwards.
  testthat::expect_identical(Encoding(escaped), "unknown")
})

testthat::test_that("a UTF-8 marked string keeps its bytes", {
  marked <- rawToChar(as.raw(c(0xed, 0x95, 0x9c)))
  Encoding(marked) <- "UTF-8"

  escaped <- maidr:::escape_for_attribute(marked)

  testthat::expect_identical(
    charToRaw(escaped), as.raw(c(0xed, 0x95, 0x9c))
  )
})

testthat::test_that("a latin1 marked string is converted to UTF-8", {
  # Converted because it says what it is: the document declares charset=UTF-8,
  # so latin1 bytes would arrive as mojibake. This is the half of the
  # conditional that still has to happen.
  latin1 <- rawToChar(as.raw(c(0x63, 0x61, 0x66, 0xe9)))
  Encoding(latin1) <- "latin1"

  escaped <- maidr:::escape_for_attribute(latin1)

  testthat::expect_identical(
    charToRaw(escaped), as.raw(c(0x63, 0x61, 0x66, 0xc3, 0xa9))
  )
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
