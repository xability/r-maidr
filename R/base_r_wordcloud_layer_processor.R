#' Base R Word Cloud Layer Processor
#'
#' @description
#' Reads a `wordcloud::wordcloud()` call as MAIDR's `word_cloud` layer: one
#' term and its weight per point.
#'
#' A word cloud is the chart that carries real data while being readable only
#' by eye --- each term's weight is drawn as glyph size and written down
#' nowhere on the page. Structurally it is a categorical label and a
#' magnitude, so the reading is a term and its number.
#'
#' @section What is read, and from where:
#' The **call's own arguments**, not the drawing. `wordcloud()` takes
#' `words` and `freq` directly, so the raw counts survive in the recorded
#' call and this layer announces occurrences rather than ratios.
#'
#' That is a real difference from the Python binding, which is worth stating
#' because the two look alike: `wordcloud.WordCloud` divides every frequency
#' by the largest and keeps only the ratio, so py-maidr can only announce a
#' relative frequency. Here the counts are present, so `Occurrences` is an
#' honest axis name.
#'
#' @section Why no selectors:
#' Measured on a three-term cloud through the package's own export
#' (`create_enhanced_svg()` over the orchestrator's gtable): the result
#' carries **no `id` attributes at all**, so there is no addressable element
#' per term --- nor any named grob to build a selector from, unlike the
#' `text` grob `lag.plot()` and `biplot()` write their labels as.
#'
#' `wordcloud()` draws each term with a bare `text()` at a rotation chosen by
#' `rot.per`, and nothing names those. So this layer emits no selectors and
#' the reading ships without a highlight, which the core supports:
#' `WordCloudTrace` returns no highlight rather than pairing the terms with
#' whatever else resolved.
#'
#' @keywords internal
NULL

#' `wordcloud()`'s own defaults, replicated so the reading matches the drawing
#'
#' Only the two that decide **which** terms are drawn. The rest --- `scale`,
#' `rot.per`, `colors` --- decide how they look, and a reading has nothing to
#' do with them.
#'
#' @keywords internal
.maidr_wordcloud_defaults <- list(min.freq = 3, max.words = Inf)


#' @title Base R Word Cloud Layer Processor
#'
#' @description
#' Turns a recorded `wordcloud::wordcloud()` call into a `word_cloud` layer.
#'
#' @keywords internal
#' @noRd
BaseRWordcloudLayerProcessor <- R6::R6Class(
  "BaseRWordcloudLayerProcessor",
  inherit = LayerProcessor,
  public = list(
    #' @description Read the call as a word cloud layer.
    #' @param plot Unused; kept for the processor interface.
    #' @param layout Unused; kept for the processor interface.
    #' @param built Unused; kept for the processor interface.
    #' @param gt Unused. The reading is of the call's arguments, not of the
    #'   drawing -- there is nothing in the gtable a term can be found by.
    #' @param grob_id Unused; kept for the processor interface.
    #' @param panel_id Unused; kept for the processor interface.
    #' @param panel_ctx Unused; kept for the processor interface.
    #' @param layer_info The recorded call, carrying `plot_call$args`.
    #' @return A layer list, or NULL when the call drew no readable term.
    process = function(plot,
                       layout,
                       built = NULL,
                       gt = NULL,
                       grob_id = NULL,
                       panel_id = NULL,
                       panel_ctx = NULL,
                       layer_info = NULL) {
      info <- if (!is.null(layer_info)) layer_info else self$layer_info
      terms <- private$terms(info$plot_call$args)
      if (is.null(terms)) {
        return(NULL)
      }

      list(
        type = "word_cloud",
        # No selectors: measured, the export carries no addressable element
        # per term. See the note on this file.
        data = lapply(
          seq_along(terms$words),
          function(i) list(x = terms$words[[i]], y = terms$freq[[i]])
        ),
        axes = build_axes(x = "Term", y = "Occurrences")
      )
    }
  ),
  private = list(
    #' The terms the call drew, with their counts, or NULL
    #'
    #' Replicates the two filters `wordcloud()` applies before drawing, so a
    #' term the chart left out is not announced:
    #'
    #' * `min.freq` (default 3) drops anything rarer. `wordcloud()` first
    #'   lowers it to 0 when it exceeds every frequency, which is what keeps
    #'   a cloud of rare terms from coming out empty; that rule is copied
    #'   rather than approximated.
    #' * `max.words` (default `Inf`) keeps the heaviest terms only.
    #'
    #' **The page-fit drop is not modelled, deliberately.** `wordcloud()`
    #' also abandons a term that will not fit in the space left, warning
    #' `"<word> could not be fit on page. It will not be plotted."`. Whether
    #' that happens depends on the device size and on a random layout, so it
    #' cannot be decided from the arguments. A term dropped that way is still
    #' announced here --- the author passed it, and R told them out loud that
    #' it was not drawn.
    terms = function(args) {
      # `wordcloud(w, f)` passes both by position; the recorder names dots
      # but leaves the dispatch arguments as written.
      xy <- resolve_xy_args(args)
      words <- args[["words"]] %||% xy$x
      freq <- args[["freq"]] %||% (if (is.null(args[["words"]])) xy$y else xy$x)
      if (is.null(words) || is.null(freq) || !length(words)) {
        return(NULL)
      }
      if (length(words) != length(freq)) {
        return(NULL)
      }

      words <- as.character(words)
      freq <- suppressWarnings(as.numeric(freq))
      keep <- !is.na(freq)
      words <- words[keep]
      freq <- freq[keep]
      if (!length(freq)) {
        return(NULL)
      }

      min_freq <- private$setting(args, "min.freq")
      # `wordcloud()`'s own rule, not a guard of ours: a threshold above
      # every frequency would draw nothing, so it drops to zero instead.
      if (min_freq > max(freq)) {
        min_freq <- 0
      }

      max_words <- private$setting(args, "max.words")
      if (is.finite(max_words) && length(freq) > max_words) {
        # `wordcloud()` ranks with `ties.method = "random"`, so which of two
        # equally frequent terms survives a cut between them is a coin flip
        # *in the chart*. Ranked deterministically here; the pair that
        # disagree can only be terms of the same weight, so the reading
        # differs from the drawing by which of two interchangeable labels it
        # names, never by a number.
        rank_desc <- rank(-freq, ties.method = "first")
        words <- words[rank_desc <= max_words]
        freq <- freq[rank_desc <= max_words]
      }

      drawn <- freq >= min_freq
      words <- words[drawn]
      freq <- freq[drawn]
      if (!length(words)) {
        return(NULL)
      }

      # Heaviest first. The core sorts again for navigation, so this is not
      # what makes the reading right -- it is what makes the emitted order
      # the order a reader is walked through, for a producer reading the
      # payload directly.
      by_weight <- order(freq, decreasing = TRUE)
      list(words = words[by_weight], freq = freq[by_weight])
    },

    #' One drawing setting, from the call or from `wordcloud()`'s default
    setting = function(args, name) {
      value <- args[[name]]
      if (is.null(value) || !length(value)) {
        return(.maidr_wordcloud_defaults[[name]])
      }
      value <- suppressWarnings(as.numeric(value)[[1]])
      if (is.na(value)) .maidr_wordcloud_defaults[[name]] else value
    }
  )
)
