# The page dependencies of the charts a knitted HTML page shows inline, in
# R/html_dependencies.R, and the script and stylesheet that go with them in
# inst/maidr-knitr/.

# ==============================================================================
# Page dependencies
# ==============================================================================

test_that("the knitr page loads maidr.js deferred, with its maths stylesheet declared", {
  deps <- maidr:::maidr_knitr_dependencies()
  names <- vapply(deps, function(dep) dep$name, character(1))
  testthat::expect_identical(utils::tail(names, 2L), c("maidr", "maidr-knitr"))

  bundle <- deps[[which(names == "maidr")]]
  testthat::expect_identical(bundle$script, list(list(src = "maidr.js", defer = NA)))
  testthat::expect_identical(unname(unlist(bundle$attachment)), "maidr-math.css")
  testthat::expect_false(bundle$all_files)
  html <- as.character(htmltools::renderDependencies(list(bundle)))
  testthat::expect_match(html, '<script src="[^"]*maidr.js" defer>')
  testthat::expect_match(html, 'id="maidr-math-attachment" rel="attachment"', fixed = TRUE)

  # The configuration still comes first, and the page bundle of the frames
  # is not needed.
  testthat::expect_identical(
    names[seq_len(length(names) - 2L)],
    vapply(
      Filter(function(dep) dep$name != "maidr", maidr:::maidr_html_dependencies(use_cdn = FALSE)),
      function(dep) dep$name, character(1)
    )
  )
  testthat::expect_false("maidr-page-bundle" %in% names)
})

test_that("the knitr page script and stylesheet are installed, and named apart from maidr's", {
  dep <- maidr:::maidr_knitr_dependency()
  dir <- system.file(dep$src$file, package = dep$package)
  testthat::expect_true(file.exists(file.path(dir, dep$script)))
  testthat::expect_true(file.exists(file.path(dir, dep$stylesheet)))
  # maidr.js takes a stylesheet named maidr-*.css for its own when it looks
  # for maidr-math.css.
  pattern <- "(?:^|/)maidr(?:[.-]\\w+)*\\.css(?:$|[?#])"
  testthat::expect_false(grepl(pattern, dep$stylesheet, perl = TRUE))
  testthat::expect_false(grepl(
    pattern, file.path(sprintf("%s-%s", dep$name, dep$version), dep$stylesheet),
    perl = TRUE
  ))
  # No switch for tests is left in what ships.
  js <- paste(readLines(file.path(dir, dep$script)), collapse = "\n")
  testthat::expect_false(grepl("NoShims", js, fixed = TRUE))
})

test_that("save_html() and the widgets keep their bundle as it was", {
  for (use_cdn in c(FALSE, TRUE)) {
    deps <- maidr:::maidr_html_dependencies(use_cdn = use_cdn)
    bundle <- deps[[length(deps)]]
    testthat::expect_identical(bundle$script, "maidr.js")
    testthat::expect_null(bundle$attachment)
  }
})
