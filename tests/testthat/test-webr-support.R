write_page <- function(dir, head) {
  dir.create(file.path(dir, "lib"), showWarnings = FALSE)
  page <- file.path(dir, "index.html")
  writeLines(paste0("<html><head>", head, "</head><body></body></html>"), page)
  page
}

test_that("local scripts and stylesheets are inlined", {
  dir <- withr::local_tempdir()
  dir.create(file.path(dir, "lib"))
  writeLines("var a = 1;", file.path(dir, "lib", "a.js"))
  writeLines("p { color: red; }", file.path(dir, "lib", "a.css"))
  page <- write_page(
    dir,
    '<script src="lib/a.js"></script><link rel="stylesheet" href="lib/a.css">'
  )

  html <- maidr:::maidr_inline_local_assets(page)

  expect_match(html, "<script>var a = 1;</script>", fixed = TRUE)
  expect_match(html, "<style>p { color: red; }</style>", fixed = TRUE)
  expect_false(grepl("lib/a", html, fixed = TRUE))
})

test_that("only stylesheet links are inlined", {
  dir <- withr::local_tempdir()
  dir.create(file.path(dir, "lib"))
  writeLines("not css", file.path(dir, "lib", "icon.png"))
  page <- write_page(dir, '<link rel="icon" href="lib/icon.png">')

  html <- maidr:::maidr_inline_local_assets(page)

  expect_match(html, '<link rel="icon" href="lib/icon.png">', fixed = TRUE)
  expect_false(grepl("<style>", html, fixed = TRUE))
})

test_that("remote URLs, absolute paths and missing files are left alone", {
  dir <- withr::local_tempdir()
  head <- paste0(
    '<script src="https://cdn.example/x.js"></script>',
    '<script src="//cdn.example/y.js"></script>',
    '<script src="/abs/z.js"></script>',
    '<script src="lib/missing.js"></script>'
  )
  page <- write_page(dir, head)

  html <- maidr:::maidr_inline_local_assets(page)

  expect_match(html, head, fixed = TRUE)
})

test_that("a closing tag inside an inlined body cannot end it early", {
  dir <- withr::local_tempdir()
  dir.create(file.path(dir, "lib"))
  writeLines('var s = "</script>";', file.path(dir, "lib", "a.js"))
  writeLines("a::after { content: '</style>'; }", file.path(dir, "lib", "a.css"))
  page <- write_page(
    dir,
    '<script src="lib/a.js"></script><link rel="stylesheet" href="lib/a.css">'
  )

  html <- maidr:::maidr_inline_local_assets(page)

  expect_equal(lengths(regmatches(html, gregexpr("</script>", html, fixed = TRUE))), 1L)
  expect_equal(lengths(regmatches(html, gregexpr("</style>", html, fixed = TRUE))), 1L)
})

test_that("replacement text is inserted literally", {
  dir <- withr::local_tempdir()
  dir.create(file.path(dir, "lib"))
  writeLines("var r = '$1 \\1 \\\\';", file.path(dir, "lib", "a.js"))
  page <- write_page(dir, '<script src="lib/a.js"></script>')

  html <- maidr:::maidr_inline_local_assets(page)

  expect_match(html, "var r = '$1 \\1 \\\\';", fixed = TRUE)
})

test_that("maidr_webr_display() calls options(maidr.webr_display)", {
  got <- NULL
  withr::local_options(maidr.webr_display = function(html) got <<- html)

  maidr:::maidr_webr_display("<p>hi</p>")

  expect_equal(got, "<p>hi</p>")
})

test_that("maidr_webr_display() falls back to a file and says where", {
  withr::local_options(maidr.webr_display = NULL)
  skip_if(requireNamespace("webr", quietly = TRUE))

  expect_message(file <- maidr:::maidr_webr_display("<p>hi</p>"), "Running under webR")

  expect_true(file.exists(file))
  expect_equal(readLines(file, warn = FALSE), "<p>hi</p>")
})

test_that("display_html() takes the webR path when is_webr() is TRUE", {
  seen <- FALSE
  testthat::local_mocked_bindings(
    is_webr = function() TRUE,
    display_html_webr = function(html_doc) seen <<- TRUE,
    .package = "maidr"
  )

  maidr:::display_html(htmltools::tags$p("x"))

  expect_true(seen)
})

test_that("is_webr() is FALSE on a native build", {
  skip_if(identical(R.version$os, "emscripten"))
  expect_false(maidr:::is_webr())
})
