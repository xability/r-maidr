# A scatter is a volcano or a Manhattan plot when its author says so.
#
# maidr.js reads both through a threshold -- how many points clear it, a
# rotor over those, each point announced by its gene or SNP and its
# chromosome -- and deliberately has no default for it. So nothing here is
# detected: `maidr_volcano()` and `maidr_manhattan()` are declarations
# carried by geoms of their own, which also let `label` and `region` columns
# through `ggplot_build()`, and which take the threshold as an argument that
# has no default either. An undeclared `geom_point()` keeps its reading.

skip_slow_file_on_cran()

volcano_genes <- function() {
  data.frame(
    gene = c("TP53", "MYC", "EGFR", "BRCA1", "KRAS", "PTEN", "GAPDH"),
    regulation = c("up", "down", "up", "ns", "ns", "down", "ns"),
    log2fc = c(2.8, -3.1, 1.6, -0.4, 0.3, -2.2, 0.1),
    padj = c(1e-8, 1e-6, 0.02, 0.4, 0.7, 1e-4, 0.9)
  )
}

volcano_snps <- function() {
  data.frame(
    snp = paste0("rs", 1:8),
    chr = rep(c("chr1", "chr2"), each = 4),
    pos = c(1, 2, 3, 4, 6, 7, 8, 9),
    p = c(0.3, 2e-9, 0.01, 0.6, 0.05, 0.8, 4e-10, 0.2)
  )
}

# Built at top level: inside a closure the bare column names in `aes()` read
# as undefined globals to static analysis.
volcano_xy <- ggplot2::aes(x = log2fc, y = -log10(padj))
volcano_identity <- ggplot2::aes(label = gene, region = regulation)
manhattan_xy <- ggplot2::aes(x = pos, y = -log10(p))
manhattan_identity <- ggplot2::aes(label = snp, region = chr)

volcano_plot <- function(...) {
  ggplot2::ggplot(volcano_genes(), volcano_xy) +
    maidr_volcano(volcano_identity, significance = -log10(0.05), ...)
}

volcano_detected <- function(plot, index = 1) {
  maidr:::Ggplot2Adapter$new()$detect_layer_type(plot$layers[[index]], plot)
}

volcano_processed <- function(plot, index = 1, type = "volcano") {
  built <- ggplot2::ggplot_build(plot)
  processor <- maidr:::Ggplot2VolcanoLayerProcessor$new(
    list(index = index, type = type)
  )
  processor$process(plot, built$layout, built, ggplot2::ggplotGrob(plot))
}

field_of <- function(points, name) {
  vapply(points, function(p) if (is.null(p[[name]])) NA_character_ else p[[name]], "")
}


# ---------------------------------------------------------------------------
# Registration and the bundle
# ---------------------------------------------------------------------------

test_that("the processor is registered for both types", {
  factory <- maidr:::Ggplot2ProcessorFactory$new()
  for (type in c("volcano", "manhattan")) {
    testthat::expect_true(type %in% factory$get_supported_types())
    testthat::expect_s3_class(
      factory$create_processor(type, list(index = 1, type = type)),
      "Ggplot2VolcanoLayerProcessor"
    )
  }
})

test_that("the bundled maidr.js builds both traces", {
  # Emitted to a bundle without the trace, an unknown type is fatal to the
  # page rather than declined, so the declarations are only safe while the
  # bundle carries both. A bundle refresh that dropped them fails here.
  bundle <- system.file(
    "htmlwidgets", "lib", paste0("maidr-", maidr:::MAIDR_VERSION), "maidr.js",
    package = "maidr"
  )
  testthat::skip_if_not(nzchar(bundle) && file.exists(bundle))
  source <- paste(readLines(bundle, warn = FALSE), collapse = "\n")
  # The trace types enum, whatever quotes the minifier chose.
  testthat::expect_true(grepl("VOLCANO=[\"'`]volcano[\"'`]", source))
  testthat::expect_true(grepl("MANHATTAN=[\"'`]manhattan[\"'`]", source))
  testthat::expect_true(grepl("significanceDirection", source, fixed = TRUE))
})

