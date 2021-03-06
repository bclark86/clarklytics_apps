# LIBRARIES ----
library(shiny)
library(shinythemes)
library(shinyWidgets)
library(tidyverse)

# SETUP ----
theme <- "paper"
button_theme_search <- "primary"
button_theme_tags <- "primary"
button_theme_cards <- "primary"


# APP CATALOG (META DATA) ----
app1 <- list(
    title = "Stock Analyzer",
    subtitle = "Business Science Course",
    description = "A financial application for analyzing trends in your favorite SP 500 stocks. Leverages AWS EC2 and uses internal data storage.",
    sub_directory = "stock_analyzer_local_data",
    tags = tibble(
        tag = c("Shiny", "AWS", "Auth"),
        color = c("default", "success", "info")
    ) %>% list(),
    img = "stock_analyzer.jpg"
)

app2 <- list(
    title = "Wedding Budget Risk Analyzer",
    subtitle = "Passion Project",
    description = "A financial application for analyzing risk of going over budget with wedding planning. Leverages custom python class and AWS EC2.",
    sub_directory = "wedding_risk",
    tags = tibble(
        tag = c("Shiny", "AWS", "Python"),
        color = c("default", "success", "info")
    ) %>% list(),
    img = "wedding_risk.png"
)

app_catalog_tbl <- bind_rows(app1, app2, .id = "id")


# FUNCTIONS ----
navbar_page_with_inputs <- function(..., inputs) {
    navbar <- shiny::navbarPage(...)
    
    form <- tags$form(class = "navbar-form navbar-right", inputs)
    
    navbar[[3]][[1]]$children[[1]]$children[[2]] <- htmltools::tagAppendChild(
        navbar[[3]][[1]]$children[[1]]$children[[2]], form
    )
    
    return(navbar)
}

make_tags <- function(data) {
    
    data %>%
        mutate(tag = as_factor(tag)) %>%
        group_by(tag) %>%
        group_split() %>%
        
        map(.f = function(data) {
            span(class = str_glue("label label-{data$color}"), data$tag)
        }) %>%
        
        tagList()
}

make_cards <- function(data) {
    if (nrow(data) == 0) return("")
    
    data %>%
        mutate(id = as_factor(id)) %>%
        group_by(id) %>%
        group_split() %>%
        map(.f = function(data) {
            div(
                class = "col-sm-4",
                style = "display: flex;",
                div(
                    class = "panel panel-default",
                    div(
                        class = "panel-heading",
                        data %>% pluck("tags", 1) %>% make_tags() 
                    ),
                    div(
                        class = "panel-body",
                        style = "padding: 20px;",
                        
                        # image
                        tags$img(
                            class = "img img-thumbnail",
                            src = str_glue("images/{data$img}")
                        ),
                        
                        br(), br(),
                        h4(data$title, br(), 
                           if (!is.na(data$subtitle)) tags$small(data$subtitle)
                        ),
                        p(data$description),
                        a(
                            type   = "button",
                            class  = str_glue("btn btn-{button_theme_cards}"),
                            target = "_blank",
                            href   = str_c("/", data$sub_directory),
                            "Open"
                        )
                    )
                )
            )
        }) %>% tagList()
        
}

# UI ----
# Define UI for application that draws a histogram
ui <- fluidPage(
    
    # 1.0 HEAD ----
    tagList(
        tags$head(HTML("<title>Apps by Clarklytics</title>"))
    ),
    
    style = "padding: 0px;",
    
    # 2.0 Navbar Page ----
    navbar_page_with_inputs(
        
        # 2.1 Application Title ----
        title = div(
            tags$img(
                src = "https://www.business-science.io/img/business-science-logo.png",
                width = "30",
                height = "30",
                style = "-webkit-filter: drop-shadow(3px 3px 3px #222);"
            )
        ),
        collapsible = TRUE,
        theme = shinytheme(theme),
        
        # 2.2 Full Text Search ----
        inputs = div(
            textInput(
                inputId = "search_box", label = NULL,
                placeholder = "Search", width = 200
            ),
            actionButton(
                inputId = "search_button", label = "Submit", class = str_glue("btn-{button_theme_search}")
            ),
            actionButton(
                inputId = "clear_button", label = "Clear", class = str_glue("btn-{button_theme_search}")
            )
        ),
        
        # 1.3 Tabs ----
        tabPanel(
            title = "Library",
            
            # 1.3.1 Tag Filters ----
            div(
                class = "container",
                id = "tag-filters",
                radioGroupButtons(
                    inputId = "input_tags",
                    choices = c("All", 
                                app_catalog_tbl %>% 
                                    select(tags) %>% 
                                    unnest(tags) %>%
                                    pull(tag) %>% 
                                    unique() %>% 
                                    sort() %>%
                                    str_to_upper()
                                    ),
                    justified = TRUE,
                    status = button_theme_tags
                )
            ),
            
            # App Library ----
            div(
                class = "",
                id = "app-library",
                uiOutput(outputId = "output_cards")
            )
        )
    )
)

# SERVER ----
server <- function(session, input, output) {
    
    reactive_values <- reactiveValues(data = app_catalog_tbl)
    
    # Search Box ----
    observeEvent(eventExpr = input$search_button, {
        
        search_string <- str_to_lower(input$search_box)
        
        reactive_values$data <- app_catalog_tbl %>%
            filter(
                str_to_lower(title) %>% str_detect(search_string) |
                    str_to_lower(subtitle) %>% str_detect(search_string) |
                    str_to_lower(description) %>% str_detect(search_string)
            )
        
    })
    
    # Clear Button ----
    observeEvent(eventExpr = input$clear_button, {
        
        updateTextInput(session = session, inputId = "search_box", value = "", placeholder = "Search")
        
        reactive_values$data <- app_catalog_tbl
        
        updateRadioGroupButtons(session = session, inputId = "input_tags", selected = "ALL")
        
    })
    
    # Tag Filters ----
    observeEvent(eventExpr = input$input_tags, {
        
        tag_selected <- input$input_tags %>% str_to_lower()
        
        if (tag_selected == "all") {
            reactive_values$data <- app_catalog_tbl
        } else {
            ids_selected <- app_catalog_tbl %>%
                unnest(tags) %>%
                filter(str_to_lower(tag) == tag_selected) %>%
                pull(id)
            
            reactive_values$data <- app_catalog_tbl %>%
                filter(id %in% ids_selected)
        }
        
    })
    
    # Render Cards ----
    output$output_cards <- renderUI({
        
        div(
            class = "container",
            div(
                class = "row",
                style = "display:-webkit-flex; flex-wrap:wrap",
                reactive_values$data %>% make_cards()
            )
        )
    })
}

# Run the application 
shinyApp(ui = ui, server = server)
