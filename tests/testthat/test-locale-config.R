# maidr.js speaks English on its own and fetches any other language as a
# locale pack, `locale-<code>.js`, from beside itself. This package does not
# bundle the packs (0.8 MB, with the installed package already over CRAN's
# size guideline), so a document that loads the bundled copy points maidr.js
# at the packs of that same version on jsDelivr. These settings are how a
# session names another place for them, or turns that off.

with_locale_settings <- function(code, url = NULL, env_url = NULL) {
  previous <- options(
    maidr.locale_base_url = url,
    # CDN documents in these tests name the bundled version rather than
    # asking the network which one is the latest.
    maidr.cdn_version = "bundled"
  )
  on.exit(options(previous), add = TRUE)

  old_env <- Sys.getenv("MAIDR_LOCALE_BASE_URL", unset = NA)
  on.exit(
    if (is.na(old_env)) {
      Sys.unsetenv("MAIDR_LOCALE_BASE_URL")
    } else {
      Sys.setenv(MAIDR_LOCALE_BASE_URL = old_env)
    },
    add = TRUE
  )
  if (is.null(env_url)) {
    Sys.unsetenv("MAIDR_LOCALE_BASE_URL")
  } else {
    Sys.setenv(MAIDR_LOCALE_BASE_URL = env_url)
  }

  force(code)
}

svg_fixture_locale <- function() {
  c(
    '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">',
    '<rect x="10" y="10" width="80" height="80"/>',
    "</svg>"
  )
}

bundled_packs <- function() {
  sprintf("https://cdn.jsdelivr.net/npm/maidr@%s/dist/", maidr:::MAIDR_VERSION)
}

dependency_names <- function(deps) {
  vapply(deps, function(dep) dep$name, character(1))
}

# The declaration itself, not the bare name: an inlined maidr.js mentions
# `maidrLocaleBaseUrl` in its own loader.
DECLARATION <- "window.maidrLocaleBaseUrl = window.maidrLocaleBaseUrl || "

declares <- function(html) {
  grepl(DECLARATION, html, fixed = TRUE)
}

test_that("a bundled document points maidr.js at its own version's packs", {
  with_locale_settings({
    for (use_cdn in list(FALSE, NULL)) {
      deps <- maidr:::maidr_html_dependencies(use_cdn = use_cdn)

      testthat::expect_identical(
        dependency_names(deps),
        c("maidr-locale-config", "maidr")
      )
      testthat::expect_true(grepl(bundled_packs(), deps[[1]]$head, fixed = TRUE))
    }
  })
})

test_that("the declaration lands ahead of the bundle and keeps the page's own", {
  with_locale_settings({
    rendered <- as.character(htmltools::renderDependencies(
      maidr:::maidr_html_dependencies(use_cdn = FALSE)
    ))

    # The `||` is what keeps a page that already says where its packs are.
    declared_at <- regexpr(DECLARATION, rendered, fixed = TRUE)
    bundle_at <- regexpr("maidr.js", rendered, fixed = TRUE)
    testthat::expect_true(declared_at > 0)
    testthat::expect_true(bundle_at > 0)
    testthat::expect_true(declared_at < bundle_at)
  })
})

test_that("an inlined bundle gets the declaration ahead of it", {
  # An inline script has no URL of its own, so without the declaration
  # maidr.js has nowhere to look for a pack at all.
  with_locale_settings({
    html <- maidr:::create_standalone_html(svg_fixture_locale(), use_cdn = FALSE)
    bundle_start <- substr(maidr:::maidr_inline_asset_tags()$js_tag, 1, 200)

    declared_at <- regexpr(DECLARATION, html, fixed = TRUE)
    bundle_at <- regexpr(bundle_start, html, fixed = TRUE)
    testthat::expect_true(declared_at > 0)
    testthat::expect_true(bundle_at > 0)
    testthat::expect_true(declared_at < bundle_at)
    testthat::expect_true(grepl(bundled_packs(), html, fixed = TRUE))
  })
})

test_that("a CDN document declares nothing, the packs being beside its copy", {
  with_locale_settings({
    deps <- maidr:::maidr_html_dependencies(use_cdn = TRUE)
    testthat::expect_identical(dependency_names(deps), "maidr")

    html <- maidr:::create_standalone_html(svg_fixture_locale(), use_cdn = TRUE)
    testthat::expect_false(declares(html))
  })
})

test_that("a place the session names is declared in every document", {
  with_locale_settings(url = "https://example.org/maidr/", {
    for (use_cdn in list(TRUE, FALSE)) {
      deps <- maidr:::maidr_html_dependencies(use_cdn = use_cdn)
      config <- Filter(function(dep) dep$name == "maidr-locale-config", deps)

      testthat::expect_length(config, 1)
      testthat::expect_true(grepl(
        "\"https://example.org/maidr/\"",
        config[[1]]$head,
        fixed = TRUE
      ))
      testthat::expect_false(grepl("cdn.jsdelivr.net", config[[1]]$head, fixed = TRUE))
    }
  })
})

test_that("the environment variable is read when the option is unset", {
  with_locale_settings(env_url = "https://mirror.example/packs/", {
    deps <- maidr:::maidr_html_dependencies(use_cdn = FALSE)
    testthat::expect_true(grepl(
      "https://mirror.example/packs/",
      deps[[1]]$head,
      fixed = TRUE
    ))
  })
})

test_that("an empty setting turns the declaration off", {
  # For a document that must never touch the network: English only.
  for (off in list("", FALSE)) {
    with_locale_settings(url = off, {
      deps <- maidr:::maidr_html_dependencies(use_cdn = FALSE)
      testthat::expect_identical(dependency_names(deps), "maidr")

      html <- maidr:::create_standalone_html(svg_fixture_locale(), use_cdn = FALSE)
      testthat::expect_false(declares(html))
    })
  }
})

test_that("anything else is refused by name", {
  with_locale_settings(url = 42, {
    testthat::expect_error(
      maidr:::maidr_html_dependencies(use_cdn = FALSE),
      "maidr.locale_base_url"
    )
  })
})

test_that("the declared place cannot close the script it sits in", {
  with_locale_settings(url = "https://example.org/</script><script>alert(1)//", {
    head <- maidr:::maidr_html_dependencies(use_cdn = FALSE)[[1]]$head
    testthat::expect_false(grepl("</script><script>", head, fixed = TRUE))
  })
})
