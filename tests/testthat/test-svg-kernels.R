# The SVG rewrite's string helpers run in C++ (src/svg_kernels.cpp). The
# exported document is read by maidr.js and by every test that looks at
# it, so the C++ must write exactly what the R it replaced wrote. Each R
# original is kept below, verbatim, and every case compares the two on the
# same input: ordinary svglite output, and the malformed and non-finite
# inputs the R handled in its own particular way.

ref_svg_trim <- function(x) {
  sub("(\\.[0-9]*[1-9])0+$", "\\1", sub("\\.0+$", "", x))
}

ref_svg_fmt <- function(v) {
  ref_svg_trim(formatC(v, format = "f", digits = 2))
}

ref_svg_flip_points <- function(points, h) {
  parts <- strsplit(trimws(points), "[ ]+")
  lens <- lengths(parts)
  flat <- unlist(parts, use.names = FALSE)
  xy <- strsplit(flat, ",", fixed = TRUE)
  x <- ref_svg_trim(vapply(xy, `[`, "", 1L))
  y <- ref_svg_fmt(h - suppressWarnings(as.numeric(vapply(xy, `[`, "", 2L))))
  pairs <- paste0(x, ",", y)
  unname(vapply(
    split(pairs, rep(seq_along(points), lens)),
    paste, "", collapse = " "
  ))
}

ref_svg_flip_path <- function(d, h) {
  vapply(d, function(one) {
    tok <- strsplit(gsub("([MLZ])", " \\1 ", one), "[ ,]+")[[1]]
    tok <- tok[nzchar(tok)]
    out <- tok
    num <- grepl("^[0-9.-]", tok)
    out[num] <- ref_svg_trim(tok[num])
    i <- 1L
    while (i <= length(tok)) {
      if (tok[i] %in% c("M", "L")) {
        out[i + 2L] <- ref_svg_fmt(h - suppressWarnings(as.numeric(tok[i + 2L])))
        i <- i + 3L
      } else if (grepl("^[0-9.-]", tok[i])) {
        out[i + 1L] <- ref_svg_fmt(h - suppressWarnings(as.numeric(tok[i + 1L])))
        i <- i + 2L
      } else {
        i <- i + 1L
      }
    }
    paste(out, collapse = " ")
  }, character(1), USE.NAMES = FALSE)
}

ref_svg_attr <- function(lines, name) {
  key <- paste0(" ", name, "='")
  out <- rep(NA_character_, length(lines))
  has <- grepl(key, lines, fixed = TRUE)
  out[has] <- sub(
    paste0("^.*? ", name, "='([^']*)'.*$"), "\\1", lines[has], perl = TRUE
  )
  out
}

ref_svg_hex_to_rgb <- function(hex) {
  if (!length(hex)) {
    return(character(0))
  }
  paste0(
    "rgb(", strtoi(substr(hex, 2, 3), 16L), ",",
    strtoi(substr(hex, 4, 5), 16L), ",", strtoi(substr(hex, 6, 7), 16L), ")"
  )
}

