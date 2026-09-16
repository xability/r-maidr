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
    sdk = "/vendor/DotPadSDK-3.0.3.js",
    asset = "/vendor/lib/",
    {
      config <- maidr:::maidr_dotpad_config()
      testthat::expect_identical(config$sdk_url, "/vendor/DotPadSDK-3.0.3.js")
      testthat::expect_identical(config$asset_base_url, "/vendor/lib/")
    }
  )
})

test_that("the environment variables carry the same names as the globals", {
  with_dotpad_settings(
    env_sdk = "https://intranet.example/dotpad/DotPadSDK-3.0.3.js",
    env_asset = "https://intranet.example/dotpad/lib/",
    {
      config <- maidr:::maidr_dotpad_config()
      testthat::expect_identical(
        config$sdk_url,
        "https://intranet.example/dotpad/DotPadSDK-3.0.3.js"
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
    list(sdk_url = "/vendor/DotPadSDK-3.0.3.js", asset_base_url = NULL)
  )

  testthat::expect_true(grepl(
    'window.MAIDR_DOTPAD_SDK_URL = "/vendor/DotPadSDK-3.0.3.js";',
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
    sdk = "/vendor/DotPadSDK-3.0.3.js",
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
  with_dotpad_settings(sdk = "/vendor/DotPadSDK-3.0.3.js", {
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

  with_dotpad_settings(sdk = "/vendor/DotPadSDK-3.0.3.js", {
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

  with_dotpad_settings(sdk = "/vendor/DotPadSDK-3.0.3.js", {
    widget <- maidr_widget(create_test_ggplot_bar(), use_cdn = FALSE)
    # The frame's document travels escaped in `srcdoc`; the assignment
    # survives escaping, only its quotes change.
    testthat::expect_true(grepl(
      "window.MAIDR_DOTPAD_SDK_URL = &quot;/vendor/DotPadSDK-3.0.3.js&quot;;",
      widget$x$iframe_content,
      fixed = TRUE
    ))
  })
})

# ==============================================================================
# Carrying a copy of the SDK
# ==============================================================================

# Points the SDK directory somewhere for the duration of `code`, with the URL
# settings cleared so a downloaded copy is what the document sees.
with_dotpad_dir <- function(dir, code) {
  with_dotpad_settings({
    previous <- options(maidr.dotpad_sdk_dir = dir)
    on.exit(options(previous), add = TRUE)
    force(code)
  })
}

# Read once, here, because the tests below replace the function that
# returns it, and a helper that asked again would be asking itself.
real_dotpad_manifest <- maidr:::maidr_dotpad_sdk_manifest()

# Where a document carries its copy: `lib/dotpad-sdk-<version>/`.
dotpad_lib_dir <- paste0("dotpad-sdk-", real_dotpad_manifest$version)

# A three-file stand-in for the real manifest, with its bytes.
fake_sdk_contents <- function() {
  contents <- list(
    charToRaw("export class DotPadSDK {}\n"),
    "lib/liblouis.js" = charToRaw("// liblouis\n"),
    "lib/liblouis.data" = charToRaw(strrep("tables", 100))
  )
  names(contents)[1] <- real_dotpad_manifest$module
  contents
}

fake_sdk_manifest <- function(contents = fake_sdk_contents()) {
  real <- real_dotpad_manifest
  sha256sum <- get0("sha256sum", envir = asNamespace("tools"), mode = "function")
  digest_of <- function(bytes, digest) {
    tmp <- tempfile()
    on.exit(unlink(tmp))
    writeBin(bytes, tmp)
    unname(digest(tmp))
  }
  real$files <- data.frame(
    path = names(contents),
    bytes = vapply(contents, length, integer(1)),
    md5 = vapply(contents, digest_of, character(1), digest = tools::md5sum),
    # Real where R can compute it, so the check runs; a placeholder of the
    # right shape where it cannot, so the manifest still validates.
    sha256 = if (is.null(sha256sum)) {
      strrep("0", 64)
    } else {
      vapply(contents, digest_of, character(1), digest = sha256sum)
    },
    stringsAsFactors = FALSE
  )
  real
}

# Writes a complete fake copy where the session will look for it.
write_fake_sdk <- function(dir, contents = fake_sdk_contents()) {
  for (path in names(contents)) {
    target <- file.path(dir, path)
    dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
    writeBin(contents[[path]], target)
  }
  dir
}

test_that("the pins describe one commit of the repository the files are served from", {
  manifest <- maidr:::maidr_dotpad_sdk_manifest()
  testthat::expect_true(grepl("^[0-9a-f]{40}$", manifest$commit))
  testthat::expect_true(grepl("^https://github\\.com/[^/]+/[^/]+$", manifest$repository))
  # jsDelivr serves a GitHub repository at a commit as gh/<owner>/<repo>@<commit>.
  owner_repo <- sub("^https://github\\.com/", "", manifest$repository)
  testthat::expect_identical(
    manifest$base_url,
    sprintf(
      "https://cdn.jsdelivr.net/gh/%s@%s/Web/%s/",
      owner_repo,
      manifest$commit,
      manifest$version
    )
  )
  testthat::expect_true(manifest$module %in% manifest$files$path)
  for (engine in c("liblouis.js", "liblouis.wasm", "liblouis.data")) {
    testthat::expect_true(paste0(manifest$asset_dir, engine) %in% manifest$files$path)
  }
  testthat::expect_true(all(manifest$files$bytes > 0))
  testthat::expect_true(all(grepl("^[0-9a-f]{32}$", manifest$files$md5)))
  testthat::expect_true(all(grepl("^[0-9a-f]{64}$", manifest$files$sha256)))
})

test_that("the pins are the shipped manifest, read as is", {
  # inst/dotpad-sdk.json is maidr.js's own copy of the pin; the accessor
  # must report exactly what is in it, so a refresh of the file is a refresh
  # of every pin.
  raw <- jsonlite::fromJSON(
    system.file("dotpad-sdk.json", package = "maidr", mustWork = TRUE),
    simplifyVector = FALSE
  )
  manifest <- maidr:::maidr_dotpad_sdk_manifest()
  testthat::expect_identical(manifest$version, raw$version)
  testthat::expect_identical(manifest$repository, raw$repository)
  testthat::expect_identical(manifest$commit, raw$commit)
  testthat::expect_identical(manifest$base_url, raw$baseUrl)
  testthat::expect_identical(manifest$module, raw$module)
  testthat::expect_identical(manifest$asset_dir, raw$assetDir)

  testthat::expect_identical(names(manifest$files), c("path", "bytes", "md5", "sha256"))
  testthat::expect_identical(manifest$files$path, names(raw$files))
  testthat::expect_type(manifest$files$bytes, "double")
  for (path in names(raw$files)) {
    row <- manifest$files[manifest$files$path == path, ]
    testthat::expect_identical(row$bytes, as.numeric(raw$files[[path]]$bytes))
    testthat::expect_identical(row$md5, raw$files[[path]]$md5)
    testthat::expect_identical(row$sha256, raw$files[[path]]$sha256)
  }
})

test_that("the pinned liblouis.data is the intact one", {
  # The corrupt copy was 7,685 bytes short; this size is the vendor's own
  # release, restored at the pinned commit.
  files <- maidr:::maidr_dotpad_sdk_manifest()$files
  testthat::expect_identical(files$bytes[files$path == "lib/liblouis.data"], 13751594)
})

test_that("the LGPL notice and wrapper sources travel with the engine", {
  paths <- maidr:::maidr_dotpad_sdk_manifest()$files$path
  testthat::expect_true("lib/LICENSES/liblouis-LGPL-2.1.txt" %in% paths)
  testthat::expect_true("lib/liblouis-web/liblouis_web.c" %in% paths)
  testthat::expect_true("lib/liblouis-web/build_liblouis_web.sh" %in% paths)
})

test_that("the SDK directory is the option, then the variable, then a per-user cache", {
  with_dotpad_settings({
    default <- maidr:::maidr_dotpad_sdk_dir()
    testthat::expect_identical(basename(default), real_dotpad_manifest$version)
    testthat::expect_identical(basename(dirname(default)), "dotpad-sdk")
    testthat::expect_true(startsWith(default, tools::R_user_dir("maidr", "cache")))

    old_env <- Sys.getenv("MAIDR_DOTPAD_SDK_DIR", unset = NA)
    restore_dir_env <- function() {
      if (is.na(old_env)) {
        Sys.unsetenv("MAIDR_DOTPAD_SDK_DIR")
      } else {
        Sys.setenv(MAIDR_DOTPAD_SDK_DIR = old_env)
      }
    }
    on.exit(restore_dir_env(), add = TRUE)
    Sys.setenv(MAIDR_DOTPAD_SDK_DIR = "/from/env")
    testthat::expect_identical(maidr:::maidr_dotpad_sdk_dir(), "/from/env")

    previous <- options(maidr.dotpad_sdk_dir = "/from/option")
    on.exit(options(previous), add = TRUE)
    testthat::expect_identical(maidr:::maidr_dotpad_sdk_dir(), "/from/option")
  })
})

test_that("download writes every file verified, and a manifest, once", {
  contents <- fake_sdk_contents()
  fetched <- character(0)
  testthat::local_mocked_bindings(
    maidr_dotpad_sdk_manifest = function() fake_sdk_manifest(contents),
    maidr_dotpad_download_file = function(url, destfile) {
      fetched <<- c(fetched, url)
      base <- real_dotpad_manifest$base_url
      testthat::expect_true(startsWith(url, base))
      writeBin(contents[[substring(url, nchar(base) + 1)]], destfile)
      invisible(destfile)
    },
    .package = "maidr"
  )
  dir <- file.path(tempfile(), "sdk")
  on.exit(unlink(dirname(dir), recursive = TRUE), add = TRUE)

  testthat::expect_message(
    result <- maidr_download_dotpad_sdk(dir),
    paste("DotPad SDK", real_dotpad_manifest$version),
    fixed = TRUE
  )
  testthat::expect_identical(result, dir)
  for (path in names(contents)) {
    testthat::expect_identical(
      readBin(file.path(dir, path), "raw", n = 1e6),
      contents[[path]]
    )
  }
  testthat::expect_length(fetched, length(contents))
  testthat::expect_length(list.files(dir, pattern = "\\.part$", recursive = TRUE), 0)

  manifest <- jsonlite::fromJSON(file.path(dir, "manifest.json"))
  testthat::expect_identical(manifest$commit, real_dotpad_manifest$commit)
  testthat::expect_identical(manifest$module, real_dotpad_manifest$module)
  testthat::expect_setequal(names(manifest$files), names(contents))
  testthat::expect_true(maidr:::maidr_dotpad_sdk_available(dir))

  # A second call finds every file in place and fetches nothing.
  maidr_download_dotpad_sdk(dir, quiet = TRUE)
  testthat::expect_length(fetched, length(contents))

  # Unless told to.
  maidr_download_dotpad_sdk(dir, force = TRUE, quiet = TRUE)
  testthat::expect_length(fetched, 2 * length(contents))
})

test_that("a corrupt download is refused and nothing is written", {
  contents <- fake_sdk_contents()
  testthat::local_mocked_bindings(
    maidr_dotpad_sdk_manifest = function() fake_sdk_manifest(contents),
    maidr_dotpad_download_file = function(url, destfile) {
      base <- real_dotpad_manifest$base_url
      bytes <- contents[[substring(url, nchar(base) + 1)]]
      # The failure that motivated the pin: a file that arrives short.
      if (endsWith(url, "liblouis.data")) bytes <- bytes[-length(bytes)]
      writeBin(bytes, destfile)
      invisible(destfile)
    },
    .package = "maidr"
  )
  dir <- file.path(tempfile(), "sdk")
  on.exit(unlink(dirname(dir), recursive = TRUE), add = TRUE)

  testthat::expect_error(
    maidr_download_dotpad_sdk(dir, quiet = TRUE),
    "liblouis.data .* expected 600 bytes, got 599"
  )
  testthat::expect_false(file.exists(file.path(dir, "lib", "liblouis.data")))
  testthat::expect_false(file.exists(file.path(dir, "manifest.json")))
  testthat::expect_false(maidr:::maidr_dotpad_sdk_available(dir))
})

test_that("a same-size corruption is caught by its digest", {
  contents <- fake_sdk_contents()
  testthat::local_mocked_bindings(
    maidr_dotpad_sdk_manifest = function() fake_sdk_manifest(contents),
    maidr_dotpad_download_file = function(url, destfile) {
      base <- real_dotpad_manifest$base_url
      bytes <- contents[[substring(url, nchar(base) + 1)]]
      if (endsWith(url, "liblouis.js")) bytes[length(bytes)] <- as.raw(0x58)
      writeBin(bytes, destfile)
      invisible(destfile)
    },
    .package = "maidr"
  )
  dir <- file.path(tempfile(), "sdk")
  on.exit(unlink(dirname(dir), recursive = TRUE), add = TRUE)
  testthat::expect_error(
    maidr_download_dotpad_sdk(dir, quiet = TRUE),
    "expected md5"
  )
})

test_that("a wrong sha256 in the manifest is caught where R can compute one", {
  testthat::skip_if(
    is.null(get0("sha256sum", envir = asNamespace("tools"), mode = "function")),
    "tools::sha256sum() arrived in R 4.5"
  )
  contents <- fake_sdk_contents()
  manifest <- fake_sdk_manifest(contents)
  manifest$files$sha256[1] <- strrep("0", 64)
  testthat::local_mocked_bindings(
    maidr_dotpad_sdk_manifest = function() manifest,
    maidr_dotpad_download_file = function(url, destfile) {
      base <- real_dotpad_manifest$base_url
      writeBin(contents[[substring(url, nchar(base) + 1)]], destfile)
      invisible(destfile)
    },
    .package = "maidr"
  )
  dir <- file.path(tempfile(), "sdk")
  on.exit(unlink(dirname(dir), recursive = TRUE), add = TRUE)
  testthat::expect_error(
    maidr_download_dotpad_sdk(dir, quiet = TRUE),
    "expected sha256"
  )
  testthat::expect_length(list.files(dir, pattern = "\\.part$", recursive = TRUE), 0)
})

test_that("a copy is complete only when every file is at its size", {
  testthat::local_mocked_bindings(
    maidr_dotpad_sdk_manifest = function() fake_sdk_manifest(),
    .package = "maidr"
  )
  dir <- write_fake_sdk(tempfile())
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  testthat::expect_true(maidr:::maidr_dotpad_sdk_available(dir))

  writeBin(charToRaw("short"), file.path(dir, "lib", "liblouis.data"))
  testthat::expect_false(maidr:::maidr_dotpad_sdk_available(dir))

  unlink(file.path(dir, "lib", "liblouis.data"))
  testthat::expect_false(maidr:::maidr_dotpad_sdk_available(dir))

  testthat::expect_false(maidr:::maidr_dotpad_sdk_available(tempfile()))
})

test_that("an offline document carries the copy and points at it", {
  testthat::local_mocked_bindings(
    maidr_dotpad_sdk_manifest = function() fake_sdk_manifest(),
    .package = "maidr"
  )
  dir <- write_fake_sdk(tempfile())
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)

  with_dotpad_dir(dir, {
    html_doc <- maidr:::create_html_document(svg_fixture_dotpad(), use_cdn = FALSE)
    deps <- htmltools::htmlDependencies(html_doc)
    names <- vapply(deps, function(dep) dep$name, character(1))
    testthat::expect_true(which(names == "dotpad-sdk") < which(names == "maidr"))

    out_dir <- tempfile()
    dir.create(out_dir)
    on.exit(unlink(out_dir, recursive = TRUE), add = TRUE)
    out_file <- file.path(out_dir, "chart.html")
    maidr:::save_html_document(html_doc, out_file)

    copied <- file.path(out_dir, "lib", dotpad_lib_dir)
    testthat::expect_true(file.exists(file.path(copied, real_dotpad_manifest$module)))
    testthat::expect_true(file.exists(file.path(copied, "lib", "liblouis.data")))

    html <- paste(readLines(out_file, warn = FALSE), collapse = "\n")
    testthat::expect_true(grepl(
      sprintf(
        'window.MAIDR_DOTPAD_SDK_URL = "lib/%s/%s";',
        dotpad_lib_dir,
        real_dotpad_manifest$module
      ),
      html,
      fixed = TRUE
    ))
    testthat::expect_true(grepl(
      sprintf('window.MAIDR_DOTPAD_ASSET_BASE_URL = "lib/%s/lib/";', dotpad_lib_dir),
      html,
      fixed = TRUE
    ))
    declared_at <- regexpr("window.MAIDR_DOTPAD_SDK_URL", html, fixed = TRUE)
    bundle_at <- regexpr("maidr.js", html, fixed = TRUE)
    testthat::expect_true(declared_at < bundle_at)
  })
})

test_that("only an offline document carries the copy", {
  testthat::local_mocked_bindings(
    maidr_dotpad_sdk_manifest = function() fake_sdk_manifest(),
    .package = "maidr"
  )
  dir <- write_fake_sdk(tempfile())
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)

  with_dotpad_dir(dir, {
    html_doc <- maidr:::create_html_document(svg_fixture_dotpad(), use_cdn = TRUE)
    names <- vapply(htmltools::htmlDependencies(html_doc), function(dep) dep$name, character(1))
    testthat::expect_false("dotpad-sdk" %in% names)
  })
})

test_that("a configured URL wins over a local copy", {
  testthat::local_mocked_bindings(
    maidr_dotpad_sdk_manifest = function() fake_sdk_manifest(),
    .package = "maidr"
  )
  dir <- write_fake_sdk(tempfile())
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)

  with_dotpad_dir(dir, {
    previous <- options(maidr.dotpad_sdk_url = "/vendor/DotPadSDK-3.0.3.js")
    on.exit(options(previous), add = TRUE)
    html_doc <- maidr:::create_html_document(svg_fixture_dotpad(), use_cdn = FALSE)
    names <- vapply(htmltools::htmlDependencies(html_doc), function(dep) dep$name, character(1))
    testthat::expect_false("dotpad-sdk" %in% names)
    testthat::expect_true("maidr-dotpad-config" %in% names)
  })
})

test_that("either URL option alone keeps a local copy out of the document", {
  # Both dependencies write the same globals and the later head wins, so a
  # document carrying both with only the engine's URL configured would load
  # the module from lib/ and the engine from the URL.
  testthat::local_mocked_bindings(
    maidr_dotpad_sdk_manifest = function() fake_sdk_manifest(),
    .package = "maidr"
  )
  dir <- write_fake_sdk(tempfile())
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)

  settings <- list(
    list(maidr.dotpad_asset_base_url = "https://intranet.example/dotpad/lib/"),
    list(
      maidr.dotpad_sdk_url = "https://intranet.example/dotpad/DotPadSDK-3.0.3.js",
      maidr.dotpad_asset_base_url = "https://intranet.example/dotpad/lib/"
    )
  )
  for (setting in settings) {
    with_dotpad_dir(dir, {
      previous <- options(setting)
      on.exit(options(previous), add = TRUE)
      html_doc <- maidr:::create_html_document(svg_fixture_dotpad(), use_cdn = FALSE)
      deps <- htmltools::htmlDependencies(html_doc)
      names <- vapply(deps, function(dep) dep$name, character(1))
      testthat::expect_false("dotpad-sdk" %in% names)
      rendered <- as.character(htmltools::renderDependencies(deps))
      testthat::expect_identical(
        lengths(regmatches(rendered, gregexpr("MAIDR_DOTPAD_ASSET_BASE_URL", rendered))),
        1L
      )
      testthat::expect_false(grepl(dotpad_lib_dir, rendered, fixed = TRUE))
    })
  }
})

test_that("a session that never downloaded the SDK is left alone", {
  with_dotpad_dir(tempfile(), {
    html_doc <- maidr:::create_html_document(svg_fixture_dotpad(), use_cdn = FALSE)
    names <- vapply(htmltools::htmlDependencies(html_doc), function(dep) dep$name, character(1))
    testthat::expect_identical(names, c("maidr-responsive", "maidr"))
  })
})
