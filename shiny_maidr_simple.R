# Simple Shiny app demonstrating maidr package
library(shiny)
library(ggplot2)

# Load the maidr package
devtools::load_all('maidr')

# Create random data with 10 categories (same as test script)
set.seed(123)
random_data <- data.frame(
  category = paste0("Group ", LETTERS[1:10]),
  value = round(runif(10, 10, 100))
)

ui <- fluidPage(
  titlePanel("maidr Package Demo - Interactive Bar Plot"),
  
  sidebarLayout(
    sidebarPanel(
      h4("Plot Controls"),
      
      # Color selector (using built-in colors)
      selectInput("bar_color", "Bar Color:",
                  choices = c("steelblue", "red", "green", "orange", "purple", "brown"),
                  selected = "steelblue"),
      
      # Theme selector
      selectInput("plot_theme", "Theme:",
                  choices = c("Minimal" = "minimal", 
                             "Classic" = "classic",
                             "Gray" = "gray",
                             "BW" = "bw"),
                  selected = "minimal"),
      
      # Title input
      textInput("plot_title", "Plot Title:", 
                value = "Random Data - 10 Groups"),
      
      # X-axis label
      textInput("x_label", "X-axis Label:", value = "Categories"),
      
      # Y-axis label  
      textInput("y_label", "Y-axis Label:", value = "Values"),
      
      # Angle for x-axis labels
      sliderInput("label_angle", "X-axis Label Angle:", 
                  min = 0, max = 90, value = 45, step = 15),
      
      hr(),
      
      h4("maidr Options"),
      
      # Checkbox for opening in browser
      checkboxInput("open_browser", "Open in Browser", value = TRUE),
      
      # Action button to generate maidr plot
      actionButton("generate_maidr", "Generate Interactive Plot", 
                   class = "btn-primary btn-lg"),
      
      hr(),
      
      # Display file path if saved
      verbatimTextOutput("file_path")
    ),
    
    mainPanel(
      tabsetPanel(
        tabPanel("Static Plot", 
                 plotOutput("static_plot", height = "500px")),
        
        tabPanel("Interactive Plot", 
                 htmlOutput("interactive_plot", height = "500px")),
        
        tabPanel("Data Table",
                 tableOutput("data_table"))
      )
    )
  )
)

server <- function(input, output, session) {
  
  # Reactive plot creation
  plot_reactive <- reactive({
    ggplot(random_data, aes(x = category, y = value)) + 
      geom_bar(stat = "identity", fill = input$bar_color) +
      labs(title = input$plot_title,
           x = input$x_label, 
           y = input$y_label) +
      theme(axis.text.x = element_text(angle = input$label_angle, hjust = 1)) +
      {
        if (input$plot_theme == "minimal") theme_minimal()
        else if (input$plot_theme == "classic") theme_classic()
        else if (input$plot_theme == "gray") theme_gray()
        else if (input$plot_theme == "bw") theme_bw()
        else theme_minimal()
      }
  })
  
  # Static plot output
  output$static_plot <- renderPlot({
    plot_reactive()
  })
  
  # Data table output
  output$data_table <- renderTable({
    random_data
  })
  
  # Interactive plot generation
  observeEvent(input$generate_maidr, {
    # Create the plot
    p <- plot_reactive()
    
    # Generate maidr plot
    file_path <- maidr(p, open = input$open_browser)
    
    # Display file path
    output$file_path <- renderText({
      if (is.null(file_path)) {
        "Plot displayed directly in browser (no file saved)"
      } else {
        paste("HTML file saved at:", file_path)
      }
    })
    
    # Display interactive plot in Shiny
    output$interactive_plot <- renderUI({
      # Read the HTML file and display it
      if (!is.null(file_path) && file.exists(file_path)) {
        includeHTML(file_path)
      } else {
        # If no file was saved, create HTML content directly
        html_doc <- create_maidr_html(p)
        HTML(as.character(html_doc))
      }
    })
  })
  
  # Initialize with a default maidr plot
  observe({
    # Create initial plot
    p <- plot_reactive()
    
    # Generate maidr plot on app start
    file_path <- maidr(p, open = FALSE)  # Don't open browser automatically
    
    # Display file path
    output$file_path <- renderText({
      if (is.null(file_path)) {
        "Plot displayed directly in browser (no file saved)"
      } else {
        paste("HTML file saved at:", file_path)
      }
    })
    
    # Display interactive plot
    output$interactive_plot <- renderUI({
      if (!is.null(file_path) && file.exists(file_path)) {
        includeHTML(file_path)
      } else {
        html_doc <- create_maidr_html(p)
        HTML(as.character(html_doc))
      }
    })
  })
}

# Run the Shiny app
shinyApp(ui = ui, server = server) 