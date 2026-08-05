# Regression tests for render_maidr()'s handling of Base R plot calls.
#
# A Base R plotting call's return value says nothing about whether it drew:
# plot() returns NULL invisibly, barplot() returns the bar midpoints, hist()
# returns the histogram object. render_maidr() used to branch on that value,
# which meant plot() rendered a silent blank and barplot()/hist() errored the
# output slot. Only ggplot worked.
#
# These exercise the real reactive path via shiny::testServer().

rendered_nothing <- function(value) {
  # htmlwidgets serialises "render nothing" as a payload whose x is null
  is.null(value) || grepl('^\\{"x":null', as.character(value))
}

setup_clean_shiny <- function() {
  maidr:::clear_all_device_storage()
}

test_that("render_maidr() renders a Base R plot() that returns NULL", {
  testthat::skip_if_not_installed("shiny")
  setup_clean_shiny()

  server <- function(input, output, session) {
    output$p <- render_maidr({
      plot(1:10, (1:10)^2)
    })
  }

  shiny::testServer(server, {
    testthat::expect_false(rendered_nothing(output$p))
  })

  setup_clean_shiny()
})

test_that("render_maidr() renders barplot(), whose return value is not a plot", {
  testthat::skip_if_not_installed("shiny")
  setup_clean_shiny()

  # barplot() returns the bar midpoints; passing that to maidr_widget()
  # used to error the output slot with "Input must be a ggplot object"
  server <- function(input, output, session) {
    output$p <- render_maidr({
      barplot(c(a = 1, b = 2, c = 3))
    })
  }

  shiny::testServer(server, {
    testthat::expect_false(rendered_nothing(output$p))
  })

  setup_clean_shiny()
})

test_that("render_maidr() renders hist()", {
  testthat::skip_if_not_installed("shiny")
  setup_clean_shiny()

  server <- function(input, output, session) {
    output$p <- render_maidr({
      hist(c(1, 2, 2, 3, 3, 3, 4))
    })
  }

  shiny::testServer(server, {
    testthat::expect_false(rendered_nothing(output$p))
  })

  setup_clean_shiny()
})

test_that("render_maidr() keeps a low-level overlay with its plot", {
  testthat::skip_if_not_installed("shiny")
  setup_clean_shiny()

  server <- function(input, output, session) {
    output$p <- render_maidr({
      plot(1:5, 1:5)
      abline(h = 2)
    })
  }

  shiny::testServer(server, {
    testthat::expect_false(rendered_nothing(output$p))
  })

  setup_clean_shiny()
})

test_that("render_maidr() still renders a ggplot", {
  testthat::skip_if_not_installed("shiny")
  testthat::skip_if_not_installed("ggplot2")
  setup_clean_shiny()

  server <- function(input, output, session) {
    output$p <- render_maidr({
      ggplot2::ggplot(mtcars, ggplot2::aes(factor(cyl))) + ggplot2::geom_bar()
    })
  }

  shiny::testServer(server, {
    testthat::expect_false(rendered_nothing(output$p))
  })

  setup_clean_shiny()
})

test_that("render_maidr() renders nothing for an empty reactive", {
  testthat::skip_if_not_installed("shiny")
  setup_clean_shiny()

  server <- function(input, output, session) {
    output$p <- render_maidr({
      NULL
    })
  }

  shiny::testServer(server, {
    testthat::expect_true(rendered_nothing(output$p))
  })

  setup_clean_shiny()
})

test_that("render_maidr() does not re-render a previous plot when a reactive goes empty", {
  testthat::skip_if_not_installed("shiny")
  setup_clean_shiny()

  # The tempting fix -- "if the result is NULL but the device has calls,
  # render those" -- reads a device that still holds the PREVIOUS
  # evaluation's calls, so an empty reactive would redraw the old plot.
  # Only calls recorded during THIS evaluation count.
  server <- function(input, output, session) {
    output$p <- render_maidr({
      if (isTRUE(input$go)) plot(1:10, 1:10) else NULL
    })
  }

  shiny::testServer(server, {
    session$setInputs(go = TRUE)
    testthat::expect_false(rendered_nothing(output$p))

    session$setInputs(go = FALSE)
    testthat::expect_true(rendered_nothing(output$p))
  })

  setup_clean_shiny()
})

test_that("render_maidr() still errors for a non-plot value", {
  testthat::skip_if_not_installed("shiny")
  setup_clean_shiny()

  server <- function(input, output, session) {
    output$p <- render_maidr({
      42
    })
  }

  shiny::testServer(server, {
    testthat::expect_error(output$p, "Input must be a ggplot object")
  })

  setup_clean_shiny()
})
