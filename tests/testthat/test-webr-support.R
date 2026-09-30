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

test_that("every occurrence of a tag is inlined", {
  dir <- withr::local_tempdir()
  dir.create(file.path(dir, "lib"))
  writeLines("var a = 1;", file.path(dir, "lib", "a.js"))
  tag <- '<script src="lib/a.js"></script>'
  page <- write_page(dir, paste0(tag, tag))

  html <- maidr:::maidr_inline_local_assets(page)

  expect_equal(lengths(regmatches(html, gregexpr("var a = 1;", html, fixed = TRUE))), 2L)
  expect_false(grepl("lib/a.js", html, fixed = TRUE))
})

test_that("single-quoted attributes are left as they are", {
  dir <- withr::local_tempdir()
  dir.create(file.path(dir, "lib"))
  writeLines("var a = 1;", file.path(dir, "lib", "a.js"))
  head <- "<script src='lib/a.js'></script>"
  page <- write_page(dir, head)

  html <- maidr:::maidr_inline_local_assets(page)

  expect_match(html, head, fixed = TRUE)
})

test_that("text that is inlined is not searched for tags again", {
  dir <- withr::local_tempdir()
  dir.create(file.path(dir, "lib"))
  writeLines("not css", file.path(dir, "lib", "b.css"))
  link <- '<link rel="stylesheet" href="lib/b.css">'
  writeLines(paste0("var t = '", link, "';"), file.path(dir, "lib", "a.js"))
  page <- write_page(dir, paste0('<script src="lib/a.js"></script>', link))

  html <- maidr:::maidr_inline_local_assets(page)

  # The link in the page is inlined; the one inside the script is just text.
  expect_match(html, paste0("<script>var t = '", link, "';</script>"), fixed = TRUE)
  expect_match(html, "<style>not css</style>", fixed = TRUE)
  expect_equal(lengths(regmatches(html, gregexpr("not css", html, fixed = TRUE))), 1L)
})

test_that("inlined assets keep the order of the page", {
  dir <- withr::local_tempdir()
  dir.create(file.path(dir, "lib"))
  for (name in c("a", "b", "c")) {
    writeLines(paste0("var ", name, " = 1;"), file.path(dir, "lib", paste0(name, ".js")))
  }
  scripts <- paste0('<script src="lib/', c("c", "a", "b"), '.js"></script>', collapse = "")
  page <- write_page(dir, paste0(scripts, "<title>t</title>"))

  html <- maidr:::maidr_inline_local_assets(page)

  expect_match(
    html,
    "<script>var c = 1;</script><script>var a = 1;</script><script>var b = 1;</script><title>t</title>",
    fixed = TRUE
  )
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
  skip_if(identical(R.version$os, "emscripten"))

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

test_that("display_html_file() takes the webR path when is_webr() is TRUE", {
  dir <- withr::local_tempdir()
  dir.create(file.path(dir, "lib"))
  writeLines("var a = 1;", file.path(dir, "lib", "a.js"))
  page <- write_page(dir, '<script src="lib/a.js"></script>')
  shown <- NULL
  testthat::local_mocked_bindings(
    is_webr = function() TRUE,
    maidr_webr_display = function(html) shown <<- html,
    .package = "maidr"
  )

  maidr:::display_html_file(page)

  expect_match(shown, "<script>var a = 1;</script>", fixed = TRUE)
})

test_that("is_webr() is FALSE on a native build", {
  skip_if(identical(R.version$os, "emscripten"))
  expect_false(maidr:::is_webr())
})

test_that("the page script hands the document to maidrWebRShow or embeds it", {
  js <- maidr:::maidr_webr_show_js("<p>100% \"quoted\"</p>")

  expect_match(js, "globalThis.maidrWebRShow", fixed = TRUE)
  expect_match(js, "document.createElement('iframe')", fixed = TRUE)
  expect_match(js, "maidr-output", fixed = TRUE)
  expect_match(js, "f.srcdoc = html", fixed = TRUE)
  # The frame is sized to its content, not to itself.
  expect_match(js, "min-height: 0 !important", fixed = TRUE)
  expect_match(js, "new MutationObserver(later)", fixed = TRUE)
  expect_match(js, "width:100%;height:450px", fixed = TRUE)
  # The document travels as a JSON string, so nothing in it is code, and a
  # closing tag in it cannot end the script it sits in.
  expect_match(js, '"<p>100% \\"quoted\\"<\\/p>"', fixed = TRUE)
  # The frame listener script is passed as a string, without its <script> tags.
  expect_false(grepl("<script>", js, fixed = TRUE))
})

test_that("the fallback message says why the page could not show the chart", {
  skip_if(identical(R.version$os, "emscripten"))
  withr::local_options(maidr.webr_display = NULL)

  expect_message(
    maidr:::maidr_webr_display("<p>hi</p>"),
    "could not show the chart on the page \\(.+\\)"
  )
})

test_that("a document comes back as one string with its dependencies inlined", {
  dir <- withr::local_tempdir()
  writeLines("var dep = 1;", file.path(dir, "dep.js"))
  page <- htmltools::tagList(
    htmltools::htmlDependency("dep", "1.0", src = c(file = dir), script = "dep.js"),
    htmltools::tags$p("chart")
  )

  html <- maidr:::maidr_webr_document(page)

  expect_match(html, "<script>var dep = 1;</script>", fixed = TRUE)
  expect_match(html, "<p>chart</p>", fixed = TRUE)
  expect_false(grepl("src=\"lib/", html, fixed = TRUE))
  expect_length(list.files(tempdir(), pattern = "^maidr-webr-"), 0L)
})

test_that("the listener code is the listener script without its element", {
  code <- maidr:::maidr_iframe_host_script_code()

  expect_false(grepl("<script", code, fixed = TRUE))
  expect_equal(
    maidr:::maidr_iframe_host_script(),
    paste0("<script>", code, "</script>")
  )
})

test_that("the JavaScript sent to the page parses", {
  node <- Sys.which("node")
  skip_if(!nzchar(node), "node is not installed")
  dir <- withr::local_tempdir()

  check <- function(name, code) {
    file <- file.path(dir, name)
    writeLines(code, file, useBytes = TRUE)
    system2(node, c("--check", shQuote(file)), stdout = TRUE, stderr = TRUE)
  }

  expect_null(attr(check("show.js", maidr:::maidr_webr_show_js("<p>hi</p>")), "status"))
  expect_null(attr(check("host.js", maidr:::maidr_iframe_host_script_code()), "status"))
})
