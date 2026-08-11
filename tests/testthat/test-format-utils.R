# Currency prefix resolution (#139)
#
# A `\uXXXX` escape behaves differently depending on where it sits. In an
# ordinary string it keeps its bytes and its UTF-8 mark in every locale. In a
# *tag* -- `list("\\u20ac" = "EUR")` -- it becomes a symbol, symbols must be
# representable in the native encoding, and outside a UTF-8 session R stores
# the placeholder text `<U+20AC>` instead. The key is then gone before any
# comparison runs, and every non-dollar currency fell through to the `USD`
# default: a euro axis announced as dollars, silently.
#
# That failure is invisible in a UTF-8 session, which is what CI runs, so the
# behavioural case below forces a `C` locale in a subprocess. The static case
# needs no subprocess and states the rule for code written later.

# ---------------------------------------------------------------------------
# Behaviour, in a locale that cannot represent the symbols
# ---------------------------------------------------------------------------

#' Run an expression in a fresh R session under a given locale.
#'
#' @param body Lines of R to run after the package is loaded.
#' @param locale Value for `LC_ALL`.
#' @return The subprocess's stdout, or `NULL` if it could not be run.
#' @noRd
in_locale <- function(body, locale = "C") {
  rscript <- file.path(R.home("bin"), "Rscript")
  if (!file.exists(rscript)) {
    return(NULL)
  }

  root <- normalizePath(testthat::test_path("..", ".."), mustWork = FALSE)
  script <- tempfile(fileext = ".R")
  on.exit(unlink(script), add = TRUE)

  writeLines(
    c(
      sprintf(".libPaths(%s)", paste(deparse(.libPaths()), collapse = "")),
      # `load_all()` under test, `library()` under R CMD check, where the
      # package is installed and the source tree may not be beside us.
      sprintf(
        "if (requireNamespace('pkgload', quietly = TRUE) && dir.exists(%s)) {
           suppressMessages(pkgload::load_all(%s, quiet = TRUE))
         } else {
           suppressMessages(library(maidr))
         }",
        deparse(file.path(root, "R")), deparse(root)
      ),
      body
    ),
    script
  )

  out <- suppressWarnings(system2(
    rscript, script,
    stdout = TRUE, stderr = FALSE,
    env = c(paste0("LC_ALL=", locale), paste0("LANG=", locale))
  ))
  if (!is.null(attr(out, "status")) && attr(out, "status") != 0) {
    return(NULL)
  }
  out
}

test_that("every currency prefix resolves outside a UTF-8 locale", {
  out <- in_locale(c(
    "syms <- c('\\u20ac', '\\u00a3', '\\u00a5', '\\u20b9', '\\u20a9',",
    "          '\\u20bd', '\\u20aa', '\\u20b1', '\\u0e3f', 'z\\u0142', '$')",
    "mark <- function(s) { Encoding(s) <- 'UTF-8'; s }",
    "cat(vapply(syms, function(s)",
    "  maidr:::prefix_to_currency_code(mark(s)), ''), sep = ' ')"
  ))
  skip_if(is.null(out), "could not run a subprocess in the C locale")

  expect_equal(
    strsplit(trimws(paste(out, collapse = " ")), "\\s+")[[1]],
    c("EUR", "GBP", "JPY", "INR", "KRW", "RUB", "ILS", "PHP", "THB",
      "PLN", "USD")
  )
})

test_that("a currency prefix is detected outside a UTF-8 locale", {
  out <- in_locale(c(
    "mark <- function(s) { Encoding(s) <- 'UTF-8'; s }",
    "cat(maidr:::detect_scales_format_type(",
    "  mark('\\u20ac'), NULL, NULL, NULL, NULL))"
  ))
  skip_if(is.null(out), "could not run a subprocess in the C locale")

  expect_equal(trimws(paste(out, collapse = "")), "currency")
})

# ---------------------------------------------------------------------------
# Behaviour in this session, whatever locale it is
# ---------------------------------------------------------------------------

test_that("a currency prefix resolves however its encoding is declared", {
  euro_bytes <- rawToChar(as.raw(c(0xe2, 0x82, 0xac)))
  marked <- euro_bytes
  Encoding(marked) <- "UTF-8"

  # Same bytes, one declared and one not. A reader gets the prefix from
  # whichever of `readr`, `jsonlite` or a literal produced it, and must not
  # hear a different currency because of that.
  expect_equal(prefix_to_currency_code(marked), "EUR")
  expect_equal(prefix_to_currency_code(euro_bytes), "EUR")
})

test_that("an unknown prefix still falls back rather than erroring", {
  expect_equal(prefix_to_currency_code("\u20bf"), "USD") # Bitcoin sign
  expect_equal(prefix_to_currency_code(NULL), "USD")
  expect_equal(prefix_to_currency_code(""), "USD")
  expect_equal(prefix_to_currency_code("SEK"), "SEK") # ISO code passthrough
})

# ---------------------------------------------------------------------------
# The rule, for code written later
# ---------------------------------------------------------------------------

test_that("no non-ASCII escape sits in a tag position in R/", {
  # The behavioural cases above only bite in a `C` locale, and a future
  # `list("\\u20ac" = ...)` written on a UTF-8 machine would pass every test
  # here while being broken for the same readers as before. This case bites
  # in any locale, because it reads the source rather than running it.
  sources <- list.files(
    testthat::test_path("..", "..", "R"),
    pattern = "\\.R$", full.names = TRUE
  )
  skip_if(length(sources) == 0, "no R/ sources beside the tests")

  # Read through the parser rather than with a regex: `EQ_SUB` is the token R
  # uses for a tag inside a call, so a comment that merely discusses the
  # mistake -- as the one above `prefixes` does -- is a `COMMENT` token and
  # cannot be mistaken for the mistake itself.
  offenders <- character()
  for (path in sources) {
    parsed <- tryCatch(
      utils::getParseData(parse(path, keep.source = TRUE)),
      error = function(e) NULL
    )
    if (is.null(parsed) || nrow(parsed) == 0) {
      next
    }

    code <- parsed[parsed$terminal & parsed$token != "COMMENT", ]
    code <- code[order(code$line1, code$col1), ]
    tagged <- which(code$token == "EQ_SUB")
    keys <- tagged[tagged > 1L] - 1L
    keys <- keys[code$token[keys] == "STR_CONST"]
    escaped <- keys[grepl("\\\\u[0-9a-fA-F]{4}", code$text[keys])]

    if (length(escaped)) {
      offenders <- c(
        offenders, sprintf("%s:%d", basename(path), code$line1[escaped])
      )
    }
  }

  expect_equal(
    offenders, character(),
    info = paste(
      "a \\uXXXX escape in a tag becomes the text <U+XXXX> outside a UTF-8",
      "locale; put the escape in a plain string and match on it instead"
    )
  )
})
