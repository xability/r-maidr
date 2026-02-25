#' @name base-r-wrappers
#' @title Base R Graphics Function Wrappers
#'
#' @description
#' MAIDR wraps standard Base R graphics functions to intercept plot calls
#' and enable accessible, interactive visualizations. When the maidr package
#' is loaded, these wrappers automatically replace the standard functions
#' on the search path, recording plot data so that [show()] can render
#' accessible versions.
#'
#' The wrappers are transparent: they call the original graphics functions
#' and return the same results. When patching is disabled (via [maidr_off()]),
#' they pass through directly to the originals with no overhead.
#'
#' @param ... Arguments passed to the original graphics function.
#' @return Same as the original Base R function (invisibly when applicable).
#'
#' @details
#' These stub definitions are overwritten during package loading by the
#' actual wrapper implementations created in [initialize_base_r_patching()].
#' They exist here solely to generate the necessary NAMESPACE exports
#' via roxygen2.
#'
#' @seealso [show()] for displaying accessible plots, [maidr_on()],
#'   [maidr_off()] for controlling patching
#' @keywords internal
NULL

# --- HIGH-level plot creation functions ---

#' @rdname base-r-wrappers
#' @export
barplot <- function(...) graphics::barplot(...)

#' @rdname base-r-wrappers
#' @export
plot <- function(...) graphics::plot(...)

#' @rdname base-r-wrappers
#' @export
hist <- function(...) graphics::hist(...)

#' @rdname base-r-wrappers
#' @export
boxplot <- function(...) graphics::boxplot(...)

#' @rdname base-r-wrappers
#' @export
image <- function(...) graphics::image(...)

#' @rdname base-r-wrappers
#' @export
heatmap <- function(...) stats::heatmap(...)

#' @rdname base-r-wrappers
#' @export
contour <- function(...) graphics::contour(...)

#' @rdname base-r-wrappers
#' @export
matplot <- function(...) graphics::matplot(...)

#' @rdname base-r-wrappers
#' @export
curve <- function(...) graphics::curve(...)

#' @rdname base-r-wrappers
#' @export
dotchart <- function(...) graphics::dotchart(...)

#' @rdname base-r-wrappers
#' @export
stripchart <- function(...) graphics::stripchart(...)

#' @rdname base-r-wrappers
#' @export
stem <- function(...) graphics::stem(...)

#' @rdname base-r-wrappers
#' @export
pie <- function(...) graphics::pie(...)

#' @rdname base-r-wrappers
#' @export
mosaicplot <- function(...) graphics::mosaicplot(...)

#' @rdname base-r-wrappers
#' @export
assocplot <- function(...) graphics::assocplot(...)

#' @rdname base-r-wrappers
#' @export
pairs <- function(...) graphics::pairs(...)

#' @rdname base-r-wrappers
#' @export
coplot <- function(...) graphics::coplot(...)

# --- LOW-level drawing functions ---

#' @rdname base-r-wrappers
#' @export
lines <- function(...) graphics::lines(...)

#' @rdname base-r-wrappers
#' @export
points <- function(...) graphics::points(...)

#' @rdname base-r-wrappers
#' @export
text <- function(...) graphics::text(...)

#' @rdname base-r-wrappers
#' @export
mtext <- function(...) graphics::mtext(...)

#' @rdname base-r-wrappers
#' @export
abline <- function(...) graphics::abline(...)

#' @rdname base-r-wrappers
#' @export
segments <- function(...) graphics::segments(...)

#' @rdname base-r-wrappers
#' @export
arrows <- function(...) graphics::arrows(...)

#' @rdname base-r-wrappers
#' @export
polygon <- function(...) graphics::polygon(...)

#' @rdname base-r-wrappers
#' @export
rect <- function(...) graphics::rect(...)

#' @rdname base-r-wrappers
#' @export
symbols <- function(...) graphics::symbols(...)

#' @rdname base-r-wrappers
#' @export
legend <- function(...) graphics::legend(...)

#' @rdname base-r-wrappers
#' @export
axis <- function(...) graphics::axis(...)

#' @rdname base-r-wrappers
#' @export
title <- function(...) graphics::title(...)

#' @rdname base-r-wrappers
#' @export
grid <- function(...) graphics::grid(...)

# --- LAYOUT functions ---

#' @rdname base-r-wrappers
#' @export
par <- function(...) graphics::par(...)

#' @rdname base-r-wrappers
#' @export
layout <- function(...) graphics::layout(...)

#' @rdname base-r-wrappers
#' @export split.screen
split.screen <- function(...) graphics::split.screen(...)
