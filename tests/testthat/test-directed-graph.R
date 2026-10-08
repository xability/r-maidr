# A ggraph drawing of a directed graph is read as the graph.
#
# `ggraph()` draws a graph as an edge layer of its own geoms
# (`geom_edge_link()` and siblings) and a node layer of points over the
# layout. The edge geoms matched no branch of the adapter, so the chart fell
# back to a static image; and points alone say only where the layout put each
# node. For a directed graph the edge layers are now skipped and the node
# layer is a `directed_graph`, built from the igraph object ggraph keeps on
# the layout: one node per vertex, each naming what feeds it.

skip_slow_file_on_cran()

skip_unless_ggraph <- function() {
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("ggraph")
  testthat::skip_if_not_installed("igraph")
}

pipeline <- function(directed = TRUE) {
  graph <- igraph::graph_from_edgelist(
    rbind(
      c("load", "clean"), c("clean", "features"), c("clean", "labels"),
      c("features", "train"), c("labels", "train")
    ),
    directed = directed
  )
  igraph::V(graph)$stage <- c("io", "prep", "prep", "prep", "fit")
  graph
}

drawn <- function(graph = pipeline()) {
  ggraph::ggraph(graph, layout = "sugiyama") +
    ggraph::geom_edge_link() +
    ggraph::geom_node_point() +
    ggraph::geom_node_text(ggplot2::aes(label = name))
}

detected_types <- function(plot) {
  adapter <- maidr:::Ggplot2Adapter$new()
  unname(vapply(
    plot$layers, function(l) adapter$detect_layer_type(l, plot), character(1)
  ))
}

processed <- function(plot, index = 2) {
  built <- ggplot2::ggplot_build(plot)
  processor <- maidr:::Ggplot2DirectedGraphLayerProcessor$new(
    list(index = index, type = "directed_graph")
  )
  processor$process(plot, built$layout, built, ggplot2::ggplotGrob(plot))
}


test_that("a directed ggraph skips its edges and reads its nodes as the graph", {
  skip_unless_ggraph()

  testthat::expect_identical(
    detected_types(drawn()), c("skip", "directed_graph", "skip")
  )
})

test_that("each node names what feeds it, with its own attributes", {
  skip_unless_ggraph()

  result <- processed(drawn())
  nodes <- stats::setNames(
    result$data, vapply(result$data, function(n) n$id, character(1))
  )

  testthat::expect_identical(result$type, "directed_graph")
  testthat::expect_identical(
    names(nodes), c("load", "clean", "features", "labels", "train")
  )
  testthat::expect_length(nodes$load$inputs, 0L)
  testthat::expect_identical(unlist(nodes$clean$inputs), "load")
  testthat::expect_setequal(unlist(nodes$train$inputs), c("features", "labels"))
  testthat::expect_identical(nodes$train$attributes, list(stage = "fit"))
  testthat::expect_identical(result$axes$x$label, "Node")
})

test_that("each node has a selector naming its own point", {
  skip_unless_ggraph()

  selectors <- unlist(processed(drawn())$selectors)
  testthat::expect_length(selectors, 5L)
  testthat::expect_match(selectors[[1]], "> use:nth-of-type\\(1\\)$")
  testthat::expect_match(selectors[[5]], "> use:nth-of-type\\(5\\)$")
})

test_that("an unnamed graph is named by vertex index", {
  skip_unless_ggraph()

  graph <- igraph::make_graph(c(1, 2, 2, 3), directed = TRUE)
  plot <- ggraph::ggraph(graph, layout = "sugiyama") +
    ggraph::geom_edge_link() +
    ggraph::geom_node_point()
  result <- processed(plot)
  testthat::expect_identical(
    vapply(result$data, function(n) n$id, character(1)), c("1", "2", "3")
  )
  testthat::expect_identical(unlist(result$data[[3]]$inputs), "2")
})

test_that("an undirected ggraph keeps the reading it had", {
  skip_unless_ggraph()

  types <- detected_types(drawn(pipeline(directed = FALSE)))
  testthat::expect_false("directed_graph" %in% types)
})