test_that("both join the layer types whose selector is one string", {
  testthat::expect_true(
    all(c("volcano", "manhattan") %in% maidr:::SINGLE_SELECTOR_LAYER_TYPES)
  )
})


# ---------------------------------------------------------------------------
# The declaration
# ---------------------------------------------------------------------------

test_that("an undeclared scatter keeps the point reading", {
  testthat::skip_if_not_installed("ggplot2")
  plot <- ggplot2::ggplot(volcano_genes(), volcano_xy) + ggplot2::geom_point()
  testthat::expect_identical(volcano_detected(plot), "point")
})

test_that("the declarations draw what geom_point() draws", {
  testthat::skip_if_not_installed("ggplot2")

  plain <- ggplot2::ggplot(volcano_genes(), volcano_xy) + ggplot2::geom_point()
  declared <- volcano_plot()
  testthat::expect_identical(volcano_detected(declared), "volcano")
  testthat::expect_s3_class(declared$layers[[1]]$geom, "GeomPoint")
  testthat::expect_equal(
    ggplot2::layer_data(declared)[, c("x", "y")],
    ggplot2::layer_data(plain)[, c("x", "y")]
  )

  manhattan <- ggplot2::ggplot(volcano_snps(), manhattan_xy) +
    maidr_manhattan(manhattan_identity, significance = -log10(5e-8))
  testthat::expect_identical(volcano_detected(manhattan), "manhattan")
  testthat::expect_s3_class(manhattan$layers[[1]]$geom, "GeomPoint")
})

test_that("the threshold has no default and is checked when declared", {
  testthat::skip_if_not_installed("ggplot2")

  testthat::expect_error(maidr_volcano(), "`significance`")
  testthat::expect_error(maidr_manhattan(), "`significance`")
  testthat::expect_error(maidr_volcano(significance = "1.3"), "`significance`")
  testthat::expect_error(maidr_volcano(significance = c(1, 2)), "`significance`")
  testthat::expect_error(maidr_volcano(significance = NA_real_), "`significance`")
  testthat::expect_error(
    maidr_volcano(significance = 1.3, effect = -1), "`effect`"
  )
  testthat::expect_error(
    maidr_volcano(significance = 1.3, direction = "sideways")
  )
})

test_that("label and region are accepted without a warning", {
  testthat::skip_if_not_installed("ggplot2")
  testthat::expect_no_warning(ggplot2::ggplot_build(volcano_plot()))
})


# ---------------------------------------------------------------------------
# What the layer emits
# ---------------------------------------------------------------------------

test_that("each point carries its label and group, and the layer its threshold", {
  testthat::skip_if_not_installed("ggplot2")

  result <- volcano_processed(volcano_plot(effect = 1))
  testthat::expect_identical(result$type, "volcano")

  genes <- volcano_genes()
  testthat::expect_length(result$data, nrow(genes))
  testthat::expect_identical(field_of(result$data, "label"), genes$gene)
  testthat::expect_identical(field_of(result$data, "group"), genes$regulation)
  testthat::expect_equal(
    vapply(result$data, function(p) p$y, numeric(1)),
    -log10(genes$padj)
  )

  testthat::expect_identical(
    result$thresholdOptions,
    list(
      significance = -log10(0.05),
      significanceDirection = "above",
      effect = 1
    )
  )
})

test_that("without effect or identities only what was declared is emitted", {
  testthat::skip_if_not_installed("ggplot2")

  plot <- ggplot2::ggplot(volcano_genes(), volcano_xy) +
    maidr_volcano(significance = 0.05, direction = "below")
  result <- volcano_processed(plot)

  testthat::expect_identical(
    result$thresholdOptions,
    list(significance = 0.05, significanceDirection = "below")
  )
  testthat::expect_null(result$data[[1]]$label)
  testthat::expect_null(result$data[[1]]$group)
})

