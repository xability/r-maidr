# The DotPad SDK is the one thing maidr.js fetches at runtime that this
# package cannot bundle for it (upstream may not redistribute it), so an
# offline document reaches jsDelivr the first time a DotPad connects unless
# the page names its own copy. These settings are how an R session names one.

with_dotpad_settings <- function(code, sdk = NULL, asset = NULL,
                                 env_sdk = NULL, env_asset = NULL) {
  previous <- options(
    maidr.dotpad_sdk_url = sdk,
    maidr.dotpad_asset_base_url = asset
  )
  on.exit(options(previous), add = TRUE)

  vars <- c(
    MAIDR_DOTPAD_SDK_URL = env_sdk,
    MAIDR_DOTPAD_ASSET_BASE_URL = env_asset
  )
  old_env <- Sys.getenv(
    c("MAIDR_DOTPAD_SDK_URL", "MAIDR_DOTPAD_ASSET_BASE_URL"),
    unset = NA
  )
  restore_env <- function() {
    for (name in names(old_env)) {
      if (is.na(old_env[[name]])) {
        Sys.unsetenv(name)
      } else {
        do.call(Sys.setenv, as.list(old_env[name]))
      }
    }
  }
  on.exit(restore_env(), add = TRUE)
  Sys.unsetenv(c("MAIDR_DOTPAD_SDK_URL", "MAIDR_DOTPAD_ASSET_BASE_URL"))
  if (length(vars) > 0) do.call(Sys.setenv, as.list(vars))

  force(code)
}

svg_fixture_dotpad <- function() {
  c(
    '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">',
    '<rect x="10" y="10" width="80" height="80"/>',
    "</svg>"
  )
}

# ==============================================================================
# Resolution: option, then environment variable
# ==============================================================================

test_that("nothing is configured by default", {
  with_dotpad_settings({
    config <- maidr:::maidr_dotpad_config()
    testthat::expect_null(config$sdk_url)
    testthat::expect_null(config$asset_base_url)
    testthat::expect_identical(maidr:::maidr_dotpad_config_script(), "")
    testthat::expect_null(maidr:::maidr_dotpad_config_dependency())
  })
})

test_that("the options name the SDK and the braille engine", {
  with_dotpad_settings(
    sdk = "/vendor/DotPadSDK-3.0.2.js",
    asset = "/vendor/lib/",
    {
      config <- maidr:::maidr_dotpad_config()
      testthat::expect_identical(config$sdk_url, "/vendor/DotPadSDK-3.0.2.js")
      testthat::expect_identical(config$asset_base_url, "/vendor/lib/")
    }
  )
})

test_that("the environment variables carry the same names as the globals", {
  with_dotpad_settings(
    env_sdk = "https://intranet.example/dotpad/DotPadSDK-3.0.2.js",
    env_asset = "https://intranet.example/dotpad/lib/",
    {
      config <- maidr:::maidr_dotpad_config()
      testthat::expect_identical(
        config$sdk_url,
        "https://intranet.example/dotpad/DotPadSDK-3.0.2.js"
      )
      testthat::expect_identical(
        config$asset_base_url,
        "https://intranet.example/dotpad/lib/"
      )
    }
  )
})

test_that("an option wins over its environment variable; an empty one defers", {
  with_dotpad_settings(
    sdk = "/from-option.js",
    asset = "",
    env_sdk = "/from-env.js",
    env_asset = "/from-env/lib/",
    {
      config <- maidr:::maidr_dotpad_config()
      testthat::expect_identical(config$sdk_url, "/from-option.js")
      testthat::expect_identical(config$asset_base_url, "/from-env/lib/")
    }
  )
})

test_that("an empty environment variable counts as unset", {
  with_dotpad_settings(env_sdk = "", {
    testthat::expect_null(maidr:::maidr_dotpad_config()$sdk_url)
  })
})

test_that("an option that is not a single string is refused", {
  with_dotpad_settings(sdk = TRUE, {
    testthat::expect_error(
      maidr:::maidr_dotpad_config(),
      "maidr.dotpad_sdk_url",
      fixed = TRUE
    )
  })
  with_dotpad_settings(asset = c("a", "b"), {
    testthat::expect_error(
      maidr:::maidr_dotpad_config(),
      "maidr.dotpad_asset_base_url",
      fixed = TRUE
    )
  })
})

# ==============================================================================
# The script tag
# ==============================================================================

test_that("the script sets only the globals that are configured", {
  script <- maidr:::maidr_dotpad_config_script(
    list(sdk_url = "/vendor/DotPadSDK-3.0.2.js", asset_base_url = NULL)
  )

  testthat::expect_true(grepl(
    'window.MAIDR_DOTPAD_SDK_URL = "/vendor/DotPadSDK-3.0.2.js";',
    script,
    fixed = TRUE
  ))
  testthat::expect_false(
    grepl("MAIDR_DOTPAD_ASSET_BASE_URL", script, fixed = TRUE)
  )
  testthat::expect_true(startsWith(script, "<script>"))
  testthat::expect_true(endsWith(script, "</script>"))

  both <- maidr:::maidr_dotpad_config_script(
    list(sdk_url = "/a.js", asset_base_url = "/lib/")
  )
  testthat::expect_true(
    grepl('window.MAIDR_DOTPAD_SDK_URL = "/a.js";', both, fixed = TRUE)
  )
  testthat::expect_true(
    grepl('window.MAIDR_DOTPAD_ASSET_BASE_URL = "/lib/";', both, fixed = TRUE)
  )
})

