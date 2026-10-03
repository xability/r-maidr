#' lattice Print Interception
#'
#' Printing a trellis object at the console -- typing its name, or calling
#' `print()` on it -- renders it in the MAIDR interactive viewer, as printing
#' a ggplot2 object does.
#'
#' The hook is lattice's own: `print.trellis()` draws with
#' `lattice.getOption("print.function")` when one is set, and with
#' `plot.trellis()` otherwise. Setting that option intercepts every print
#' without touching the S3 method table, and is undone by setting it back.
#' lattice is only in Suggests, so the option is set when lattice's
#' namespace loads (`.maidr_lattice_onload_hook()`), or at once when it is
#' already loaded.
#'
#' @name lattice_print_method
#' @keywords internal
NULL

# Internal state for the lattice print interception
.maidr_lattice_state <- new.env(parent = emptyenv())
.maidr_lattice_state$previous_print_function <- NULL
.maidr_lattice_state$registered <- FALSE
.maidr_lattice_state$busy <- FALSE
# The devices R opened by default for charts MAIDR drew natively; see
# remember_default_device().
.maidr_lattice_state$default_devices <- list()
# The screen a page lattice is still composing was moved to, off MAIDR's
# hidden device; see lattice_draw_on_screen().
.maidr_lattice_state$shared_page <- NULL
# TRUE from maidr_off() until maidr_on(): lattice loaded meanwhile keeps its
# own print function, as ggplot2 keeps its print method.
.maidr_lattice_state$switched_off <- FALSE

#' Set MAIDR's print function as lattice's print hook
#'
#' Stores whatever print function was set before -- `NULL` unless the user
#' or another package set one -- so a print MAIDR does not render is drawn
#' the way it would have been without MAIDR. Does nothing until lattice's
#' namespace is loaded; `.maidr_lattice_onload_hook()` calls it again then.
#'
#' Whether the hook is set is read from the option itself, not from a flag
#' kept here: the option goes when lattice's namespace is unloaded and
#' loaded again, and a user can set it to something else, and a flag would
#' then say the hook was set when it was not, so neither the onLoad hook
#' nor `maidr_on()` would set it again.
#'
#' @return NULL (invisible)
#' @keywords internal
register_lattice_print_method <- function() {
  .maidr_lattice_state$switched_off <- FALSE
  if (!isNamespaceLoaded("lattice")) {
    return(invisible(NULL))
  }

  current <- lattice::lattice.getOption("print.function")
  if (!identical(current, maidr_print_trellis)) {
    .maidr_lattice_state$previous_print_function <- current
    lattice::lattice.options(print.function = maidr_print_trellis)
  }
  .maidr_lattice_state$registered <- TRUE

  invisible(NULL)
}

#' Restore the print function lattice had before MAIDR set its own
#'
#' @return NULL (invisible)
#' @keywords internal
restore_lattice_print_method <- function() {
  .maidr_lattice_state$switched_off <- TRUE
  if (!isTRUE(.maidr_lattice_state$registered)) {
    return(invisible(NULL))
  }

  if (isNamespaceLoaded("lattice") &&
    identical(lattice::lattice.getOption("print.function"), maidr_print_trellis)) {
    lattice::lattice.options(
      print.function = .maidr_lattice_state$previous_print_function
    )
  }
  .maidr_lattice_state$registered <- FALSE

  invisible(NULL)
}

#' Set MAIDR's lattice print hook when lattice's namespace loads
#'
#' Named rather than anonymous so `.onUnload()` can remove exactly this
#' hook. After `maidr_off()` it sets nothing, and `maidr_on()` sets it
#' later. The options are not read here but at every print (see
#' [lattice_print_opens_viewer()]), as ggplot2's and Base R's are: read
#' here, a `maidr.lattice` or `maidr.auto_show` that was `FALSE` when
#' lattice loaded -- from an `.Rprofile`, or before a package that imports
#' lattice loaded it -- would keep lattice out of the viewer after it was
#' set back to `TRUE`.
#'
#' @param ... Ignored; passed by `setHook()`.
#' @return NULL (invisible)
#' @keywords internal
.maidr_lattice_onload_hook <- function(...) {
  if (!isTRUE(.maidr_lattice_state$switched_off)) {
    tryCatch(register_lattice_print_method(), error = function(e) NULL)
  }
  invisible(NULL)
}

