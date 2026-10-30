# A Base R page read as MAIDR data, and the titles of its panels and layers,
# for the tests of how a figure, its panels and its plots are titled.

#' The MAIDR data of the Base R page `draw` draws
base_r_figure <- function(draw) {
  grDevices::pdf(NULL)
  device_id <- grDevices::dev.cur()
  on.exit(
    {
      clear_base_r_device(device_id)
      grDevices::dev.off()
    },
    add = TRUE
  )
  clear_base_r_device(device_id)

  draw()
  maidr:::BaseRPlotOrchestrator$new(device_id)$generate_maidr_data()
}

#' The title of each subplot's first layer, row by row
panel_titles <- function(figure) {
  unlist(lapply(figure$subplots, function(row) {
    vapply(row, function(cell) {
      title <- cell$layers[[1]]$title
      if (is.null(title)) "" else title
    }, character(1))
  }))
}

#' The titles of each subplot's layers, row by row
layer_titles <- function(figure) {
  lapply(unlist(figure$subplots, recursive = FALSE), function(cell) {
    vapply(cell$layers, function(layer) {
      if (is.character(layer$title)) layer$title else ""
    }, character(1))
  })
}
