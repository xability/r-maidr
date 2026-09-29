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
# The device R opened by default when a chart was drawn natively with none
# open; see screen_device_is_current().
.maidr_lattice_state$default_device <- NULL
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
    # The print is a reader's at a screen, and MAIDR's hidden device only
    # counts as one because it kept the screen from opening: drawn there, the
    # chart would go into a temporary file nobody sees. A new device is the
    # screen lattice would have drawn it on, as show() opens for this chart;
    # the hidden device is made current again for the Base R chart it holds.
    if (maidr_hidden_device_is_current()) {
      recording <- grDevices::dev.cur()
      grDevices::dev.new()
      on.exit(
        if (recording %in% grDevices::dev.list()) grDevices::dev.set(recording),
        add = TRUE
      )
    }
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
  args <- lattice_print_arguments(args)
  if (is.null(args)) {
    return(FALSE)
  }
  # A chart can carry its place on a shared page in its `plot.args`, set by
  # `xyplot(plot.args = )` or `update()`. `plot.trellis()` takes an argument
  # from there only by its exact name and only when `print()` was not given
  # it, so they are added after the print's own are matched, never matched
  # by place or partial name themselves.
  stored <- as.list(stored)
  args <- c(args, stored[setdiff(names(stored), c("", names(args)))])

  composing <- !is.null(args[["position"]]) ||
    !is.null(args[["split"]]) ||
    isTRUE(args[["more"]]) ||
    identical(args[["newpage"]], FALSE) ||
    !is.null(args[["draw.in"]])

  !composing &&
    !isTRUE(.maidr_lattice_state$busy) &&
    is_lattice_enabled() &&
    session_is_interactive() &&
    !isTRUE(getOption("knitr.in.progress")) &&
    is.null(shiny::getDefaultReactiveDomain()) &&
    screen_device_is_current()
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
  # The device R opened by default when MAIDR drew a chart natively with
  # none open. In a session with no display that is pdf() on Rplots.pdf: a
  # device the reader never chose, standing where the screen would be, so
  # it counts as the screen no device open counted as.
  if (identical(current_device_identity(), .maidr_lattice_state$default_device)) {
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
  # With no device open, drawing opens R's default device, which stays
  # current; see screen_device_is_current().
  none_open <- grDevices::dev.cur() == 1L
  draw(x, ...)
  if (none_open && grDevices::dev.cur() != 1L) {
    .maidr_lattice_state$default_device <- current_device_identity()
  }
  invisible(x)
}

#' The current device, told apart from a later one given its number
#'
#' R gives a closed device's number to the next device opened, so the
#' number is kept with the device's name and, for a file device, the file
#' `.Devices` records.
#'
#' @return A list: `number`, `name` and `path` (`NULL` for no file).
#' @keywords internal
current_device_identity <- function() {
  device <- grDevices::dev.cur()
  list(
    number = unname(device),
    name = names(device),
    path = attr(get(".Devices", envir = baseenv())[[device]], "filepath")
  )
}
