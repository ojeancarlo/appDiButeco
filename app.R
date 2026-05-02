library(shiny)
library(leaflet)
library(leaflet.extras)
library(rvest)
library(dplyr)
library(stringr)
library(tidygeocoder)
library(htmltools)
library(geosphere)

# construindo a função de coleta dos dados e tratamento
get_data <- function() {
  cache_file <- "dados_bares_cache.rds"

  if (file.exists(cache_file) && as.Date(file.info(cache_file)$mtime) == Sys.Date()) {
    return(readRDS(cache_file))
  }

  tryCatch({
    url <- "https://www.acidadeon.com/ribeiraopreto/lazer-e-cultura/comida-di-buteco-conheca-os-32-bares-participantes-em-ribeirao-preto/"
    pagina <- read_html(url, encoding = "UTF-8")
    itens_bares <- pagina |> html_nodes(xpath = "//*[@id='dsoaudio']/div[6]//ul/li")

    df <- lapply(itens_bares, function(no) {
      nome <- no |> html_node("strong") |> html_text(trim = TRUE) |> str_remove(":")
      texto_bruto <- no |> html_text(trim = TRUE)
      endereco <- str_match(texto_bruto, paste0(nome, "\\s*(.*?)\\s*Petisco:"))[,2]
      endereco <- str_remove(endereco, "(?i)Endereço:\\s*") |> str_remove("^[[:punct:]\\s]+")
      petisco <- str_split(texto_bruto, "Petisco:")[[1]][2] |> str_trim()
      data.frame(Nome = nome, Endereco = endereco, Petisco = petisco, stringsAsFactors = FALSE)
    }) |> bind_rows()

    df <- df |>
      mutate(rua_limpa = str_split(Endereco, " [–-] ") |> sapply(`[`, 1),
             endereco_gps = paste0(rua_limpa, ", Ribeirão Preto, SP, Brasil")) |>
      geocode(address = endereco_gps, method = 'arcgis') |>
      filter(!is.na(lat))

    saveRDS(df, cache_file)
    return(df)
  }, error = function(e) {
    if(file.exists(cache_file)) return(readRDS(cache_file))
    stop("Não foi possível carregar os dados.")
  })
}

dados_bares <- get_data()

