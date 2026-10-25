# A layer `title` reaches maidr.js as one string or not at all. A processor
# that names no title leaves NULL in its layer, and jsonlite writes NULL as
# `{}`: maidr.js took that object for a title and failed on it, so `d`
# opened no description and the `L`, `T` label left the reader stuck in
# label mode.

test_that("layer_title_text keeps one string and drops what is not text", {
  testthat::expect_null(maidr:::layer_title_text(NULL))
  testthat::expect_null(maidr:::layer_title_text(list()))
  testthat::expect_null(maidr:::layer_title_text(NA))
  testthat::expect_null(maidr:::layer_title_text(NA_character_))
  testthat::expect_null(maidr:::layer_title_text(list(a = 1)))
  testthat::expect_identical(maidr:::layer_title_text("Sales"), "Sales")
  testthat::expect_identical(maidr:::layer_title_text(""), "")
  testthat::expect_identical(maidr:::layer_title_text(factor("setosa")), "setosa")
  testthat::expect_identical(maidr:::layer_title_text(2024), "2024")
  testthat::expect_identical(maidr:::layer_title_text(c("Sales", "by region")), "Sales by region")
})

test_that("maidr_data_json writes no empty-object layer title", {
  maidr_data <- list(
    id = "plot",
    title = "Figure",
    subplots = list(list(list(
      id = "cell",
      layers = list(
        list(id = 1, type = "box", title = NULL, data = list()),
        list(id = 2, type = "bar", title = "Layer", data = list()),
        list(id = 3, type = "line", title = factor("Level"), data = list())
      )
    )))
  )

  json <- as.character(maidr:::maidr_data_json(maidr_data))
  testthat::expect_false(grepl('"title":{}', json, fixed = TRUE))

  parsed <- jsonlite::fromJSON(json, simplifyVector = FALSE)
  layers <- parsed$subplots[[1]][[1]]$layers
  testthat::expect_false("title" %in% names(layers[[1]]))
  testthat::expect_identical(layers[[2]]$title, "Layer")
  testthat::expect_identical(layers[[3]]$title, "Level")
  testthat::expect_identical(parsed$title, "Figure")
})

test_that("layer_titles_as_text reads a flat list of cells too", {
  maidr_data <- list(
    id = "flat",
    subplots = list(
      list(id = "cell", layers = list(
        list(id = 1, type = "bar", title = NULL),
        list(id = 2, type = "bar", title = "Kept")
      ))
    )
  )

  layers <- maidr:::layer_titles_as_text(maidr_data)$subplots[[1]]$layers
  testthat::expect_false("title" %in% names(layers[[1]]))
  testthat::expect_identical(layers[[2]]$title, "Kept")
})

test_that("ggplot2 layers whose processors name no title carry none", {
  skip_if_no_render()

  plots <- list(
    box = ggplot2::ggplot(iris, ggplot2::aes(Species, Petal.Length)) +
      ggplot2::geom_boxplot(),
    point = ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) +
      ggplot2::geom_point(),
    tile = ggplot2::ggplot(
      expand.grid(x = c("a", "b"), y = c("c", "d")),
      ggplot2::aes(x, y, fill = seq_len(4))
    ) + ggplot2::geom_tile(),
    violin = ggplot2::ggplot(iris, ggplot2::aes(Species, Sepal.Width)) +
      ggplot2::geom_violin()
  )

  for (name in names(plots)) {
    html <- rendered(plots[[name]] + ggplot2::labs(title = "A titled chart"))
    testthat::expect_false(
      grepl("&quot;title&quot;:{}", html, fixed = TRUE),
      info = name
    )
    schema <- schema_from(html)
    testthat::expect_identical(schema$title, "A titled chart", info = name)
    for (row in schema$subplots) {
      for (cell in row) {
        for (layer in cell$layers) {
          title <- layer$title
          testthat::expect_true(
            is.null(title) || (is.character(title) && length(title) == 1),
            info = name
          )
        }
      }
    }
  }
})