test_that("a dropped row does not shift the names onto the wrong points", {
  testthat::skip_if_not_installed("ggplot2")

  genes <- volcano_genes()
  genes$log2fc[3] <- NA
  genes$gene[5] <- NA
  plot <- ggplot2::ggplot(genes, volcano_xy) +
    maidr_volcano(volcano_identity, significance = 1.3)
  result <- suppressWarnings(volcano_processed(plot))

  testthat::expect_length(result$data, nrow(genes) - 1L)
  kept <- genes[-3, ]
  testthat::expect_identical(
    field_of(result$data, "label"),
    kept$gene
  )
  testthat::expect_equal(
    vapply(result$data, function(p) p$x, numeric(1)),
    kept$log2fc
  )
})

test_that("a Manhattan layer names each SNP and its chromosome", {
  testthat::skip_if_not_installed("ggplot2")

  plot <- ggplot2::ggplot(volcano_snps(), manhattan_xy) +
    maidr_manhattan(manhattan_identity, significance = -log10(5e-8))
  result <- volcano_processed(plot, type = "manhattan")

  testthat::expect_identical(result$type, "manhattan")
  testthat::expect_identical(field_of(result$data, "label"), volcano_snps()$snp)
  testthat::expect_identical(field_of(result$data, "group"), volcano_snps()$chr)
  testthat::expect_identical(
    result$thresholdOptions,
    list(significance = -log10(5e-8), significanceDirection = "above")
  )
})


# ---------------------------------------------------------------------------
# The rendered payload
# ---------------------------------------------------------------------------

test_that("a declared volcano renders as one volcano layer with a string selector", {
  skip_if_no_render()
  testthat::skip_if_not_installed("xml2")

  plot <- volcano_plot(effect = 1) +
    ggplot2::geom_hline(yintercept = -log10(0.05), linetype = "dashed") +
    ggplot2::geom_vline(xintercept = c(-1, 1), linetype = "dashed")

  html <- rendered(plot)
  testthat::expect_false(fell_back(html))

  layers <- layers_from(html)
  # The threshold lines are reference lines and are skipped.
  testthat::expect_length(layers, 1L)
  layer <- layers[[1]]
  testthat::expect_identical(layer$type, "volcano")
  testthat::expect_identical(layer$thresholdOptions$significanceDirection, "above")
  testthat::expect_equal(layer$thresholdOptions$significance, -log10(0.05))
  testthat::expect_equal(layer$thresholdOptions$effect, 1)
  testthat::expect_identical(layer$data[[2]]$label, "MYC")
  testthat::expect_identical(layer$data[[2]]$group, "down")

  # One string, naming one drawn mark per point.
  testthat::expect_true(is.character(layer$selectors))
  testthat::expect_length(layer$selectors, 1L)
  id <- gsub("\\\\", "", sub("^g#(.*) > use$", "\\1", layer$selectors))
  svg <- xml2::read_html(html)
  marks <- xml2::xml_find_all(svg, sprintf("//*[@id='%s']/use", id))
  testthat::expect_length(marks, nrow(volcano_genes()))
})

test_that("a faceted Manhattan plot names the points of each panel", {
  skip_if_no_render()

  snps <- volcano_snps()
  plot <- ggplot2::ggplot(snps, manhattan_xy) +
    maidr_manhattan(manhattan_identity, significance = 8) +
    ggplot2::facet_wrap(~chr, scales = "free_x")

  schema <- schema_from(rendered(plot))
  testthat::expect_false(is.null(schema))
  cells <- unlist(schema$subplots, recursive = FALSE)
  testthat::expect_length(cells, 2L)
  for (cell in cells) {
    layer <- cell$layers[[1]]
    testthat::expect_identical(layer$type, "manhattan")
    chromosomes <- unique(field_of(layer$data, "group"))
    testthat::expect_length(chromosomes, 1L)
    testthat::expect_identical(
      field_of(layer$data, "label"),
      snps$snp[snps$chr == chromosomes]
    )
    testthat::expect_equal(layer$thresholdOptions$significance, 8)
  }
})