# construindo a ui do user
ui <- fluidPage(
  title = "Circuito Comida di Buteco 2026 - RP",
  tags$head(
    tags$meta(name = "viewport", content = "width=device-width, initial-scale=1.0"),
    tags$style(HTML("
      /* Configuração Flexbox para o corpo da página */
      html, body { width: 100%; height: 100vh; margin: 0; padding: 0; overflow: hidden; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; display: flex; flex-direction: column; }

      /* Transforma o container base do fluidPage em um flex container */
      .container-fluid { padding: 0 !important; display: flex; flex-direction: column; flex-grow: 1; height: 100%; }

      /* Impede que o cabeçalho, filtros e rodapé sejam esmagados pelo mapa */
      .header-container, .filter-row, .footer-container { flex-shrink: 0; z-index: 10; }

      .header-container { background-color: white; padding: 15px 30px; border-bottom: 5px solid #EB7E00; box-shadow: 0 4px 10px rgba(0,0,0,0.05); }
      .project-desc { color: #666; font-size: 13px; line-height: 1.4; margin-top: 8px; width: 100%; }

      /* Adicionado scroll vertical caso os filtros empilhados passem de 40% da tela */
      .filter-row { background-color: #fcfcfc; padding: 10px 25px; border-bottom: 1px solid #eee; max-height: 40vh; overflow-y: auto; }

      /* O pulo do gato: flex-grow: 1 faz o mapa ocupar exatamente o espaço que sobrar */
      #map { flex-grow: 1; height: 100% !important; width: 100%; z-index: 1; }

      .distancia-painel {
        position: absolute; bottom: 80px; right: 20px; z-index: 1000; background: rgba(255,255,255,0.95);
        padding: 15px; border-radius: 10px; border-left: 6px solid #56A853; width: 320px; max-height: 310px;
        overflow-y: auto; font-size: 12px; box-shadow: 0 4px 15px rgba(0,0,0,0.2);
      }

      .footer-container { padding: 10px 30px; background-color: white; color: #444; text-align: left; font-size: 11px; border-top: 2px solid #56A853; line-height: 1.6; }
      .footer-container a { color: #0077B5; text-decoration: none; font-weight: bold; }
      .footer-container a:hover { text-decoration: underline; }

      .item-roteiro { margin-bottom: 12px; border-bottom: 1px solid #f0f0f0; padding-bottom: 8px; }
      .petisco-txt { color: #666; font-style: italic; font-size: 11px; display: block; margin-top: 2px; }
      .btn-roteirizar { background-color: #56A853; color: white; border: none; margin-top: 25px; width: 100%; border-radius: 4px; padding: 6px; font-weight: bold; cursor: pointer;}
      .btn-reset { background-color: #f0f0f0; color: #666; border: 1px solid #ccc; margin-top: 25px; width: 100%; border-radius: 4px; padding: 6px; font-weight: bold; cursor: pointer;}

      /* --- MEDIA QUERIES (REGRAS EXCLUSIVAS PARA CELULARES) --- */
      @media (max-width: 768px) {
        .header-container { padding: 10px 15px; }
        h1 { font-size: 22px !important; }
        .filter-row { padding: 10px 15px; }

        /* Corrige o espaçamento dos botões quando eles empilham no mobile */
        .btn-roteirizar, .btn-reset { margin-top: 10px; }

        /* Centraliza o painel de distâncias e adapta ao tamanho da tela */
        .distancia-painel {
          width: 90%;
          left: 5%;
          right: 5%;
          bottom: 20px;
          max-height: 35vh;
        }

        .footer-container { padding: 10px 15px; font-size: 10px; }
      }
    "))
  ),
  div(class = "header-container",
      h1("Circuito Comida di Buteco 2026", style = "margin:0; color:#EB7E00; font-weight:900; letter-spacing:-1.5px; font-size: 28px;"),
      p("Ribeirão Preto/SP", style = "margin:0; color:#56A853; font-weight:bold; font-size:16px;"),
      div(class = "project-desc",
          "Este dashboard auxilia na exploração dos bares participantes do concurso em Ribeirão Preto. ",
          "O objetivo é facilitar a criação de roteiros gastronômicos: basta filtrar por bar ou ingrediente do petisco, ",
          "clicar no mapa para definir sua localização atual e solicitar a roteirização para encontrar as opções mais próximas.")
  ),
  div(class = "filter-row",
      fluidRow(
        column(2, selectizeInput("busca_bar", "Bar:", choices = c("Todos", sort(dados_bares$Nome)), width = "100%")),
        column(3, selectizeInput("busca_petisco", "Petisco:",
                                 choices = c("Todos", sort(dados_bares$Petisco)),
                                 options = list(placeholder = 'Buscar ingrediente...', onInitialize = I('function() { this.setValue(""); }')),
                                 width = "100%")),
        column(1, numericInput("qtd_bares", "Qtd:", value = 3, min = 1, max = 15, width = "100%")),
        column(2, textInput("minha_loc", "Origem:", placeholder = "Clique no mapa...", width = "100%")),
        column(2, actionButton("calc_dist", "ROTEIRIZAR", class="btn-roteirizar")),
        column(2, actionButton("reset_loc", "LIMPAR", class="btn-reset"))
      )
  ),
  uiOutput("ui_distancia"),
  leafletOutput("map"),
  div(class = "footer-container",
      div(strong("Dica:"), " Clique no mapa para definir o endereço e pressione Roteirizar. Distâncias calculadas em linha reta (Haversine)."),
      div(strong("Referências:"), " Site Oficial ", a("Comida di Buteco", href="https://comidadibuteco.com.br/", target="_blank"), " | Dados: ", a("ACidade ON", href="https://www.acidadeon.com/ribeiraopreto/lazer-e-cultura/comida-di-buteco-conheca-os-32-bares-participantes-em-ribeirao-preto/", target="_blank")),
      div(strong("Desenvolvedor:"), " Jean Silva - Especialista em Dados | ", a("LinkedIn", href="https://www.linkedin.com/in/jeancarlonds/", target="_blank"), " | Atualizado em: 2026-05-02")
  )
)

# construindo o server
server <- function(input, output, session) {
  rv <- reactiveValues(coords = NULL, show_panel = FALSE, ranking = NULL, last_click_addr = "", temp_coords = NULL)

  observeEvent(input$map_click, {
    click <- input$map_click
    ponto_clicado <- data.frame(lat = click$lat, long = click$lng)
    endereco_reverso <- reverse_geocode(ponto_clicado, lat = lat, long = long, method = 'arcgis')
    rua_encontrada <- as.character(endereco_reverso$address[1])
    if(is.na(rua_encontrada)) rua_encontrada <- "Localização capturada"

    updateTextInput(session, "minha_loc", value = rua_encontrada)
    rv$temp_coords <- list(lon = click$lng, lat = click$lat)
    rv$last_click_addr <- rua_encontrada

    leafletProxy("map") |>
      clearGroup("minha_pos") |>
      addCircleMarkers(lng = click$lng, lat = click$lat, group = "minha_pos", radius = 10,
                       fillColor = "#0277BD", fillOpacity = 0.8, color = "white", weight = 3)
  })

  observeEvent(input$calc_dist, {
    req(input$minha_loc)
    if (input$minha_loc != rv$last_click_addr) {
      loc_limpa <- paste0(input$minha_loc, ", Ribeirão Preto, SP, Brasil")
      res <- geo(address = loc_limpa, method = 'arcgis')
      if(!is.na(res$lat[1])) {
        rv$coords <- list(lon = res$long[1], lat = res$lat[1])
      } else {
        showNotification("Endereço não encontrado.", type = "error")
        return()
      }
    } else {
      rv$coords <- rv$temp_coords
    }

    req(rv$coords)
    df_f <- dados_bares
    sel_bar <- isolate(input$busca_bar)
    sel_petisco <- isolate(input$busca_petisco)
    qtd <- isolate(input$qtd_bares)

    if (sel_bar != "Todos") df_f <- df_f |> filter(Nome == sel_bar)
    if (sel_petisco != "Todos" && sel_petisco != "") {
      df_f <- df_f |> filter(grepl(sel_petisco, Petisco, ignore.case = TRUE))
    }

    if(nrow(df_f) == 0) {
      showNotification("Nenhum bar com este filtro.", type = "warning")
      return()
    }

    dists <- distHaversine(matrix(c(rv$coords$lon, rv$coords$lat), ncol = 2),
                           matrix(c(df_f$long, df_f$lat), ncol = 2))

    rv$ranking <- df_f |> mutate(dist_km = round(dists / 1000, 2)) |> arrange(dist_km) |> head(qtd)
    rv$show_panel <- TRUE
    leafletProxy("map") |> setView(lng = rv$coords$lon, lat = rv$coords$lat, zoom = 14)
  })

  observeEvent(input$reset_loc, {
    updateTextInput(session, "minha_loc", value = "")
    updateNumericInput(session, "qtd_bares", value = 3)
    updateSelectizeInput(session, "busca_bar", selected = "Todos")
    updateSelectizeInput(session, "busca_petisco", selected = "Todos")
    rv$coords <- NULL; rv$temp_coords <- NULL; rv$ranking <- NULL; rv$show_panel <- FALSE; rv$last_click_addr <- ""

    leafletProxy("map") |> clearGroup("minha_pos")
  })

  observe({
    proxy <- leafletProxy("map")
    dados_f <- dados_bares

    if (input$busca_bar != "Todos") dados_f <- dados_f |> filter(Nome == input$busca_bar)
    if (input$busca_petisco != "Todos" && input$busca_petisco != "") {
      dados_f <- dados_f |> filter(grepl(input$busca_petisco, Petisco, ignore.case = TRUE))
    }

    proxy |> clearGroup("bares_ativos")

    if (nrow(dados_f) > 0) {
      # Criação das labels em HTML para o efeito de hover
      labels <- lapply(seq(nrow(dados_f)), function(i) {
        HTML(paste0(
          "<b>", dados_f$Nome[i], "</b><br>",
          "<i>", dados_f$Endereco[i], "</i><br>",
          "Petisco: ", dados_f$Petisco[i]
        ))
      })

      proxy |> addCircleMarkers(
        data = dados_f, lng = ~long, lat = ~lat, radius = 8,
        fillColor = "#D32F2F", fillOpacity = 0.8, color = "white", weight = 2,
        stroke = TRUE,
        label = labels,
        labelOptions = labelOptions(
          style = list("font-weight" = "normal", padding = "3px 8px"),
          textsize = "13px",
          direction = "auto"
        ),
        popup = ~paste0("<b>", Nome, "</b><br>", Petisco),
        group = "bares_ativos"
      )

      if (!rv$show_panel) {
        if (nrow(dados_f) == 1) {
          proxy |> setView(lng = dados_f$long[1], lat = dados_f$lat[1], zoom = 17)
        } else {
          proxy |> fitBounds(lng1 = min(dados_f$long), lat1 = min(dados_f$lat),
                             lng2 = max(dados_f$long), lat2 = max(dados_f$lat))
        }
      }
    }
  })

  output$map <- renderLeaflet({
    leaflet() |> addProviderTiles(providers$Esri.WorldImagery) |> addProviderTiles(providers$CartoDB.PositronOnlyLabels)
  })

  output$ui_distancia <- renderUI({
    if (!rv$show_panel || is.null(rv$ranking)) return(NULL)
    df <- rv$ranking
    itens_html <- lapply(1:nrow(df), function(i) {
      div(class = "item-roteiro",
          strong(paste0(i, ". ", df$Nome[i])),
          htmltools::span(paste0(" (", df$dist_km[i], " km)"), style="color:#56A853; font-weight:bold;"),
          htmltools::span(class = "petisco-txt", df$Petisco[i]))
    })
    div(class = "distancia-painel", strong("Top Sugestões:", style="color:#EB7E00; font-size:15px; margin-bottom:10px; display:block;"), itens_html)
  })
}

options(shiny.launch.browser = TRUE)
shinyApp(ui, server)
