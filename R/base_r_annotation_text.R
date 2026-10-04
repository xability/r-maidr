#' The text Base R draws for a chart's annotations
#'
#' R draws a title, an axis title, a margin text or a tick label given as
#' almost anything: `title()`, `mtext()`, `text()` and `axis()` turn a
#' classed value to text with `as.character()` (`as.graphicsAnnot()`), and
#' the C code that draws turns whatever else it is handed to text, a number
#' to fifteen significant digits, as `as.character()` does. A missing value
#' is left out, and a title of several values is drawn a line for each.
#'
#' gridGraphics, which draws a Base R chart again for maidr, accepts less:
#' it stops on a title that is a number, a logical, a vector of more than one
#' value or a list with graphical parameters ("Unrecognised text argument
#' type"), and draws a missing margin text or tick label as "NA". The
#' functions here hand it the text R drew.
#'
#' @name base_r_annotation_text
#' @keywords internal
#' @noRd
NULL

#' The text of one `title()` argument, and the parameters it carries
#'
#' As R's own `GetTextArg()` reads `main`, `sub`, `xlab` or `ylab`: a call
#' stays a call, an expression an expression, and anything else is text, as
#' `as.character()` makes it. A list holds the text as its unnamed element
#' (its first, when no element is named) and may carry `cex`, `col` and
#' `font` for it, as `title(main = list("Speed", font = 4))` does.
#'
#' @param value The argument, as `title()` passed it on
#' @param cex,col,font The text's own size, colour and font, from `par()`
#' @return A list: `text` (NULL when there is none), `cex`, `col`, `font`
#' @keywords internal
#' @noRd
base_r_title_text <- function(value, cex, col, font) {
  as_text <- function(x) {
    if (length(x) == 0) {
      return(NULL)
    }
    if (is.language(x)) x else as.character(x)
  }
  if (!is.list(value)) {
    return(list(text = as_text(value), cex = cex, col = col, font = font))
  }

  text <- if (is.null(names(value)) && length(value) > 0) as_text(value[[1]])
  for (i in seq_along(names(value))) {
    item <- value[[i]]
    key <- names(value)[[i]]
    if (identical(key, "cex")) {
      size <- suppressWarnings(as.numeric(item)[1])
      if (is.finite(size)) cex <- size
    } else if (identical(key, "col")) {
      if (!all(is.na(item))) col <- item
    } else if (identical(key, "font")) {
      if (!is.na(item[1])) font <- item
    } else {
      text <- as_text(item)
    }
  }
  list(text = text, cex = cex, col = col, font = font)
}

#' A recorded Base R drawing, its annotations the text R drew
#'
#' gridGraphics echoes a drawing from its display list, where each title,
#' margin text and axis holds the value its function was given. A title that
#' is not one string or call is drawn again as R drew it
#' (`base_r_title_as_drawn()`), a missing margin text is left blank, as R
#' left it, and an axis's logical `labels` is the one R read. The missing
#' tick labels R leaves out are taken out after the echo
#' ([thin_axis_labels()]), since R also leaves them out of its spacing.
#'
#' @param recording The drawing, from [grDevices::recordPlot()], recorded on
#'   a page of `size`
#' @param size The page, a named numeric vector, `width` and `height`, in
#'   inches
#' @return The recording, each of its annotations one gridGraphics draws
#' @keywords internal
#' @noRd
base_r_echoable_recording <- function(recording, size) {
  entries <- as.list(recording[[1]])
  if (length(entries) == 0) {
    return(recording)
  }
  pieces <- lapply(seq_along(entries), function(i) {
    entry <- entries[[i]]
    operation <- tryCatch(entry[[2]][[1]]$name, error = function(e) NULL)
    if (identical(operation, "C_title")) {
      return(base_r_echoable_title(recording, i, size))
    }
    if (identical(operation, "C_mtext")) {
      return(list(base_r_echoable_mtext(entry)))
    }
    if (identical(operation, "C_axis")) {
      return(list(base_r_echoable_axis(entry)))
    }
    list(entry)
  })
  echoable <- do.call(c, pieces)
  if (!identical(echoable, entries)) {
    recording[[1]] <- as.pairlist(echoable)
  }
  recording
}

#' A recorded `title()`, as entries gridGraphics draws as R drew it
#'
#' gridGraphics draws a title that is one string or a call. Another value of
#' length one is handed to it as the string R drew, and one of length zero
#' as no title, which is what R drew. A title of several values, or given as
#' a list, is drawn again as R drew it (`base_r_title_as_drawn()`).
#'
#' @param recording The recorded drawing
#' @param i The index of the `title()` entry in its display list
#' @param size The page the drawing was recorded on
#' @return A list of display-list entries
#' @keywords internal
#' @noRd
base_r_echoable_title <- function(recording, i, size) {
  entry <- recording[[1]][[i]]
  args <- as.list(entry[[2]])
  texts <- args[2:5]
  one_value <- vapply(
    texts,
    function(text) is.null(text) || is.language(text) || (is.atomic(text) && length(text) <= 1),
    logical(1)
  )
  if (!all(one_value)) {
    return(base_r_title_as_drawn(recording, i, size))
  }
  args[2:5] <- lapply(texts, function(text) {
    base_r_first_expression(base_r_title_text(text, NA, NA, NA)$text)
  })
  if (identical(args, as.list(entry[[2]]))) {
    return(list(entry))
  }
  entry[[2]] <- as.pairlist(args)
  list(entry)
}

#' The expression R draws of a title given as several
#'
#' R draws the first expression of a title given as several; gridGraphics
#' stops on them.
#'
#' @param text A title's text
#' @return The text, an expression vector cut to its first expression
#' @keywords internal
#' @noRd
base_r_first_expression <- function(text) {
  if (is.expression(text) && length(text) > 1) text[1] else text
}