ref_svg_style_attrs <- function(style, text, own = rep(NA_character_, length(style)),
                                line = logical(length(style))) {
  svg_gp_attr_map <- maidr:::svg_gp_attr_map
  svg_style_defaults <- maidr:::svg_style_defaults
  style[is.na(style)] <- ""
  key <- paste(as.integer(text), as.integer(line), own, style, sep = "\r")
  uniq <- !duplicated(key)
  conv <- vapply(which(uniq), function(i) {
    d <- trimws(strsplit(style[i], ";", fixed = TRUE)[[1]])
    d <- d[nzchar(d)]
    k <- trimws(sub(":.*$", "", d))
    v <- trimws(sub("^[^:]*:", "", d))
    keep <- k != "white-space"
    val <- stats::setNames(v[keep], k[keep])
    if (is.na(own[i])) {
      want <- union(names(val), c("fill", "stroke"))
    } else {
      set <- strsplit(own[i], ",", fixed = TRUE)[[1]]
      want <- unique(unlist(svg_gp_attr_map[intersect(set, names(svg_gp_attr_map))]))
      want <- c(want, intersect(names(val), "fill-rule"))
      if (text[i]) {
        want <- union(want, c("fill", "fill-opacity", "font-size", "font-family"))
      }
    }
    miss <- setdiff(want, names(val))
    val[miss] <- svg_style_defaults[miss]
    if (text[i]) {
      if ("fill" %in% miss) val[["fill"]] <- "#000000"
      if ("stroke" %in% want) {
        val[["stroke"]] <- val[["fill"]]
        val[["stroke-opacity"]] <- if (is.na(val["fill-opacity"])) "1" else val[["fill-opacity"]]
      }
    }
    val <- val[want]
    val <- val[!is.na(val)]
    if (line[i]) val[["fill"]] <- "none"
    hex <- grepl("^#[0-9A-Fa-f]{6}$", val)
    val[hex] <- ref_svg_hex_to_rgb(val[hex])
    val <- sub("^([0-9.]+)px$", "\\1", val)
    num <- grepl("^[0-9.]+$", val)
    val[num] <- ref_svg_trim(val[num])
    fam <- names(val) == "font-family"
    val[fam] <- maidr:::svg_font_stack(gsub("\"", "", val[fam], fixed = TRUE))
    if (!length(val)) {
      return("")
    }
    paste0(" ", names(val), '="', val, '"', collapse = "")
  }, character(1))
  conv[match(key, key[uniq])]
}

# Numbers as svglite writes them, and the awkward ones.
kernel_numbers <- function(n = 400) {
  set.seed(20260929)
  c(
    round(runif(n, -1000, 1000), sample(0:4, n, TRUE)),
    runif(n) * 10^sample(-6:12, n, TRUE),
    c(0, -0, 0.005, 0.015, 1.005, 2.675, -0.001, -0.005, 1e20, 123456789.125),
    c(NA, NaN, Inf, -Inf)
  )
}

test_that("svg_fmt() writes what formatC() and svg_trim() wrote", {
  v <- kernel_numbers()
  expect_identical(maidr:::svg_fmt(v), ref_svg_fmt(v))
  # formatC() pads a call's non-finite values to one width, so what a
  # value becomes depends on what it is formatted with.
  for (batch in list(NA_real_, NaN, Inf, -Inf, c(NA, 1), c(NA, -Inf, 2), c(NaN, NA), c(Inf, NA))) {
    expect_identical(maidr:::svg_fmt(batch), ref_svg_fmt(batch))
  }
  expect_identical(maidr:::svg_fmt(numeric(0)), ref_svg_fmt(numeric(0)))
  expect_identical(maidr:::svg_fmt(c(3L, NA, -7L)), ref_svg_fmt(c(3, NA, -7)))
})

test_that("svg_trim() drops trailing zeros as the regular expressions did", {
  x <- c(
    formatC(kernel_numbers(), format = "f", digits = 3),
    "1.50", "10", "10.0", "1.0", ".0", "0.000", "1.2.30", "1.00.0", "1.50.0",
    "abc", "", NA, "1e-05", "1.0e5", "-0.00", "100", "1.x0", "1.", "0.10",
    " 1.50", "1.50 "
  )
  expect_identical(maidr:::svg_trim(x), ref_svg_trim(x))
})

test_that("svg_attr() reads the first value of an attribute", {
  lines <- c(
    "<rect x='1.00' y='2' width='3.50' height='4'/>",
    "<circle cx='1' cy='2' r='3'/>",
    "<rect y='2'/>",
    "<rect x='1' x='2'/>",
    "<rect  x='open/>",
    "<text x='1'>x='nested'</text>",
    "x='no leading space'",
    "<text x='é☃'>é</text>",
    "",
    NA
  )
  for (name in c("x", "y", "cx", "r", "width", "height", "style")) {
    expect_identical(maidr:::svg_attr(lines, name), ref_svg_attr(lines, name))
  }
})

