# maidr Package Architecture Documentation

## Overview

The `maidr` package is an R package that converts ggplot2 plots (currently focused on bar plots) into interactive, accessible HTML/SVG with JavaScript/CSS integration. It follows a **Factory Pattern** architecture for extensibility to other plot types.

## Table of Contents

1. [Core Architecture](#core-architecture)
2. [Factory Pattern Implementation](#factory-pattern-implementation)
3. [Data Flow Architecture](#data-flow-architecture)
4. [Library Dependencies](#library-dependencies)
5. [File Structure](#file-structure)
6. [Code Flow for Bar Plots](#code-flow-for-bar-plots)
7. [Extensibility Guide](#extensibility-guide)
8. [SVG Generation Options](#svg-generation-options)

## Core Architecture

### Design Principles

1. **Factory Pattern**: Centralized plot type detection and processing
2. **Separation of Concerns**: Bar-specific logic in `bar.R`, generic logic in factory files
3. **Extensibility**: Easy to add new plot types by extending factory switches
4. **Data Flow**: Clean progression from ggplot → processed data → SVG → HTML
5. **Accessibility**: Structured data embedded in SVG for screen readers

### Main Components

```
┌─────────────────────────────────────────────────────────────┐
│                    maidr Package Architecture              │
├─────────────────────────────────────────────────────────────┤
│ 1. Entry Points (maidr.R)                                 │
│    - maidr() - Main user function                         │
│    - save_html() - Save to file                           │
│    - create_maidr_html() - Core orchestration             │
├─────────────────────────────────────────────────────────────┤
│ 2. Factory Pattern (plot_factory.R, grob_factory.R)       │
│    - create_plot_processor() - Main processor factory     │
│    - extract_layer_ids() - Layer ID extraction factory    │
│    - make_selector() - CSS selector factory               │
│    - detect_plot_type() - Plot type detection factory     │
├─────────────────────────────────────────────────────────────┤
│ 3. Bar-Specific Logic (bar.R)                             │
│    - bar_plot_data() - Bar data constructor               │
│    - extract_bar_data() - Extract bar data from ggplot    │
│    - make_bar_selectors() - Create bar selectors          │
│    - find_bar_grobs() - Find bar grobs in gtable          │
├─────────────────────────────────────────────────────────────┤
│ 4. SVG/HTML Utilities (svg_utils.R, html_dependencies.R)  │
│    - create_enhanced_svg() - SVG generation with data     │
│    - add_maidr_data_to_svg() - Inject JSON into SVG       │
│    - create_html_document() - HTML assembly               │
│    - maidr_html_dependencies() - JS/CSS dependencies      │
└─────────────────────────────────────────────────────────────┘
```

## Factory Pattern Implementation

### 1. Plot Type Detection (`detect_plot_type()`)

```r
detect_plot_type(plot) {
  # Extract geom classes from plot layers
  geom_types <- sapply(plot$layers, function(layer) {
    class(layer$geom)[1]
  })
  
  # Determine plot type based on geoms
  determine_plot_type_from_geoms(geom_types) {
    if (any(geom_types %in% c("GeomBar", "GeomCol"))) {
      return("bar")
    }
    return(NA_character_)
  }
}
```

### 2. Plot Processor Creation (`create_plot_processor()`)

```r
create_plot_processor(plot, plot_type = NULL, ...) {
  if (is.null(plot_type)) {
    plot_type <- detect_plot_type(plot)  # Returns "bar"
  }
  
  # Factory switch based on plot type
  switch(plot_type,
    "bar" = process_bar_plot(plot, ...),
    stop("Unsupported plot type: ", plot_type)
  )
}
```

### 3. Bar Plot Processing (`process_bar_plot()`)

```r
process_bar_plot(plot, ...) {
  # Extract layout information (title, axes labels)
  layout <- extract_layout(plot)
  
  # Extract bar-specific data
  data <- extract_bar_data(plot)
  
  # Create bar-specific selectors
  selectors <- make_bar_selectors(plot)
  
  # Return bar_plot_data object
  bar_plot_data(data = data, layout = layout, selectors = selectors)
}
```

### 4. Layer Processing Factories

#### Layer ID Extraction (`extract_layer_ids()`)
```r
extract_layer_ids(gt, plot_type) {
  switch(plot_type,
    "bar" = extract_bar_layer_ids_from_gtable(gt),
    character(0)
  )
}
```

#### Selector Creation (`make_selector()`)
```r
make_selector(plot_type, layer_id) {
  switch(plot_type,
    "bar" = make_bar_selector(layer_id)
  )
}
```

## Data Flow Architecture

### Complete Flow Diagram

```
User Input: ggplot2 bar plot
    ↓
maidr() - Main entry point
    ↓
create_maidr_html() - Orchestration
    ↓
create_plot_processor() - Factory pattern
    ↓
detect_plot_type() → "bar"
    ↓
process_bar_plot() - Bar-specific processing
    ↓
extract_bar_data() + make_bar_selectors() - Bar data extraction
    ↓
extract_layer_ids() + make_selector() - Layer processing
    ↓
create_maidr_data() - Data structure assembly
    ↓
create_enhanced_svg() - SVG generation with maidr data
    ↓
create_html_document() - HTML assembly with dependencies
    ↓
display_html() / save_html_document() - Output
    ↓
Interactive HTML with embedded SVG + JS/CSS
```

### Detailed Step-by-Step Flow

#### Step 1: Entry Point (`maidr()`)
```r
maidr(plot, file = NULL, open = TRUE, ...) {
  html_doc <- create_maidr_html(plot, ...)
  
  if (is.null(file)) {
    if (open) display_html(html_doc)
    invisible(NULL)
  } else {
    save_html_document(html_doc, file)
    if (open) display_html_file(file)
    invisible(file)
  }
}
```

#### Step 2: Main Orchestration (`create_maidr_html()`)
```r
create_maidr_html(plot, ...) {
  # Use the factory pattern to process the plot
  plot_processor <- create_plot_processor(plot, ...)
  
  # Extract layout information
  layout <- extract_layout(plot)
  
  # Convert to gtable for SVG generation
  gt <- ggplot2::ggplotGrob(plot)
  
  # Get plot type from processor
  plot_type <- get_plot_type(plot_processor)
  layer_ids <- extract_layer_ids(gt, plot_type)
  
  # Create layers structure from the processed plot data
  layers <- create_layer_structure(layer_ids, plot_processor, layout)
  
  # Final assembly
  maidr_data <- create_maidr_data(layers)
  svg_content <- create_enhanced_svg(gt, maidr_data, ...)
  html_doc <- create_html_document(svg_content)
}
```

#### Step 3: Bar-Specific Data Extraction (`bar.R`)

##### Bar Data Extraction (`extract_bar_data()`)
```r
extract_bar_data(plot) {
  # Build plot to access internal data
  built <- ggplot2::ggplot_build(plot)
  
  # Find bar layers (GeomBar or GeomCol)
  bar_layers <- which(sapply(plot$layers, function(layer) {
    inherits(layer$geom, "GeomBar") || inherits(layer$geom, "GeomCol")
  }))
  
  # Extract data from first bar layer
  built_data <- built$data[[bar_layers[1]]]
  
  # Process each data point
  for (j in seq_len(nrow(built_data))) {
    point <- list()
    point$x <- get_x_value(built_data, j, original_data)
    point$y <- built_data$y[j] || built_data$count[j]
    point$fill <- built_data$fill[j]  # if exists
    data_points[[j]] <- point
  }
  
  return(data_points)
}
```

##### Bar Selector Creation (`make_bar_selectors()`)
```r
make_bar_selectors(plot) {
  # Convert to gtable
  gt <- ggplot2::ggplotGrob(plot)
  
  # Find bar grobs (rectangular graphical objects)
  grobs <- find_bar_grobs(gt)
  
  # Create selectors for each bar
  for (grob in grobs) {
    layer_id <- extract_layer_id_from_grob(grob)
    selector <- make_bar_selector(layer_id)
    selectors[[length(selectors) + 1]] <- selector
  }
}
```

#### Step 4: SVG Generation & Enhancement

##### Enhanced SVG Creation (`create_enhanced_svg()`)
```r
create_enhanced_svg(gt, maidr_data, ...) {
  # Create temporary SVG file
  svg_file <- tempfile(fileext = ".svg")
  
  # Draw gtable to SVG
  grid.newpage()
  grid.draw(gt)
  grid.export(svg_file, exportCoords = "none", exportMappings = "inline")
  
  # Read SVG content
  svg_content <- readLines(svg_file, warn = FALSE)
  
  # Add maidr data to SVG
  svg_content <- add_maidr_data_to_svg(svg_content, maidr_data)
  
  return(svg_content)
}
```

##### Maidr Data Injection (`add_maidr_data_to_svg()`)
```r
add_maidr_data_to_svg(svg_content, maidr_data) {
  # Convert maidr data to JSON
  maidr_json <- jsonlite::toJSON(maidr_data, auto_unbox = TRUE)
  
  # Parse SVG as XML
  svg_doc <- xml2::read_xml(svg_text)
  
  # Add maidr-data attribute to SVG root
  xml2::xml_attr(svg_doc, "maidr-data") <- maidr_json
  
  # Convert back to character vector
  svg_content <- strsplit(as.character(svg_doc), "\n")[[1]]
}
```

#### Step 5: HTML Document Creation

##### HTML Document Assembly (`create_html_document()`)
```r
create_html_document(svg_content) {
  # Create HTML structure
  html_doc <- htmltools::tags$html(
    htmltools::tags$head(),
    htmltools::tags$body(
      htmltools::HTML(paste(svg_content, collapse = "\n"))
    )
  )
  
  # Attach maidr dependencies (JS/CSS from CDN)
  html_doc <- htmltools::attachDependencies(
    html_doc,
    maidr_html_dependencies()
  )
}
```

## Library Dependencies

### Core Dependencies (DESCRIPTION Imports)

| Library | Primary Purpose | Key Function |
|---------|----------------|--------------|
| **gridSVG** | **GTable to SVG conversion** | `grid.export()` |
| **htmltools** | **JS/CSS injection & HTML creation** | `attachDependencies()` |
| **jsonlite** | **Data serialization for JS** | `toJSON()` |
| **xml2** | **SVG data injection** | `xml_attr()` |
| **ggplot2** | **Plot data extraction** | `ggplot_build()` |
| **grid** | **Graphics rendering** | `grid.draw()` |

### External Dependencies (CDN)

- **maidr.js**: `https://cdn.jsdelivr.net/npm/maidr@latest/dist/maidr.js`
- **maidr_style.css**: `https://cdn.jsdelivr.net/npm/maidr@latest/dist/maidr_style.css`

### Base R Functions Used

- **File Operations**: `tempfile()`, `readLines()`, `paste()`, `strsplit()`
- **System Functions**: `Sys.getenv()`, `Sys.time()`
- **Utility Functions**: `utils::browseURL()`, `print()`

## File Structure

```
maidr/
├── DESCRIPTION                 # Package metadata and dependencies
├── NAMESPACE                  # Exported functions
├── R/                         # R source code
│   ├── maidr.R               # Main entry points
│   ├── plot_factory.R        # Factory pattern implementation
│   ├── grob_factory.R        # Grob processing factory
│   ├── bar.R                 # Bar-specific functions
│   ├── plot_data.R           # Data structure classes
│   ├── extract_layout.R      # Layout extraction
│   ├── svg_utils.R           # SVG/HTML utilities
│   └── html_dependencies.R   # HTML dependencies
├── inst/
│   └── htmlwidgets/          # HTML widget files
│       ├── maidrWidget.js
│       └── maidrWidget.yaml
└── man/                      # Documentation files
```

## Code Flow for Bar Plots

### 1. Entry Point - User Calls `maidr()`

```r
# User creates a bar plot
p <- ggplot(data, aes(x = category, y = value)) + geom_bar(stat = "identity")
maidr(p)  # Main entry point
```

### 2. Main Orchestration - `create_maidr_html()`

```r
create_maidr_html <- function(plot, ...) {
  # Step 1: Factory Pattern Processing
  plot_processor <- create_plot_processor(plot, ...)
  
  # Step 2: Layout Extraction
  layout <- extract_layout(plot)
  
  # Step 3: GTable Conversion
  gt <- ggplot2::ggplotGrob(plot)
  
  # Step 4: Layer Processing
  plot_type <- get_plot_type(plot_processor)
  layer_ids <- extract_layer_ids(gt, plot_type)
  
  # Step 5: Layer Structure Creation
  layers <- create_layer_structure(layer_ids, plot_processor, layout)
  
  # Step 6: Final Assembly
  maidr_data <- create_maidr_data(layers)
  svg_content <- create_enhanced_svg(gt, maidr_data, ...)
  html_doc <- create_html_document(svg_content)
}
```

### 3. Factory Pattern - Plot Type Detection & Processing

#### Plot Type Detection (`detect_plot_type()`)
```r
detect_plot_type(plot) {
  # Extract geom classes from plot layers
  geom_types <- sapply(plot$layers, function(layer) {
    class(layer$geom)[1]
  })
  
  # Determine plot type based on geoms
  determine_plot_type_from_geoms(geom_types) {
    if (any(geom_types %in% c("GeomBar", "GeomCol"))) {
      return("bar")
    }
    return(NA_character_)
  }
}
```

#### Plot Processor Creation (`create_plot_processor()`)
```r
create_plot_processor(plot, plot_type = NULL, ...) {
  if (is.null(plot_type)) {
    plot_type <- detect_plot_type(plot)  # Returns "bar"
  }
  
  # Factory switch based on plot type
  switch(plot_type,
    "bar" = process_bar_plot(plot, ...),
    stop("Unsupported plot type: ", plot_type)
  )
}
```

#### Bar Plot Processing (`process_bar_plot()`)
```r
process_bar_plot(plot, ...) {
  # Extract layout information (title, axes labels)
  layout <- extract_layout(plot)
  
  # Extract bar-specific data
  data <- extract_bar_data(plot)
  
  # Create bar-specific selectors
  selectors <- make_bar_selectors(plot)
  
  # Return bar_plot_data object
  bar_plot_data(data = data, layout = layout, selectors = selectors)
}
```

### 4. Bar-Specific Data Extraction (`bar.R`)

#### Bar Data Extraction (`extract_bar_data()`)
```r
extract_bar_data(plot) {
  # Build the plot to get data
  built <- ggplot2::ggplot_build(plot)

  # Find bar layers
  bar_layers <- which(sapply(plot$layers, function(layer) {
    inherits(layer$geom, "GeomBar") || inherits(layer$geom, "GeomCol")
  }))

  # Extract data from first bar layer
  built_data <- built$data[[bar_layers[1]]]
  
  # Build data points in original data frame order
  data_points <- list()
  for (j in seq_len(nrow(built_data))) {
    point <- list()
    point$x <- get_x_value(built_data, j, original_data)
    point$y <- built_data$y[j] || built_data$count[j]
    point$fill <- built_data$fill[j]  # if exists
    data_points[[j]] <- point
  }
  
  return(data_points)
}
```

#### Bar Selector Creation (`make_bar_selectors()`)
```r
make_bar_selectors(plot) {
  # Convert to gtable to get grob information
  gt <- ggplot2::ggplotGrob(plot)

  # Find bar grobs
  grobs <- find_bar_grobs(gt)

  selectors <- list()
  for (grob in grobs) {
    grob_name <- grob$name
    # Extract the numeric part from grob name
    layer_id <- gsub("geom_rect\\.rect\\.", "", grob_name)

    # Create selector for this bar
    selector <- make_bar_selector(layer_id)
    selectors[[length(selectors) + 1]] <- selector
  }

  selectors
}
```

### 5. Layer Processing - Factory Pattern for Grobs

#### Layer ID Extraction (`extract_layer_ids()`)
```r
extract_layer_ids(gt, plot_type) {
  switch(plot_type,
    "bar" = extract_bar_layer_ids_from_gtable(gt),
    character(0)
  )
}
```

#### Bar Layer ID Extraction (`extract_bar_layer_ids_from_gtable()`)
```r
extract_bar_layer_ids_from_gtable(gt) {
  # Find bar grobs
  grobs <- find_bar_grobs(gt)

  # Extract layer IDs from grob names
  layer_ids <- character(0)
  for (grob in grobs) {
    grob_name <- grob$name
    layer_id <- gsub("geom_rect\\.rect\\.", "", grob_name)
    layer_ids <- c(layer_ids, layer_id)
  }

  layer_ids
}
```

#### Selector Creation (`make_selector()`)
```r
make_selector(plot_type, layer_id) {
  switch(plot_type,
    "bar" = make_bar_selector(layer_id)
  )
}
```

### 6. Data Structure Assembly

#### Layer Structure Creation
```r
# In create_maidr_html()
for (i in seq_along(layer_ids)) {
  layer_id <- layer_ids[i]
  
  layers[[i]] <- list(
    id = layer_id,
    selectors = make_selector(plot_type, layer_id),
    type = plot_type,
    data = plot_processor$data,
    title = layout$title,
    axes = layout$axes
  )
}
```

#### Maidr Data Creation (`create_maidr_data()`)
```r
create_maidr_data(layers) {
  # Filter out layers with null types
  valid_layers <- filter_valid_layers(layers)
  
  # Create maidr-data structure
  list(
    id = paste0("maidr-plot-", timestamp),
    subplots = list(
      list(
        list(
          id = paste0("maidr-subplot-", timestamp),
          layers = valid_layers
        )
      )
    )
  )
}
```

### 7. SVG Generation & Enhancement

#### Enhanced SVG Creation (`create_enhanced_svg()`)
```r
create_enhanced_svg(gt, maidr_data, ...) {
  # Create temporary SVG file
  svg_file <- tempfile(fileext = ".svg")
  
  # Draw gtable to SVG
  grid.newpage()
  grid.draw(gt)
  grid.export(svg_file, exportCoords = "none", exportMappings = "inline")
  
  # Read SVG content
  svg_content <- readLines(svg_file, warn = FALSE)
  
  # Add maidr data to SVG
  svg_content <- add_maidr_data_to_svg(svg_content, maidr_data)
  
  return(svg_content)
}
```

#### Maidr Data Injection (`add_maidr_data_to_svg()`)
```r
add_maidr_data_to_svg(svg_content, maidr_data) {
  # Convert maidr data to JSON
  maidr_json <- jsonlite::toJSON(maidr_data, auto_unbox = TRUE)
  
  # Parse SVG as XML
  svg_doc <- xml2::read_xml(svg_text)
  
  # Add maidr-data attribute to SVG root
  xml2::xml_attr(svg_doc, "maidr-data") <- maidr_json
  
  # Convert back to character vector
  svg_content <- strsplit(as.character(svg_doc), "\n")[[1]]
}
```

### 8. HTML Document Creation

#### HTML Document Assembly (`create_html_document()`)
```r
create_html_document(svg_content) {
  # Create HTML structure
  html_doc <- htmltools::tags$html(
    htmltools::tags$head(),
    htmltools::tags$body(
      htmltools::HTML(paste(svg_content, collapse = "\n"))
    )
  )
  
  # Attach maidr dependencies (JS/CSS from CDN)
  html_doc <- htmltools::attachDependencies(
    html_doc,
    maidr_html_dependencies()
  )
}
```

#### HTML Dependencies (`maidr_html_dependencies()`)
```r
maidr_html_dependencies() {
  # JS dependency from CDN
  js_dep <- htmltools::htmlDependency(
    name = "maidr-js",
    version = "1.0.0",
    src = c(href = "https://cdn.jsdelivr.net/npm/maidr@latest/dist/"),
    script = "maidr.js"
  )
  
  # CSS dependency from CDN
  css_dep <- htmltools::htmlDependency(
    name = "maidr-css",
    version = "1.0.0",
    src = c(href = "https://cdn.jsdelivr.net/npm/maidr@latest/dist/"),
    stylesheet = "maidr_style.css"
  )
  
  list(js_dep, css_dep)
}
```

### 9. Final Output & Display

#### Display Options
```r
# Option 1: Display directly
display_html(html_doc) {
  if (Sys.getenv("RSTUDIO") == "1") {
    htmltools::html_print(html_doc)  # RStudio Viewer
  } else {
    print(htmltools::browsable(html_doc))  # Browser
  }
}

# Option 2: Save to file
save_html_document(html_doc, file) {
  htmltools::save_html(html_doc, file = file)
}
```

## Extensibility Guide

### Adding a New Plot Type (e.g., "scatter")

#### 1. Update Plot Type Detection
```r
# In plot_factory.R
determine_plot_type_from_geoms(geom_types) {
  if (any(geom_types %in% c("GeomBar", "GeomCol"))) {
    return("bar")
  }
  if (any(geom_types %in% c("GeomPoint"))) {
    return("scatter")  # NEW
  }
  return(NA_character_)
}
```

#### 2. Add Processor Function
```r
# In plot_factory.R
create_plot_processor(plot, plot_type = NULL, ...) {
  switch(plot_type,
    "bar" = process_bar_plot(plot, ...),
    "scatter" = process_scatter_plot(plot, ...),  # NEW
    stop("Unsupported plot type: ", plot_type)
  )
}

# NEW: Create scatter_plot.R
process_scatter_plot(plot, ...) {
  layout <- extract_layout(plot)
  data <- extract_scatter_data(plot)
  selectors <- make_scatter_selectors(plot)
  
  scatter_plot_data(data = data, layout = layout, selectors = selectors)
}
```

#### 3. Add Layer Processing
```r
# In grob_factory.R
extract_layer_ids(gt, plot_type) {
  switch(plot_type,
    "bar" = extract_bar_layer_ids_from_gtable(gt),
    "scatter" = extract_scatter_layer_ids_from_gtable(gt),  # NEW
    character(0)
  )
}

make_selector(plot_type, layer_id) {
  switch(plot_type,
    "bar" = make_bar_selector(layer_id),
    "scatter" = make_scatter_selector(layer_id)  # NEW
  )
}
```

#### 4. Create Plot-Specific Functions
```r
# NEW: scatter.R
scatter_plot_data(data, layout, selectors, ...) {
  base_obj <- plot_data(
    type = "scatter",
    data = data,
    layout = layout,
    selectors = selectors,
    ...
  )
  class(base_obj) <- c("scatter_plot_data", class(base_obj))
  base_obj
}

extract_scatter_data(plot) {
  # Extract scatter plot specific data
}

make_scatter_selectors(plot) {
  # Create scatter plot selectors
}

find_scatter_grobs(gt) {
  # Find scatter plot grobs
}
```

## Conclusion

The maidr package provides a robust, extensible architecture for converting ggplot2 plots into interactive, accessible HTML. The factory pattern implementation makes it easy to add new plot types, while the separation of concerns ensures maintainable code. The current implementation uses gridSVG for detailed element mapping, but svglite could be considered for performance-critical applications.

The architecture is designed to be:
- **Extensible**: Easy to add new plot types
- **Maintainable**: Clear separation of concerns
- **Accessible**: Structured data for screen readers
- **Interactive**: JavaScript/CSS integration
- **Flexible**: Multiple output options 