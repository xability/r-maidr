# MAIDR Interactive Dashboard
# Comprehensive Shiny dashboard displaying all MAIDR plot types with navigation

# Load required libraries
library(shiny)
library(shinydashboard)
library(ggplot2)
library(devtools)

library(patchwork)
library(datasets)

# Load the maidr package
# Get the directory where this script is located
script_path <- commandArgs(trailingOnly = FALSE)
script_file <- sub("--file=", "", script_path[grep("--file=", script_path)])
script_dir <- dirname(normalizePath(script_file))
maidr_dir <- dirname(script_dir) # Parent directory of script directory
load_all(maidr_dir)

# Define UI
ui <- dashboardPage(
  # Header
  dashboardHeader(
    title = "MAIDR Interactive Dashboard",
    titleWidth = 350
  ),

  # Sidebar
  dashboardSidebar(
    width = 250,
    sidebarMenu(
      id = "tabs",
      role = "navigation",
      `aria-label` = "Main navigation menu",
      selected = "bar",

      # Basic Plots Section
      menuItem("Bar Plot", tabName = "bar", icon = icon("chart-bar")),
      menuItem("Dodged Bar", tabName = "dodged_bar", icon = icon("chart-bar")),
      menuItem("Stacked Bar", tabName = "stacked_bar", icon = icon("chart-bar")),
      menuItem("Point/Scatter", tabName = "point", icon = icon("circle")),

      # Statistical Plots Section
      menuItem("Histogram", tabName = "histogram", icon = icon("chart-line")),
      menuItem("Histogram + Density", tabName = "hist_density", icon = icon("chart-line")),
      menuItem("Boxplot", tabName = "boxplot", icon = icon("chart-line")),
      menuItem("Smooth Plot", tabName = "smooth", icon = icon("chart-line")),

      # Advanced Plots Section
      menuItem("Line Plot", tabName = "line", icon = icon("chart-area")),
      menuItem("Multiline Plot", tabName = "multiline", icon = icon("chart-area")),
      menuItem("Dual Axis", tabName = "dual_axis", icon = icon("chart-area")),
      menuItem("Heatmap", tabName = "heatmap", icon = icon("chart-area")),

      # Faceted Plots Section
      menuItem("Faceted Bar", tabName = "facet_bar", icon = icon("th")),
      menuItem("Faceted Point", tabName = "facet_point", icon = icon("th")),
      menuItem("Faceted Line", tabName = "facet_line", icon = icon("th")),

      # Multi-panel Plots Section
      menuItem("Patchwork 2x2", tabName = "patchwork_2x2", icon = icon("grid-3x3")),

      # Information Section
      menuItem("About MAIDR", tabName = "about", icon = icon("info-circle"))
    )
  ),

  # Body
  dashboardBody(
    # Skip link for accessibility (properly positioned)
    tags$a(
      href = "#dashboard-content",
      class = "skip-link",
      "Skip to main content"
    ),

    # Custom CSS for better styling, auto-resizing, and accessibility
    tags$head(
      tags$style(HTML("
        .content-wrapper {
          background-color: #f8f9fa;
        }
        .box {
          border-radius: 8px;
          box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .box-header {
          background-color: #007bff;
          color: white;
          border-radius: 8px 8px 0 0;
        }
        .nav-tabs-custom > .nav-tabs > li.active > a {
          background-color: #007bff;
          color: white;
        }

        /* Auto-resizing for MAIDR plots */
        .maidr-container {
          height: auto !important;
          min-height: 300px;
          max-height: 800px;
          overflow: visible;
        }

        .maidr-container svg {
          max-width: 100%;
          height: auto;
        }

        /* Ensure boxes auto-resize with content */
        .box-body {
          height: auto !important;
          overflow: visible;
        }

        /* Responsive plot containers */
        .plot-container {
          width: 100%;
          height: auto;
          min-height: 300px;
          max-height: 800px;
        }

        /* Accessibility Enhancements */

        /* Skip link styles - properly hidden until focused */
        .skip-link {
          position: absolute;
          top: -100px;
          left: 6px;
          background: #007bff;
          color: white;
          padding: 8px 16px;
          text-decoration: none;
          z-index: 10000;
          border-radius: 4px;
          font-weight: bold;
          border: 2px solid white;
          transition: top 0.3s ease;
        }

        .skip-link:focus {
          top: 6px;
          outline: 3px solid #ff6b35;
          outline-offset: 2px;
        }

        /* Focus indicators - only for interactive elements */
        a:focus,
        button:focus,
        input:focus,
        select:focus,
        textarea:focus,
        [tabindex]:focus {
          outline: 3px solid #ff6b35 !important;
          outline-offset: 2px !important;
        }

        /* High contrast focus for menu items */
        .sidebar-menu a:focus {
          background-color: #ff6b35 !important;
          color: white !important;
          outline: 2px solid white !important;
        }

        /* Remove unnecessary focus from non-interactive elements */
        .box-header:focus {
          outline: none !important;
        }

        /* Improve contrast for better readability */
        .box-header,
        .main-header .logo {
          background-color: #0056b3 !important;
          color: white !important;
        }

        /* Menu item accessibility */
        .sidebar-menu .menu-item a {
          position: relative;
        }

        .sidebar-menu .menu-item a:focus::after {
          content: ' (Current)';
          font-weight: bold;
        }

        /* ARIA live region for announcements */
        .aria-live-region {
          position: absolute;
          left: -10000px;
          width: 1px;
          height: 1px;
          overflow: hidden;
        }

        /* Ensure sufficient color contrast */
        .text-muted {
          color: #495057 !important;
        }

        /* Button accessibility */
        .btn:focus {
          box-shadow: 0 0 0 3px rgba(0, 123, 255, 0.25) !important;
        }

        /* Ensure proper focus visibility for custom tabindex elements */
        [tabindex='0']:focus {
          outline: 3px solid #ff6b35 !important;
          outline-offset: 2px !important;
          box-shadow: 0 0 0 1px white !important;
        }
      ")),

      # JavaScript for enhanced accessibility
      tags$script(HTML("
        $(document).ready(function() {
          // Skip link functionality
          $('.skip-link').on('click', function(e) {
            e.preventDefault();
            var target = $($(this).attr('href'));
            if (target.length) {
              target.attr('tabindex', '-1').focus();
              target.on('blur', function() {
                $(this).removeAttr('tabindex');
              });
            }
          });

          // Announce tab changes to screen readers
          $('.sidebar-menu a').on('click', function() {
            var tabName = $(this).text();
            $('#aria-live-region').text('Navigated to ' + tabName + ' section');
          });

          // Menu items are already focusable by default - no need to add tabindex

          // Add ARIA expanded states for collapsible menu items
          $('.sidebar-menu .treeview').each(function() {
            var $this = $(this);
            var $link = $this.find('> a');
            var $submenu = $this.find('> .treeview-menu');

            if ($submenu.length) {
              $link.attr('aria-expanded', $submenu.is(':visible'));
              $link.on('click', function() {
                var isVisible = $submenu.is(':visible');
                $(this).attr('aria-expanded', !isVisible);
              });
            }
          });

          // Add role and labels to plot containers
          $('.plot-container').each(function() {
            $(this).attr('role', 'img');
            $(this).attr('aria-label', 'Interactive data visualization with MAIDR accessibility features');
          });

          // Announce plot loading to screen readers
          $('.maidr-container').on('DOMNodeInserted', function() {
            $('#aria-live-region').text('Plot has been loaded and is ready for interaction');
          });

          // Handle Shiny custom messages for accessibility
          Shiny.addCustomMessageHandler('announceTabChange', function(message) {
            $('#aria-live-region').text(message);
          });

          Shiny.addCustomMessageHandler('announcePlotReady', function(message) {
            $('#aria-live-region').text(message);
          });

          // Add keyboard shortcuts for common actions
          $(document).on('keydown', function(e) {
            // Alt + H for Home (About section)
            if (e.altKey && e.key === 'h') {
              e.preventDefault();
              $('.sidebar-menu a[data-value=\"about\"]').click();
            }

            // Alt + B for Basic plots
            if (e.altKey && e.key === 'b') {
              e.preventDefault();
              $('.sidebar-menu a[data-value=\"basic\"]').click();
            }

            // Alt + S for Statistical plots
            if (e.altKey && e.key === 's') {
              e.preventDefault();
              $('.sidebar-menu a[data-value=\"statistical\"]').click();
            }
          });

          // Add help text for keyboard shortcuts
          $('body').append('<div id=\"keyboard-help\" style=\"position: fixed; bottom: 10px; right: 10px; background: rgba(0,0,0,0.8); color: white; padding: 10px; border-radius: 5px; font-size: 12px; z-index: 9999; display: none;\">Keyboard shortcuts: Alt+H (Home), Alt+B (Basic), Alt+S (Statistical)</div>');

          // Show/hide keyboard help with Alt+K
          $(document).on('keydown', function(e) {
            if (e.altKey && e.key === 'k') {
              e.preventDefault();
              $('#keyboard-help').toggle();
            }
          });
        });
      "))
    ),

    # ARIA live region for screen reader announcements
    div(
      id = "aria-live-region",
      class = "aria-live-region",
      `aria-live` = "polite",
      `aria-atomic` = "true",
      role = "status"
    ),
    div(
      id = "dashboard-content",
      tabItems(
        # === BASIC PLOTS ===

        # Bar Plot
        tabItem(
          tabName = "bar",
          role = "main",
          `aria-label` = "Simple Bar Plot Section",
          fluidRow(
            box(
              title = "Simple Bar Plot",
              status = "primary",
              solidHeader = TRUE,
              width = 12,
              height = "auto",
              `aria-labelledby` = "bar-plot-title",
              div(
                class = "plot-container",
                `aria-label` = "Interactive bar plot showing categorical data",
                maidr_output("bar_plot", height = "auto")
              )
            )
          ),
          fluidRow(
            box(
              title = "Description",
              status = "info",
              width = 12,
              "This bar plot shows categorical data with values for categories A, B, C, and D.
            MAIDR provides full keyboard navigation and screen reader support."
            )
          )
        ),

        # Dodged Bar Plot
        tabItem(
          tabName = "dodged_bar",
          fluidRow(
            box(
              title = "Dodged Bar Plot",
              status = "primary",
              solidHeader = TRUE,
              width = 12,
              div(
                class = "plot-container",
                maidr_output("dodged_bar_plot", height = "auto")
              )
            )
          ),
          fluidRow(
            box(
              title = "Description",
              status = "info",
              width = 12,
              "Dodged bar plots show grouped categorical data side by side.
            Use Tab to navigate between groups and Enter to explore values."
            )
          )
        ),

        # Stacked Bar Plot
        tabItem(
          tabName = "stacked_bar",
          fluidRow(
            box(
              title = "Stacked Bar Plot",
              status = "primary",
              solidHeader = TRUE,
              width = 12,
              div(
                class = "plot-container",
                maidr_output("stacked_bar_plot", height = "auto")
              )
            )
          ),
          fluidRow(
            box(
              title = "Description",
              status = "info",
              width = 12,
              "Stacked bar plots show the composition of categorical data.
            Each bar represents the total, with segments showing proportions."
            )
          )
        ),

        # Point/Scatter Plot
        tabItem(
          tabName = "point",
          fluidRow(
            box(
              title = "Point/Scatter Plot",
              status = "primary",
              solidHeader = TRUE,
              width = 12,
              div(
                class = "plot-container",
                maidr_output("point_plot", height = "auto")
              )
            )
          ),
          fluidRow(
            box(
              title = "Description",
              status = "info",
              width = 12,
              "Scatter plots show relationships between two continuous variables.
            Points are colored by group for easy comparison."
            )
          )
        ),

        # === STATISTICAL PLOTS ===

        # Histogram
        tabItem(
          tabName = "histogram",
          fluidRow(
            box(
              title = "Histogram",
              status = "primary",
              solidHeader = TRUE,
              width = 12,
              div(
                class = "plot-container",
                maidr_output("histogram_plot", height = "auto")
              )
            )
          ),
          fluidRow(
            box(
              title = "Description",
              status = "info",
              width = 12,
              "Histograms show the distribution of continuous data.
            Each bar represents a range of values and their frequency."
            )
          )
        ),

        # Histogram with Density
        tabItem(
          tabName = "hist_density",
          fluidRow(
            box(
              title = "Histogram with Density Curve",
              status = "primary",
              solidHeader = TRUE,
              width = 12,
              div(
                class = "plot-container",
                maidr_output("hist_density_plot", height = "auto")
              )
            )
          ),
          fluidRow(
            box(
              title = "Description",
              status = "info",
              width = 12,
              "Combines histogram and density curve to show both discrete bins and smooth distribution.
            The red curve represents the probability density function."
            )
          )
        ),

        # Boxplot
        tabItem(
          tabName = "boxplot",
          fluidRow(
            box(
              title = "Boxplot (Horizontal)",
              status = "primary",
              solidHeader = TRUE,
              width = 12,
              div(
                class = "plot-container",
                maidr_output("boxplot_plot", height = "auto")
              )
            )
          ),
          fluidRow(
            box(
              title = "Description",
              status = "info",
              width = 12,
              "Boxplots show the distribution of continuous data across categories.
            The box shows quartiles, whiskers show range, and points show outliers."
            )
          )
        ),

        # Smooth Plot
        tabItem(
          tabName = "smooth",
          fluidRow(
            box(
              title = "Smooth Plot (Density)",
              status = "primary",
              solidHeader = TRUE,
              width = 12,
              div(
                class = "plot-container",
                maidr_output("smooth_plot", height = "auto")
              )
            )
          ),
          fluidRow(
            box(
              title = "Description",
              status = "info",
              width = 12,
              "Smooth density plots show the probability distribution of continuous data.
            The curve represents the likelihood of observing values at each point."
            )
          )
        ),

        # === ADVANCED PLOTS ===

        # Line Plot
        tabItem(
          tabName = "line",
          fluidRow(
            box(
              title = "Single Line Plot",
              status = "primary",
              solidHeader = TRUE,
              width = 12,
              div(
                class = "plot-container",
                maidr_output("line_plot", height = "auto")
              )
            )
          ),
          fluidRow(
            box(
              title = "Description",
              status = "info",
              width = 12,
              "Line plots show trends over time or across ordered categories.
            Perfect for visualizing sequences and time series data."
            )
          )
        ),

        # Multiline Plot
        tabItem(
          tabName = "multiline",
          fluidRow(
            box(
              title = "Multiline Plot",
              status = "primary",
              solidHeader = TRUE,
              width = 12,
              div(
                class = "plot-container",
                maidr_output("multiline_plot", height = "auto")
              )
            )
          ),
          fluidRow(
            box(
              title = "Description",
              status = "info",
              width = 12,
              "Multiline plots compare multiple series on the same axes.
            Each line represents a different group or category."
            )
          )
        ),

        # Dual Axis Plot
        tabItem(
          tabName = "dual_axis",
          fluidRow(
            box(
              title = "Dual-Axis Plot",
              status = "primary",
              solidHeader = TRUE,
              width = 12,
              div(
                class = "plot-container",
                maidr_output("dual_axis_plot", height = "auto")
              )
            )
          ),
          fluidRow(
            box(
              title = "Description",
              status = "info",
              width = 12,
              "Dual-axis plots combine two different types of visualizations on separate y-axes.
            Here we show bars on the left axis and a line on the right axis."
            )
          )
        ),

        # Heatmap
        tabItem(
          tabName = "heatmap",
          fluidRow(
            box(
              title = "Heatmap with Labels",
              status = "primary",
              solidHeader = TRUE,
              width = 12,
              div(
                class = "plot-container",
                maidr_output("heatmap_plot", height = "auto")
              )
            )
          ),
          fluidRow(
            box(
              title = "Description",
              status = "info",
              width = 12,
              "Heatmaps show relationships between two categorical variables using color intensity.
            Values are displayed as text labels within each cell."
            )
          )
        ),

        # === FACETED PLOTS ===

        # Faceted Bar Plot
        tabItem(
          tabName = "facet_bar",
          fluidRow(
            box(
              title = "Faceted Bar Plot",
              status = "primary",
              solidHeader = TRUE,
              width = 12,
              div(
                class = "plot-container",
                maidr_output("facet_bar_plot", height = "auto")
              )
            )
          ),
          fluidRow(
            box(
              title = "Description",
              status = "info",
              width = 12,
              "Faceted plots create multiple panels, each showing a subset of the data.
            This allows comparison across different groups or categories."
            )
          )
        ),

        # Faceted Point Plot
        tabItem(
          tabName = "facet_point",
          fluidRow(
            box(
              title = "Faceted Point Plot",
              status = "primary",
              solidHeader = TRUE,
              width = 12,
              div(
                class = "plot-container",
                maidr_output("facet_point_plot", height = "auto")
              )
            )
          ),
          fluidRow(
            box(
              title = "Description",
              status = "info",
              width = 12,
              "Faceted scatter plots show relationships between variables across different groups.
            Each panel represents a different subset of the data."
            )
          )
        ),

        # Faceted Line Plot
        tabItem(
          tabName = "facet_line",
          fluidRow(
            box(
              title = "Faceted Line Plot",
              status = "primary",
              solidHeader = TRUE,
              width = 12,
              div(
                class = "plot-container",
                maidr_output("facet_line_plot", height = "auto")
              )
            )
          ),
          fluidRow(
            box(
              title = "Description",
              status = "info",
              width = 12,
              "Faceted line plots show trends across multiple groups.
            Each panel displays the same variables but for different categories."
            )
          )
        ),

        # === MULTI-PANEL PLOTS ===

        # Patchwork 2x2
        tabItem(
          tabName = "patchwork_2x2",
          fluidRow(
            box(
              title = "Patchwork 2x2 Layout",
              status = "primary",
              solidHeader = TRUE,
              width = 12,
              div(
                class = "plot-container",
                maidr_output("patchwork_2x2_plot", height = "auto")
              )
            )
          ),
          fluidRow(
            box(
              title = "Description",
              status = "info",
              width = 12,
              "Patchwork layouts combine multiple plots into a single visualization.
            This 2x2 grid shows line plots and bar charts arranged together."
            )
          )
        ),

        # === ABOUT SECTION ===

        tabItem(
          tabName = "about",
          id = "about-content",
          role = "main",
          `aria-label` = "About MAIDR and Accessibility Information",
          fluidRow(
            box(
              title = "About MAIDR",
              status = "info",
              solidHeader = TRUE,
              width = 12,
              `aria-labelledby` = "about-title",
              h3(id = "about-title", "Multimodal Access and Interactive Data Representation"),
              p("MAIDR is an open, research-driven platform that makes data visualizations accessible to users with visual impairments through screen readers and sonification."),
              h4("♿ Accessibility Features:"),
              tags$ul(
                tags$li("Full keyboard navigation support - Tab through all elements"),
                tags$li("Screen reader compatibility with ARIA labels"),
                tags$li("Audio descriptions and sonification for data exploration"),
                tags$li("Interactive data exploration with keyboard controls"),
                tags$li("High contrast focus indicators for visual accessibility"),
                tags$li("Skip links to bypass navigation and go directly to content"),
                tags$li("Live regions for dynamic content announcements")
              ),
              h4("⌨️ Keyboard Navigation:"),
              tags$ul(
                tags$li("Tab - Navigate between interactive elements"),
                tags$li("Enter/Space - Activate buttons and menu items"),
                tags$li("Arrow keys - Explore data points in plots"),
                tags$li("Escape - Close modals or return to previous state")
              ),
              h4("🎧 Screen Reader Usage:"),
              tags$ul(
                tags$li("All plots have descriptive ARIA labels"),
                tags$li("Menu items announce their current state"),
                tags$li("Tab changes are announced via live regions"),
                tags$li("Plot loading and interactions are announced"),
                tags$li("Descriptions provide context for each visualization")
              ),
              h4("📊 Supported Plot Types:"),
              tags$ul(
                tags$li("Bar plots (simple, dodged, stacked)"),
                tags$li("Statistical plots (histogram, boxplot, density)"),
                tags$li("Line plots (single and multiple series)"),
                tags$li("Scatter plots and heatmaps"),
                tags$li("Faceted and multi-panel layouts")
              ),
              h4("🔧 Technical Implementation:"),
              tags$ul(
                tags$li("WCAG 2.1 AA compliant design"),
                tags$li("Semantic HTML structure with proper roles"),
                tags$li("ARIA attributes for enhanced screen reader support"),
                tags$li("Auto-resizing containers that adapt to content"),
                tags$li("High contrast color scheme for visual accessibility")
              ),
              p("This dashboard demonstrates all supported plot types with comprehensive accessibility features, ensuring that data visualizations are usable by everyone, including users with disabilities.")
            )
          )
        )
      )
    ) # Close div with id="dashboard-content"
  )
)

# Define Server
server <- function(input, output, session) {
  # Accessibility enhancement: Announce tab changes
  observe({
    if (!is.null(input$tabs)) {
      cat("=== TAB CHANGED TO:", input$tabs, "===\n")
      # Announce the current tab to screen readers
      session$sendCustomMessage(
        type = "announceTabChange",
        message = paste("Current section:", input$tabs)
      )
    }
  })

  # Accessibility enhancement: Track plot loading
  observe({
    # This will trigger when plots are rendered
    invalidateLater(1000) # Check every second
    if (!is.null(input$tabs)) {
      session$sendCustomMessage(
        type = "announcePlotReady",
        message = paste("Plot in", input$tabs, "section is ready for interaction")
      )
    }
  })

  # === BASIC PLOTS ===

  # Bar Plot
  cat("=== DEFINING OUTPUT$bar_plot ===\n")
  output$bar_plot <- render_maidr({
    cat("=== BAR PLOT RENDERING START ===\n")

    tryCatch(
      {
        cat("Creating bar data...\n")
        bar_data <- data.frame(
          Category = c("A", "B", "C", "D"),
          Value = c(30, 25, 15, 10)
        )
        cat("Bar data created:", nrow(bar_data), "rows\n")

        cat("Creating ggplot...\n")
        p <- ggplot(bar_data, aes(x = Category, y = Value)) +
          geom_bar(stat = "identity", fill = "steelblue") +
          labs(title = "Simple Bar Plot", x = "Category", y = "Value") +
          theme_minimal()

        cat("ggplot created successfully\n")
        cat("Plot class:", class(p), "\n")
        cat("Plot inherits ggplot:", inherits(p, "ggplot"), "\n")

        cat("About to return plot to render_maidr...\n")
        return(p)
      },
      error = function(e) {
        cat("ERROR in bar plot creation:", e$message, "\n")
        cat("Error traceback:\n")
        traceback()

        # Return a simple plot as fallback
        fallback_plot <- ggplot(data.frame(x = 1, y = 1), aes(x = x, y = y)) +
          geom_point() +
          labs(title = "Error loading plot")

        cat("Returning fallback plot\n")
        return(fallback_plot)
      }
    )
  })

  # Dodged Bar Plot
  output$dodged_bar_plot <- render_maidr({
    dodged_data <- data.frame(
      Category = rep(c("A", "B", "C"), each = 2),
      Type = rep(c("Type1", "Type2"), 3),
      Value = c(10, 15, 20, 25, 30, 35)
    )

    ggplot(dodged_data, aes(x = Category, y = Value, fill = Type)) +
      geom_bar(stat = "identity", position = position_dodge(width = 0.8)) +
      labs(title = "Dodged Bar Plot", x = "Category", y = "Value", fill = "Type") +
      theme_minimal() +
      theme(legend.position = "right")
  })

  # Stacked Bar Plot
  output$stacked_bar_plot <- render_maidr({
    stacked_data <- data.frame(
      Category = rep(c("A", "B", "C"), each = 2),
      Type = rep(c("Type1", "Type2"), 3),
      Value = c(10, 15, 20, 25, 30, 35)
    )

    ggplot(stacked_data, aes(x = Category, y = Value, fill = Type)) +
      geom_bar(stat = "identity", position = position_stack()) +
      labs(title = "Stacked Bar Plot", x = "Category", y = "Value", fill = "Type") +
      theme_minimal() +
      theme(legend.position = "right")
  })

  # Point/Scatter Plot
  output$point_plot <- render_maidr({
    set.seed(123)
    x_values <- rep(1:5, each = 3)
    y_values <- c(
      rnorm(3, 10, 1), rnorm(3, 15, 2), rnorm(3, 12, 1.5),
      rnorm(3, 18, 1.8), rnorm(3, 14, 0.8)
    )
    groups <- rep(c("A", "B", "C"), times = 5)

    point_data <- data.frame(
      x = x_values,
      y = y_values,
      group = groups
    )

    ggplot(point_data, aes(x = x, y = y, color = group)) +
      geom_point(size = 4, alpha = 0.8) +
      labs(title = "Point/Scatter Plot", x = "X Values", y = "Y Values", color = "Group") +
      theme_minimal() +
      scale_x_continuous(breaks = 1:5) +
      theme(legend.position = "right")
  })

  # === STATISTICAL PLOTS ===

  # Histogram
  output$histogram_plot <- render_maidr({
    hist_data <- data.frame(
      values = rnorm(100, mean = 0, sd = 1)
    )

    ggplot(hist_data, aes(x = values)) +
      geom_histogram(bins = 20, fill = "steelblue", color = "black") +
      labs(title = "Histogram", x = "Values", y = "Frequency") +
      theme_minimal()
  })

  # Histogram with Density
  output$hist_density_plot <- render_maidr({
    set.seed(123)
    petal_lengths <- rnorm(150, mean = 3.8, sd = 1.8)
    petal_data <- data.frame(petal_length = petal_lengths)

    ggplot(petal_data, aes(x = petal_length)) +
      geom_histogram(aes(y = after_stat(density)), binwidth = 0.5, fill = "lightblue", alpha = 0.7, color = "black") +
      geom_density(color = "red", linewidth = 1) +
      labs(title = "Histogram with Density Curve", x = "Petal Length (cm)", y = "Density") +
      theme_minimal()
  })

  # Boxplot
  output$boxplot_plot <- render_maidr({
    iris_data <- datasets::iris

    ggplot(iris_data, aes(x = Petal.Length, y = Species)) +
      geom_boxplot(fill = "lightblue", color = "darkblue", alpha = 0.7) +
      labs(title = "Boxplot - Petal Length by Species", x = "Petal Length", y = "Species") +
      theme_minimal()
  })

  # Smooth Plot
  output$smooth_plot <- render_maidr({
    smooth_data <- data.frame(
      x = rnorm(100, mean = 0, sd = 1)
    )

    ggplot(smooth_data, aes(x = x)) +
      geom_density(fill = "lightblue", alpha = 0.5) +
      labs(title = "Smooth Density Plot", x = "Values", y = "Density") +
      theme_minimal()
  })

  # === ADVANCED PLOTS ===

  # Line Plot
  output$line_plot <- render_maidr({
    line_data <- data.frame(
      x = 1:10,
      y = c(2, 4, 1, 5, 3, 7, 6, 8, 9, 4)
    )

    ggplot(line_data, aes(x = x, y = y)) +
      geom_line(color = "steelblue", linewidth = 1.5) +
      labs(title = "Single Line Plot", x = "X values", y = "Y values") +
      theme_minimal()
  })

  # Multiline Plot
  output$multiline_plot <- render_maidr({
    set.seed(123)
    x <- 1:10
    y1 <- c(2, 4, 1, 5, 3, 7, 6, 8, 9, 4)
    y2 <- c(1, 3, 5, 2, 4, 6, 8, 7, 5, 3)
    y3 <- c(3, 1, 4, 6, 5, 2, 4, 5, 7, 6)

    multiline_data <- data.frame(
      x = rep(x, 3),
      y = c(y1, y2, y3),
      series = rep(c("Series 1", "Series 2", "Series 3"), each = length(x))
    )

    ggplot(multiline_data, aes(x = x, y = y, color = series)) +
      geom_line(linewidth = 1) +
      labs(title = "Multiline Plot", x = "X values", y = "Y values", color = "Series") +
      theme_minimal() +
      theme(legend.position = "right")
  })

  # Dual Axis Plot
  output$dual_axis_plot <- render_maidr({
    x_dual <- 0:4
    bar_data_dual <- c(3, 5, 2, 7, 3)
    line_data_dual <- c(10, 8, 12, 14, 9)

    dual_plot_data <- data.frame(
      x = x_dual,
      bar_values = bar_data_dual,
      line_values = line_data_dual
    )

    ggplot(dual_plot_data, aes(x = x)) +
      geom_bar(aes(y = bar_values), stat = "identity", fill = "skyblue", alpha = 0.7) +
      geom_line(aes(y = line_values * max(bar_data_dual) / max(line_data_dual)), color = "red", linewidth = 1) +
      labs(title = "Dual-Axis Plot", x = "X values", y = "Bar values") +
      scale_y_continuous(
        name = "Bar values",
        sec.axis = sec_axis(~ . * max(line_data_dual) / max(bar_data_dual), name = "Line values")
      ) +
      theme_minimal() +
      theme(
        axis.title.y.right = element_text(color = "red"),
        axis.text.y.right = element_text(color = "red"),
        axis.title.y.left = element_text(color = "blue"),
        axis.text.y.left = element_text(color = "blue")
      )
  })

  # Heatmap
  output$heatmap_plot <- render_maidr({
    heatmap_data <- data.frame(
      x = c("B", "A", "B", "A"),
      y = c("2", "2", "1", "1"),
      z = c(4, 3, 2, 1)
    )

    ggplot(heatmap_data, aes(x = x, y = y, fill = z)) +
      geom_tile() +
      geom_text(aes(label = z), color = "white", size = 4) +
      labs(title = "Heatmap with Labels", x = "X Category", y = "Y Category", fill = "Value") +
      theme_minimal()
  })

  # === FACETED PLOTS ===

  # Faceted Bar Plot
  output$facet_bar_plot <- render_maidr({
    set.seed(42)
    facet_bar_data <- data.frame(
      x = rep(1:5, 4),
      y = c(
        runif(5, 1, 10),
        runif(5, 10, 100),
        runif(5, 1, 36),
        runif(5, 1, 42)
      ),
      group = rep(c("Group 1", "Group 2", "Group 3", "Group 4"), each = 5)
    )

    ggplot(facet_bar_data, aes(x = x, y = y)) +
      geom_bar(stat = "identity", fill = "steelblue") +
      facet_wrap(~group, ncol = 2) +
      labs(title = "Faceted Bar Plot", x = "Categories", y = "Values") +
      theme_minimal()
  })

  # Faceted Point Plot
  output$facet_point_plot <- render_maidr({
    set.seed(42)
    facet_point_data <- data.frame(
      x = rep(1:5, 4),
      y = c(
        runif(5, 1, 10),
        runif(5, 10, 100),
        runif(5, 1, 36),
        runif(5, 1, 42)
      ),
      group = rep(c("Group 1", "Group 2", "Group 3", "Group 4"), each = 5)
    )

    ggplot(facet_point_data, aes(x = x, y = y)) +
      geom_point(size = 3, color = "steelblue") +
      facet_wrap(~group, ncol = 2) +
      labs(title = "Faceted Point Plot", x = "X Values", y = "Y Values") +
      theme_minimal()
  })

  # Faceted Line Plot
  output$facet_line_plot <- render_maidr({
    set.seed(42)
    facet_line_data <- data.frame(
      x = rep(1:5, 4),
      y = c(
        runif(5, 1, 10),
        runif(5, 10, 100),
        runif(5, 1, 36),
        runif(5, 1, 42)
      ),
      group = rep(c("Group 1", "Group 2", "Group 3", "Group 4"), each = 5)
    )

    ggplot(facet_line_data, aes(x = x, y = y)) +
      geom_line(color = "steelblue", linewidth = 1.5) +
      facet_wrap(~group, ncol = 2) +
      labs(title = "Faceted Line Plot", x = "X Values", y = "Y Values") +
      theme_minimal()
  })

  # === MULTI-PANEL PLOTS ===

  # Patchwork 2x2
  output$patchwork_2x2_plot <- render_maidr({
    set.seed(99)
    line_df_pw <- data.frame(x = 1:8, y = c(2, 4, 1, 5, 3, 7, 6, 8))
    pw_line <- ggplot(line_df_pw, aes(x, y)) +
      geom_line(color = "steelblue", linewidth = 1) +
      labs(title = "Line Plot: Random Data", x = "X-axis", y = "Values") +
      theme_minimal()

    bar_df1_pw <- data.frame(
      categories = c("A", "B", "C", "D", "E"),
      values = runif(5, 0, 10)
    )
    pw_bar1 <- ggplot(bar_df1_pw, aes(categories, values)) +
      geom_bar(stat = "identity", fill = "forestgreen", alpha = 0.7) +
      labs(title = "Bar Plot: Random Values", x = "Categories", y = "Values") +
      theme_minimal()

    bar_df2_pw <- data.frame(
      categories = c("A", "B", "C", "D", "E"),
      values = rnorm(5, 0, 100)
    )
    pw_bar2 <- ggplot(bar_df2_pw, aes(categories, values)) +
      geom_bar(stat = "identity", fill = "royalblue", alpha = 0.7) +
      labs(title = "Bar Plot 2: Random Values", x = "Categories", y = "Values") +
      theme_minimal()

    set.seed(1234)
    line_df_extra <- data.frame(x = 1:8, y = cumsum(rnorm(8)))
    pw_line_extra <- ggplot(line_df_extra, aes(x, y)) +
      geom_line(color = "tomato", linewidth = 1) +
      labs(title = "Extra Line Plot", x = "X-axis", y = "Values") +
      theme_minimal()

    (pw_line + pw_bar1 + pw_bar2 + pw_line_extra) + plot_layout(ncol = 2)
  })
}

# Run the application
shinyApp(ui = ui, server = server, options = list(port = 3838, host = "127.0.0.1"))