#' MAIDR's print function for trellis objects
#'
#' Renders a printed trellis object in the MAIDR viewer when the print is a
#' reader asking to see a chart, and draws it the way lattice would have
#' otherwise. See [lattice_print_opens_viewer()] for which prints those are.
#' An unsupported chart is drawn natively. One that is read but cannot be
#' exported opens in the viewer as a static image, with a warning, as it does
#' from `show()`: [build_interactive_svg()] turns the failure into the
#' picture. It is drawn natively when fallback is off, which hands that
#' error to this hook, and when the viewer cannot be opened.
#'
#' @param x A trellis object
#' @param ... Arguments `print()` was given, passed to lattice when the chart
#'   is drawn natively
#' @return `x`, invisibly
#' @keywords internal
maidr_print_trellis <- function(x, ...) {
  # A chart a document prints is drawn by lattice on the chunk's device,
  # which is marked, so the plot hook does not take the figure for the
  # chunk's Base R chart.
  in_knit <- isTRUE(getOption("knitr.in.progress")) && is_lattice_enabled() &&
    !isTRUE(.maidr_lattice_state$busy)
  if (in_knit) {
    ensure_knitr_integration()
    on.exit(mark_device_foreign_drawing(), add = TRUE)
  }
  if (!lattice_print_opens_viewer(list(...), x$plot.args)) {
    return(print_trellis_natively(x, ...))
  }

  # Rendering draws the chart, which must not come back through here.
  .maidr_lattice_state$busy <- TRUE
  on.exit(.maidr_lattice_state$busy <- FALSE, add = TRUE)

  # The packets a print asks for -- `?packet.panel.default`'s way to print a
  # later page -- are the ones read, as `plot.trellis()` would draw them.
  shown <- x
  packet_panel <- lattice_print_arguments(list(...))[["packet.panel"]]
  if (!is.null(packet_panel)) {
    shown$plot.args[["packet.panel"]] <- packet_panel
  }

  orchestrator <- tryCatch(
    get_global_registry()$get_adapter("lattice")$create_orchestrator(shown),
    error = function(e) NULL
  )
  supported <- !is.null(orchestrator) &&
    !isTRUE(tryCatch(orchestrator$should_fallback(), error = function(e) TRUE))
  rendered <- supported && tryCatch(
    {
      display_html(create_maidr_html(shown, orchestrator = orchestrator))
      TRUE
    },
    error = function(e) FALSE
  )
  if (!rendered) {
    # Drawn as any print left to lattice is -- on a screen rather than in
    # MAIDR's hidden device, see lattice_draw_on_screen() -- and no longer a
    # drawing MAIDR makes while it renders.
    .maidr_lattice_state$busy <- FALSE
    return(print_trellis_natively(x, ...))
  }

  invisible(x)
}

#' Whether a print of a trellis object should open the MAIDR viewer
#'
#' Every print of a trellis object reaches the hook, and most of them are not
#' a reader asking to see a chart. Each of these is drawn natively:
#'
#' * a composition -- `print(p, split = , more = TRUE)`, `position =`,
#'   `newpage = FALSE`, `draw.in =`, by name, partial name or place (see
#'   [lattice_print_arguments()]), or carried in the chart's `plot.args` --
#'   places the chart on a page other charts share, which is lattice's own
#'   idiom for arranging several;
#' * a print onto a device that is not a screen: a file the user opened with
#'   `pdf()` or `png()` expects the chart in the file, and `grid.grabExpr()`
#'   or `ggplotify::as.grob()` expect it on their own off-screen device;
#' * a print while knitr is running, which is `knit_print.trellis()`'s to
#'   make accessible, or inside a Shiny render, which is `render_maidr()`'s;
#' * a print outside an interactive session, where there is no viewer to open;
#' * a print MAIDR makes while it renders, and any print after `maidr_off()`
#'   or under `options(maidr.lattice = FALSE)`.
#'
#' @param args The arguments `print()` was given besides the object.
#' @param stored The object's `plot.args`, which `plot.trellis()` draws
#'   with in place of any argument `print()` was not given.
#' @return `TRUE` when the print should open the viewer.
#' @keywords internal
lattice_print_opens_viewer <- function(args, stored = NULL) {
  # A print lattice will refuse is lattice's to refuse, with its own error.
  args <- lattice_drawing_arguments(args, stored)
  if (is.null(args)) {
    return(FALSE)
  }

  composing <- !is.null(args[["position"]]) ||
    !is.null(args[["split"]]) ||
    isTRUE(args[["more"]]) ||
    identical(args[["newpage"]], FALSE) ||
    !is.null(args[["draw.in"]])

  !composing &&
    !isTRUE(.maidr_lattice_state$busy) &&
    is_lattice_enabled() &&
    drawn_at_console() &&
    screen_device_is_current()
}