test_that("a filtered node layer is not claimed", {
  skip_unless_ggraph()

  plot <- ggraph::ggraph(pipeline(), layout = "sugiyama") +
    ggraph::geom_edge_link() +
    ggraph::geom_node_point(ggplot2::aes(filter = stage == "prep"))
  testthat::expect_false("directed_graph" %in% detected_types(plot))
})

test_that("a chart renders as a directed graph and its selectors resolve", {
  skip_if_no_render()
  skip_unless_ggraph()

  html <- rendered(drawn())
  testthat::expect_false(fell_back(html))
  layers <- layers_from(html)
  testthat::expect_length(layers, 1L)
  layer <- layers[[1]]
  testthat::expect_identical(layer$type, "directed_graph")
  testthat::expect_length(layer$data, 5L)
  testthat::expect_length(layer$selectors, 5L)
  group <- sub(" > use.*$", "", unlist(layer$selectors)[[1]])
  id <- gsub("\\\\", "", sub("^g#", "", group))
  testthat::expect_true(grepl(paste0('id="', id, '"'), html, fixed = TRUE))
})

test_that("the processor is registered for the type", {
  factory <- maidr:::Ggplot2ProcessorFactory$new()
  testthat::expect_true("directed_graph" %in% factory$get_supported_types())
})

# Base R: igraph's own `plot()` of a directed graph. `plot.igraph()` draws
# every circle vertex with one `symbols()` call, in vertex order, so the
# n-th circle of that group is the n-th node.

base_r_graph_layers <- function(plot_fun) {
  testthat::skip_if_not_installed("igraph")
  testthat::skip_if_not_installed("jsonlite")
  maidr:::clear_all_device_storage()
  file <- tempfile(fileext = ".html")
  grDevices::pdf(NULL)
  on.exit(
    {
      grDevices::dev.off()
      unlink(file)
      maidr:::clear_all_device_storage()
    },
    add = TRUE
  )
  plot_fun()
  suppressWarnings(suppressMessages(maidr::save_html(plot = NULL, file = file)))
  html <- paste(readLines(file, warn = FALSE), collapse = "\n")
  list(html = html, layers = layers_from(html))
}

test_that("Base R plot() of a directed igraph reads its nodes, one circle each", {
  result <- base_r_graph_layers(function() {
    set.seed(1)
    plot(pipeline(), main = "Pipeline")
  })

  testthat::expect_false(fell_back(result$html))
  testthat::expect_length(result$layers, 1L)
  layer <- result$layers[[1]]
  testthat::expect_identical(layer$type, "directed_graph")
  testthat::expect_identical(layer$title, "Pipeline")
  nodes <- stats::setNames(layer$data, vapply(layer$data, `[[`, "", "id"))
  testthat::expect_identical(
    names(nodes), c("load", "clean", "features", "labels", "train")
  )
  testthat::expect_identical(unlist(nodes$train$inputs), c("features", "labels"))
  testthat::expect_identical(nodes$train$attributes$stage, "fit")

  testthat::expect_length(layer$selectors, 5L)
  testthat::expect_match(
    unlist(layer$selectors)[[5]], "symbols-circle-1\\.1 > circle:nth-of-type(5)",
    fixed = TRUE
  )
  circles <- regmatches(
    result$html,
    gregexpr('<circle id="graphics-plot-1-symbols-circle-1\\.1\\.[0-9]+"', result$html)
  )[[1]]
  testthat::expect_length(unique(circles), 5L)
})

test_that("Base R plot() of an undirected or reshaped igraph is a picture", {
  undirected <- base_r_graph_layers(function() plot(pipeline(directed = FALSE)))
  testthat::expect_true(fell_back(undirected$html))

  squares <- base_r_graph_layers(function() {
    plot(pipeline(), vertex.shape = "square")
  })
  testthat::expect_true(fell_back(squares$html))
})

test_that("the Base R processor is registered for the type", {
  factory <- maidr:::BaseRProcessorFactory$new()
  testthat::expect_true("directed_graph" %in% factory$get_supported_types())
})