test_that("svg_flip_points() flips every y about the page height", {
  points <- c(
    "1,2 3,4", "  1.50,2.25   3,4  ", "", NA, "5", "5,", ",5", "1,2,3",
    "1\t2,3 4,5", "0.10,0.105 7.00,8.004", "1,x", "1,2  3,4 5,6"
  )
  for (h in c(0, 100, 432.5)) {
    expect_identical(maidr:::svg_flip_points(points, h), ref_svg_flip_points(points, h))
  }
  set.seed(1)
  long <- paste(
    paste0(formatC(runif(2000, 0, 500), format = "f", digits = 2), ",",
           formatC(runif(2000, 0, 500), format = "f", digits = 2)),
    collapse = " "
  )
  expect_identical(maidr:::svg_flip_points(long, 504), ref_svg_flip_points(long, 504))
  # One list with nothing in it, among others, shortens the result as
  # split() did.
  expect_identical(
    maidr:::svg_flip_points(c("1,2", "", "3,4"), 10),
    ref_svg_flip_points(c("1,2", "", "3,4"), 10)
  )
})

test_that("svg_flip_path() flips every y of an M/L/Z path", {
  d <- c(
    "M 1.00 2.00 L 3.50 4.25 Z", "M1,2L3,4Z", "M 1 2 3 4 5 6 Z", "M 1",
    "M 1 2 L", "", NA, "C 1 2", "M -1.50 -2 L .5 0.105", "M 1 x L 2 3",
    "Z Z", "M 1 2 L 3 4 M 5 6 L 7 8 Z"
  )
  for (h in c(0, 100, 432.5)) {
    expect_identical(maidr:::svg_flip_path(d, h), ref_svg_flip_path(d, h))
  }
})

test_that("svg_style_attrs() keeps what each shape's own gpar accounts for", {
  styles <- c(
    "stroke-width: 1.07; stroke: #FF0000; fill: #00ff00; stroke-linecap: butt;",
    "font-size: 8.80px; font-family: \"Liberation Sans\";",
    "font-size: 11.00px; fill: #4D4D4D; font-family: \"Liberation Serif\";",
    "font-family: \"Nonexistent Face\"; font-weight: bold;",
    "font-family: \"\";",
    "white-space: pre;", "", NA, ": x; fill: ;", "fill: #000000; fill: #111111;",
    "fill-rule: evenodd; fill: #123456;", "stroke-opacity: 0.50; fill-opacity: 0.25;",
    "stroke-dasharray: 4.00,4.00; stroke-width: 2.13;", "fill: none; stroke: #ABCDEF",
    "stroke-miterlimit: 10.00;", "fill: #12345G;", "no colon at all",
    "  fill :  #0000FF  ;  stroke:#FFFFFF  "
  )
  owns <- c(
    NA, "col,fill", "fontsize,cex", "", "lty", "alpha,lwd,bogus", ",col",
    "fontfamily,fontface", "col,col,fill", "NA", "lineend,linejoin,linemitre,font"
  )
  grid <- expand.grid(
    style = seq_along(styles), own = seq_along(owns), text = c(FALSE, TRUE),
    line = c(FALSE, TRUE)
  )
  style <- styles[grid$style]
  own <- owns[grid$own]
  expect_identical(
    maidr:::svg_style_attrs(style, grid$text, own, grid$line),
    ref_svg_style_attrs(style, grid$text, own, grid$line)
  )
  expect_identical(
    maidr:::svg_style_attrs(styles, rep(FALSE, length(styles))),
    ref_svg_style_attrs(styles, rep(FALSE, length(styles)))
  )
  expect_identical(maidr:::svg_style_attrs(character(0), logical(0)), character(0))
})