#' Whether a chart drawn now is drawn at the console
#'
#' In an interactive session, and neither while knitr runs, which makes the
#' chart a chunk's figure, nor inside a Shiny render, which draws it for its
#' output.
#'
#' @return `TRUE` for a chart drawn at the console.
#' @keywords internal
drawn_at_console <- function() {
  session_is_interactive() &&
    !isTRUE(getOption("knitr.in.progress")) &&
    is.null(shiny::getDefaultReactiveDomain())
}

#' The arguments of a print, named as lattice's drawer matches them
#'
#' `print()` passes a trellis object's arguments on as they were written,
#' and `plot.trellis()` matches them as R matches any call: by name, by a
#' partial name, or by position. `print(p, c(0, 0, 0.5, 1))` and
#' `print(p, pos = c(0, 0, 0.5, 1))` place the chart exactly as
#' `print(p, position = c(0, 0, 0.5, 1))` does, and read by their names
#' alone they would open the viewer in the middle of a composition.
#'
#' @param args The arguments `print()` was given besides the object.
#' @return The arguments named as `plot.trellis()` matches them, or `NULL`
#'   when they do not match it at all.
#' @keywords internal
lattice_print_arguments <- function(args) {
  drawer <- utils::getS3method("plot", "trellis")
  call <- as.call(c(list(quote(plot_trellis), quote(x)), args))
  matched <- tryCatch(
    match.call(drawer, call, expand.dots = FALSE),
    error = function(e) NULL
  )
  if (is.null(matched)) {
    return(NULL)
  }
  as.list(matched)[-1L]
}

#' The arguments a trellis object is drawn with
#'
#' A chart can carry its place on a shared page in its `plot.args`, set by
#' `xyplot(plot.args = )` or `update()`. `plot.trellis()` takes an argument
#' from there only by its exact name and only when the call did not give
#' it, so they are added after the call's own are matched, never matched by
#' place or partial name themselves.
#'
#' @param args The arguments `print()` or `plot()` was given besides the
#'   object.
#' @param stored The object's `plot.args`.
#' @return The arguments named as `plot.trellis()` draws with them, or
#'   `NULL` when the call's own do not match it at all.
#' @keywords internal
lattice_drawing_arguments <- function(args, stored = NULL) {
  args <- lattice_print_arguments(args)
  if (is.null(args)) {
    return(NULL)
  }
  stored <- as.list(stored)
  c(args, stored[setdiff(names(stored), c("", names(args)))])
}

#' Whether this R session is interactive
#'
#' A wrapper for [interactive()], which tests cannot otherwise change.
#'
#' @return `TRUE` in an interactive session.
#' @keywords internal
session_is_interactive <- function() {
  interactive()
}

#' Whether a chart printed now would be drawn on a screen
#'
#' No device open counts, since printing would open the default screen
#' device, and so does MAIDR's own hidden device, which only Base R
#' recording opens. Otherwise the current device has to be one R knows as
#' interactive, or one of the IDE devices R does not list: RStudio's, and
#' httpgd's, which VS Code uses. Anything else -- `pdf()`, `png()`,
#' `svglite()`, the off-screen device `grid.grabExpr()` opens -- is a
#' destination the caller chose for the drawing.
#'
#' @return `TRUE` when the current device is a screen.
#' @keywords internal
screen_device_is_current <- function() {
  device <- grDevices::dev.cur()
  if (device == 1L || maidr_hidden_device_is_current()) {
    return(TRUE)
  }
  # A device R opened by default for a chart MAIDR drew natively. In a
  # session with no display that is pdf() on Rplots.pdf: a device the reader
  # never chose, standing where the screen would be, so it counts as the
  # screen no device open counted as.
  current <- current_device_identity()
  if (any(vapply(.maidr_lattice_state$default_devices, identical, logical(1), current))) {
    return(TRUE)
  }
  names(device) %in% c(
    grDevices::deviceIsInteractive(), "RStudioGD", "httpgd", "unigd"
  )
}

