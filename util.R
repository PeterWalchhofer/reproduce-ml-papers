# Title     : TODO
# Objective : TODO
# Created by: Peter
# Created on: 20.05.2020

getNodes <- function(html, selector) {
  parsed <- sapply(html, function(x) {
    x %>% read_html() %>%
      html_nodes(paste0(selector)) %>%
      html_text() %>%
      str_remove_all("\n")
  }) %>%
    return
}

extract_command<- function (list_commands, cmd){
  list_commands %>%
}