test_that("a URL cannot break out of the script element", {
  # `</` ends a <script> for the HTML parser whatever the JavaScript around
  # it says, and a quote would end the literal.
  hostile <- '/x".js</script><script>alert(1)</script>'
  script <- maidr:::maidr_dotpad_config_script(
    list(sdk_url = hostile, asset_base_url = NULL)
  )

  # One closing tag: the one this package wrote.
  testthat::expect_identical(
    lengths(regmatches(script, gregexpr("</script>", script, fixed = TRUE))),
    1L
  )
  testthat::expect_true(grepl('\\"', script, fixed = TRUE))
  testthat::expect_true(grepl("<\\/script>", script, fixed = TRUE))
})

# ==============================================================================
# Every path that loads the bundle declares the globals ahead of it
# ==============================================================================

test_that("the standalone document declares the globals in its head, offline and on the CDN", {
  with_dotpad_settings(
    sdk = "/vendor/DotPadSDK-3.0.2.js",
    asset = "/vendor/lib/",
    for (use_cdn in c(FALSE, TRUE)) {
      html <- maidr:::create_standalone_html(
        svg_fixture_dotpad(),
        use_cdn = use_cdn
      )

      declared_at <- regexpr("window.MAIDR_DOTPAD_SDK_URL", html, fixed = TRUE)
      head_ends_at <- regexpr("</head>", html, fixed = TRUE)
      testthat::expect_true(declared_at > 0)
      testthat::expect_true(declared_at < head_ends_at)
      testthat::expect_true(grepl(
        'window.MAIDR_DOTPAD_ASSET_BASE_URL = "/vendor/lib/";',
        html,
        fixed = TRUE
      ))
    }
  )
})

test_that("the standalone document says nothing about a DotPad when unconfigured", {
  with_dotpad_settings({
    html <- maidr:::create_standalone_html(svg_fixture_dotpad(), use_cdn = FALSE)
    testthat::expect_false(grepl("window.MAIDR_DOTPAD", html, fixed = TRUE))
  })
})

test_that("the dependency list puts the globals ahead of maidr.js", {
  with_dotpad_settings(sdk = "/vendor/DotPadSDK-3.0.2.js", {
    for (use_cdn in list(TRUE, FALSE, NULL)) {
      deps <- maidr:::maidr_html_dependencies(use_cdn = use_cdn)

      testthat::expect_length(deps, 2)
      testthat::expect_identical(deps[[1]]$name, "maidr-dotpad-config")
      testthat::expect_identical(deps[[2]]$name, "maidr")

      rendered <- as.character(htmltools::renderDependencies(deps))
      declared_at <- regexpr(
        "window.MAIDR_DOTPAD_SDK_URL",
        rendered,
        fixed = TRUE
      )
      bundle_at <- regexpr("maidr.js", rendered, fixed = TRUE)
      testthat::expect_true(declared_at > 0)
      testthat::expect_true(bundle_at > 0)
      testthat::expect_true(declared_at < bundle_at)
    }
  })
})

test_that("the dependency list is unchanged when nothing is configured", {
  with_dotpad_settings({
    deps <- maidr:::maidr_html_dependencies(use_cdn = FALSE)
    testthat::expect_length(deps, 1)
    testthat::expect_identical(deps[[1]]$name, "maidr")
  })
})

test_that("save_html() writes the globals ahead of the bundle", {
  testthat::skip_if_not_installed("ggplot2")

  with_dotpad_settings(sdk = "/vendor/DotPadSDK-3.0.2.js", {
    p <- create_test_ggplot_bar()
    tmp_file <- tempfile(fileext = ".html")
    on.exit(unlink(tmp_file), add = TRUE)

    save_html(p, file = tmp_file, use_cdn = FALSE)
    html <- paste(readLines(tmp_file, warn = FALSE), collapse = "\n")

    declared_at <- regexpr("window.MAIDR_DOTPAD_SDK_URL", html, fixed = TRUE)
    bundle_at <- regexpr("maidr.js", html, fixed = TRUE)
    testthat::expect_true(declared_at > 0)
    testthat::expect_true(declared_at < bundle_at)
  })
})

test_that("the widget's frame carries the globals", {
  testthat::skip_if_not_installed("ggplot2")

  with_dotpad_settings(sdk = "/vendor/DotPadSDK-3.0.2.js", {
    widget <- maidr_widget(create_test_ggplot_bar(), use_cdn = FALSE)
    # The frame's document travels escaped in `srcdoc`; the assignment
    # survives escaping, only its quotes change.
    testthat::expect_true(grepl(
      "window.MAIDR_DOTPAD_SDK_URL = &quot;/vendor/DotPadSDK-3.0.2.js&quot;;",
      widget$x$iframe_content,
      fixed = TRUE
    ))
  })
})