#' Whether the current device is MAIDR's hidden device, and not its number
#'
#' [is_maidr_temp_device()] compares device numbers, and R gives a closed
#' device's number to the next device opened: after `dev.off()` closes the
#' hidden device, a `pdf("chart.pdf")`, `svglite()` or `ragg::agg_png()`
#' opened next, or the `pdf(NULL)` that `grid.grabExpr()` opens, has its
#' number, and a chart printed there would open the viewer and leave the
#' file or the grob without it. The hidden device is always a `pdf()` opened
#' on a temporary file, and R has recorded a pdf device's file in
#' `.Devices` since 3.2.0, so it is the device whose recorded file is that
#' one. A device that records no file -- svglite's, ragg's, `pdf(NULL)` --
#' is not it.
#'
#' @return `TRUE` when the current device is MAIDR's hidden device.
#' @keywords internal
maidr_hidden_device_is_current <- function() {
  if (!is_maidr_temp_device()) {
    return(FALSE)
  }
  devices <- get(".Devices", envir = baseenv())
  path <- attr(devices[[grDevices::dev.cur()]], "filepath")
  hidden <- .maidr_patching_env$.temp_device_file
  !is.null(path) && !is.null(hidden) &&
    identical(
      normalizePath(path, mustWork = FALSE),
      normalizePath(hidden, mustWork = FALSE)
    )
}

#' Draw a trellis object the way lattice would without MAIDR
#'
#' With the print function lattice's `print()` would call if MAIDR had not
#' set its own -- the one set now, or while MAIDR's is set, the one set
#' before it -- or with `plot.trellis()`, lattice's own drawer, when there
#' is none. Never with `print()`, which would come back through the hook,
#' and never with a bare `plot()`: inside this namespace that is MAIDR's
#' recording wrapper for Base R's `plot()`.
#'
#' The option is read each time rather than the function stored when MAIDR
#' set its hook: after `maidr_off()` that function is only a record of what
#' was set once, and the user may have set another since.
#'
#' @param x A trellis object
#' @param ... Passed to the drawing function
#' @return `x`, invisibly
#' @keywords internal
print_trellis_natively <- function(x, ...) {
  draw <- lattice::lattice.getOption("print.function")
  if (identical(draw, maidr_print_trellis)) {
    draw <- .maidr_lattice_state$previous_print_function
  }
  if (!is.function(draw)) {
    draw <- utils::getS3method("plot", "trellis")
  }
  draw_on_default_device(lattice_draw_on_screen(x, ..., .draw = draw))
  invisible(x)
}

#' Draw a trellis object on a screen rather than on MAIDR's hidden device
#'
#' MAIDR's hidden device is current from the first Base R call it records
#' until `show()`, and counts as a screen only because it kept one from
#' opening: a chart lattice draws there goes into a temporary file nobody
#' sees, which `show()` then deletes. So a chart drawn there at the console
#' ([drawn_at_console()]) is drawn on the screen lattice would have drawn it
#' on instead: the one MAIDR opened last, as plain R draws every chart on
#' one screen ([use_default_device()]), with the settings the reader made
#' ([lattice_carry_reader_settings()]). The charts that join its page with
#' `more = TRUE` follow it there, and go to a new screen should that one
#' have been closed before the page was finished. The hidden device is made
#' current again for the Base R chart it holds. A chart drawn into a page
#' made on the hidden device itself (`draw.in`, or `newpage = FALSE` with no
#' page being composed) stays there, with that page and its viewports, as do
#' the charts that join it, and so does one MAIDR draws while it renders.
#'
#' @param x A trellis object
#' @param ... The arguments of the print or `plot()` call besides the object
#' @param .draw The function that draws it: lattice's print function, or
#'   Base R's `plot()`
#' @return What `.draw` returns, with its visibility
#' @keywords internal
lattice_draw_on_screen <- function(x, ..., .draw) {
  if (!maidr_hidden_device_is_current() || isTRUE(.maidr_lattice_state$busy) ||
    !drawn_at_console()) {
    return(.draw(x, ...))
  }
  # Arguments lattice refuses are lattice's to report, from the device the
  # call was made on.
  args <- lattice_drawing_arguments(list(...), x$plot.args)
  if (is.null(args)) {
    return(.draw(x, ...))
  }
  page_open <- lattice_page_open()
  page <- .maidr_lattice_state$shared_page
  here <- current_device_identity()
  # A page made on the hidden device itself -- drawn into with `draw.in`, or
  # with `newpage = FALSE` -- stays there with its viewports, and so do the
  # charts that join it. Remembered, it is told apart from a page whose
  # screen is gone: lattice keeps one record of a page being composed, for
  # every device, and it outlives the device the page is on.
  if (!is.null(args[["draw.in"]]) || (!page_open && identical(args[["newpage"]], FALSE)) ||
    (page_open && identical(page, here))) {
    drawn <- withVisible(.draw(x, ...))
    .maidr_lattice_state$shared_page <- if (lattice_page_open()) here
    return(if (drawn$visible) drawn$value else invisible(drawn$value))
  }

  x <- lattice_carry_reader_settings(x)
  recording <- grDevices::dev.cur()
  on.exit(
    if (recording %in% grDevices::dev.list()) grDevices::dev.set(recording),
    add = TRUE
  )
  if (page_open) {
    if (!is.null(page) && page$number %in% grDevices::dev.list()) {
      grDevices::dev.set(page$number)
    }
    # R gives a closed device's number to the next one opened, so the page's
    # screen is known by more than its number. A page whose screen is gone
    # goes on a new one, which starts blank, as it would without MAIDR.
    if (!identical(current_device_identity(), page)) {
      open_default_device()
    }
  } else {
    use_default_device()
  }
  drawn <- withVisible(.draw(x, ...))
  .maidr_lattice_state$shared_page <- if (lattice_page_open()) {
    current_device_identity()
  }
  if (drawn$visible) drawn$value else invisible(drawn$value)
}

