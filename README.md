# 🍻 Roteirizador Comida di Buteco 2026 - Ribeirão Preto

[![R](https://img.shields.io/badge/R-276DC3?style=for-the-badge&logo=r&logoColor=white)](https://www.r-project.org/)
[![Shiny](https://img.shields.io/badge/Shiny-3165F5?style=for-the-badge&logo=RStudio&logoColor=white)](https://shiny.rstudio.com/)

Aplicação interativa desenvolvida em R e Shiny para otimização de rotas gastronômicas do festival Comida di Buteco 2026 em Ribeirão Preto/SP. 

O projeto resolve um problema logístico real: transformar uma lista estática de bares em um mapa inteligente que calcula distâncias em tempo real a partir da localização do usuário.

🔗 **[Acesse a Aplicação Ao Vivo no ShinyApps.io](https://ojeancarlo.shinyapps.io/LocalizaDiButecoRP/)**
📖 **[Leia o artigo completo sobre a arquitetura no Medium](COLE_AQUI_O_LINK_DO_MEDIUM)**

## Funcionalidades e Itens Técnicos

- **Web Scraping (ETL):** Extração automatizada de dados (Nome, Endereço, Petisco) do portal ACidade ON utilizando `rvest` e manipulação via RegEx com `stringr`.
- **Geolocalização:** Conversão de endereços em coordenadas geográficas via API do ArcGIS utilizando o pacote `tidygeocoder`.
- **Sistema de Cache Inteligente:** Para evitar o esgotamento de requisições e lentidão, o script gera um cache local (`.rds`). Se o arquivo for do dia atual, o app carrega, pulando o scraping.
- **Espacialidade:** Cálculo preciso de distâncias em linha reta utilizando a **Fórmula de Haversine** (`geosphere`).
- **UX/UI Customizada:** Interface nativa e responsiva construída com injeção de CSS e renderização dinâmica de labels e mapas via `leaflet`.

## Tecnologias utilizadas

- **Linguagem:** R
- **Frontend/Backend Web:** Shiny, htmltools
- **Manipulação e Limpeza:** dplyr, stringr
- **Scraping:** rvest
- **Geolocalização e Mapas:** leaflet, leaflet.extras, tidygeocoder, geosphere

## Para executar localmente

1. Clone o repositório:
```bash
git clone [https://github.com/ojeancarlo/appDiButeco.git](https://github.com/ojeancarlo/appDiButeco.git)