#' A recorded `mtext()`, its missing values left blank
#'
#' R draws nothing for a missing value of `mtext()`'s text, where
#' gridGraphics draws "NA". A blank keeps each value's place against `at`
#' and `line`.
#'
#' @param entry The display-list entry
#' @return The entry
#' @keywords internal
#' @noRd
base_r_echoable_mtext <- function(entry) {
  text <- entry[[2]][[2]]
  if (is.language(text) || !is.atomic(text) || !anyNA(text)) {
    return(entry)
  }
  args <- as.list(entry[[2]])
  text <- as.character(text)
  text[is.na(text)] <- ""
  args[[2]] <- text
  entry[[2]] <- as.pairlist(args)
  entry
}

#' A recorded `axis()`, its logical `labels` the one R reads
#'
#' R reads `labels` given as logicals by the first: `TRUE` labels the ticks
#' as it would unasked, and `FALSE` or `NA` draws no labels. gridGraphics
#' stops on any but one `TRUE` or `FALSE`.
#'
#' @param entry The display-list entry
#' @return The entry
#' @keywords internal
#' @noRd
base_r_echoable_axis <- function(entry) {
  labels <- entry[[2]][[4]]
  if (!is.logical(labels) || identical(labels, TRUE) || identical(labels, FALSE)) {
    return(entry)
  }
  args <- as.list(entry[[2]])
  args[[4]] <- length(labels) == 0 || isTRUE(labels[[1]])
  entry[[2]] <- as.pairlist(args)
  entry
}

#' A `title()` gridGraphics cannot echo, drawn again as R drew it
#'
#' R draws the values of a title of several values a line apart: `main`
#' centred on the line it would draw one value on, `xlab` from that line
#' outwards and `ylab` from it inwards; `sub` draws them all on its line.
#' The page is drawn up to the title again, which gives `par()` as R had it
#' there, and each value is drawn with `mtext()` where and as `title()` drew
#' it, from the same calculation (R's `C_title()`), so the entries recorded
#' are R's own. A title of one value given as a list is drawn with
#' `title()`, its parameters passed as `cex.main` and the like.
#'
#' @param recording The recorded drawing
#' @param i The index of the `title()` entry in its display list
#' @param size The page the drawing was recorded on
#' @return A list of display-list entries
#' @keywords internal
#' @noRd
base_r_title_as_drawn <- function(recording, i, size) {
  current <- grDevices::dev.cur()
  grDevices::pdf(NULL, width = size[["width"]], height = size[["height"]])
  device <- grDevices::dev.cur()
  on.exit(
    {
      grDevices::dev.off(device)
      if (current > 1) grDevices::dev.set(current)
    },
    add = TRUE
  )
  grDevices::dev.control("enable")
  before <- recording
  before[1] <- list(as.pairlist(as.list(recording[[1]])[seq_len(i - 1)]))
  grDevices::replayPlot(before)
  drawn <- length(grDevices::recordPlot()[[1]])

  args <- as.list(recording[[1]][[i]][[2]])
  line <- suppressWarnings(as.numeric(args[[6]])[1])
  outer <- isTRUE(as.logical(args[[7]])[1])
  inline <- args[-(1:7)]
  cex <- graphics::par("cex")
  pars <- graphics::par()
  pars[names(inline)] <- inline
  if (!is.finite(line)) line <- NA_real_

  for (which in c("main", "sub", "xlab", "ylab")) {
    suffix <- switch(which, main = "main", sub = "sub", "lab")
    text <- base_r_title_text(
      args[[match(which, c("main", "sub", "xlab", "ylab")) + 1]],
      cex = pars[[paste0("cex.", suffix)]],
      col = pars[[paste0("col.", suffix)]],
      font = pars[[paste0("font.", suffix)]]
    )
    if (is.null(text$text)) {
      next
    }
    if (is.language(text$text) || length(text$text) == 1) {
      own <- stats::setNames(
        list(base_r_first_expression(text$text), line, outer, text$cex, text$col, text$font),
        c(which, "line", "outer", paste0(c("cex.", "col.", "font."), suffix))
      )
      do.call(graphics::title, c(own, inline[!names(inline) %in% names(own)]))
      next
    }
    n <- length(text$text)
    steps <- seq_len(n) - 1
    at_line <- switch(which,
      main = 0.5 * (n - 1) + (if (is.na(line)) {
        0.5 * (if (outer) pars$oma[3] else pars$mar[3])
      } else {
        line
      }) - steps - pars$ylbias / pars$mex,
      sub = rep(if (is.na(line)) pars$mgp[1] + 1 else line, n),
      xlab = (if (is.na(line)) pars$mgp[1] else line) + steps,
      ylab = (if (is.na(line)) pars$mgp[1] else line) - steps
    )
    drawn_values <- !is.na(text$text)
    if (!any(drawn_values)) {
      next
    }
    own <- list(
      text = text$text[drawn_values],
      side = switch(which, main = 3, sub = 1, xlab = 1, ylab = 2),
      line = at_line[drawn_values],
      outer = outer,
      adj = pars$adj,
      padj = if (which == "main" && is.na(line)) 0.5 else 0,
      cex = cex * text$cex,
      col = text$col,
      font = text$font,
      las = 0
    )
    keep <- !names(inline) %in% c(names(own), names(formals(graphics::mtext)))
    do.call(graphics::mtext, c(own, inline[keep]))
  }

  entries <- as.list(grDevices::recordPlot()[[1]])
  entries[seq_along(entries) > drawn]
}