#' Make the screen MAIDR opened last current, or open one
#'
#' Plain R draws every chart on one screen, each new page replacing the
#' last, so the default device MAIDR opened last that is still open is used
#' again, known by its identity ([remember_default_device()]). A new one is
#' opened only when none is left.
#'
#' @return NULL (invisible)
#' @keywords internal
use_default_device <- function() {
  open <- grDevices::dev.list()
  for (kept in rev(.maidr_lattice_state$default_devices)) {
    if (kept$number %in% open) {
      grDevices::dev.set(kept$number)
      if (identical(current_device_identity(), kept)) {
        return(invisible(NULL))
      }
    }
  }
  open_default_device()
}

#' Open R's default device for a chart MAIDR draws natively
#'
#' The device the chart would have gone to at the console without MAIDR, and
#' one the reader never chose, so it is remembered as their screen
#' ([remember_default_device()]).
#'
#' @return NULL (invisible)
#' @keywords internal
open_default_device <- function() {
  before <- grDevices::dev.list()
  grDevices::dev.new()
  # Only a device dev.new() opened: RStudio Server allows one device of its
  # own, and refusing a second, leaves the one current before -- MAIDR's
  # hidden device, say -- current.
  if (!identical(grDevices::dev.list(), before)) {
    remember_default_device()
  }
}

#' Draw natively, remembering the device R opens when none is open
#'
#' With no device open, drawing opens R's default device, which stays
#' current: `pdf()` on `Rplots.pdf` in a session with no display, or an
#' IDE's own `pdf(NULL)`. The reader chose no file, so it is remembered as
#' their screen ([remember_default_device()]).
#'
#' @param drawing The drawing, evaluated here.
#' @return What `drawing` evaluates to, with its visibility
#' @keywords internal
draw_on_default_device <- function(drawing) {
  none_open <- grDevices::dev.cur() == 1L
  on.exit(if (none_open) remember_default_device(), add = TRUE)
  drawn <- withVisible(drawing)
  if (drawn$visible) drawn$value else invisible(drawn$value)
}

#' Remember the current device as one R opened by default
#'
#' [screen_device_is_current()] counts it as the reader's screen. It is kept
#' by [current_device_identity()], with a mark set on the device itself: R
#' gives a closed device's number to the next device opened, and a `pdf()`
#' the reader opens, or the `pdf(NULL)` `grid.grabExpr()` opens, can have the
#' number, name and file of one since closed, but not the mark. `err` is a
#' graphical parameter R keeps for each device and documents as unimplemented,
#' so setting it draws nothing; a device opened later starts at `0`.
#'
#' @return NULL (invisible)
#' @keywords internal
remember_default_device <- function() {
  if (grDevices::dev.cur() == 1L) {
    return(invisible(NULL))
  }
  graphics::par(err = -1L)
  device <- current_device_identity()
  others <- Filter(
    function(kept) kept$number != device$number,
    .maidr_lattice_state$default_devices
  )
  .maidr_lattice_state$default_devices <- c(others, list(device))
  invisible(NULL)
}

#' The current device, told apart from a later one given its number
#'
#' R gives a closed device's number to the next device opened, so the
#' number is kept with the device's name and, for a file device, the file
#' `.Devices` records. Those three are all a `pdf()` opened on R's default
#' file once the default device is closed has too, so `marked` is kept as
#' well: whether the device carries the mark [remember_default_device()]
#' sets on a device R opened by default.
#'
#' @return A list: `number`, `name`, `path` (`NULL` for no file) and
#'   `marked`.
#' @keywords internal
current_device_identity <- function() {
  device <- grDevices::dev.cur()
  list(
    number = unname(device),
    name = names(device),
    path = attr(get(".Devices", envir = baseenv())[[device]], "filepath"),
    marked = identical(graphics::par("err"), -1L)
  )
}
