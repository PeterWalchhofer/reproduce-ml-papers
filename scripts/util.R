# Title     : TODO
# Objective : TODO
# Created by: Peter
# Created on: 20.05.2020

getNodes <- function(html, selector) {
  parsed <- sapply(html, function(x) {
    x %>%
      read_html() %>%
      html_nodes(paste0(selector)) %>%
      html_text() %>%
      str_remove_all("\n")
  }) %>%
    return
}

extract_commands <- function(df, col, cmd) {
  col <- enquo(col)
  df %>%
    unnest(!!col) %>%
    mutate(found = str_detect(str_to_lower(!!col), cmd)) %>%
    return
}

count_commands <- function(df, col, cmd) {
  col <- enquo(col)
  col_count_name <- paste0(cmd)#, "_count")
  df %>%
    left_join(extract_commands(df, !!col, cmd) %>%
                group_by(paper_url) %>%
                filter(found) %>%
                count(found) ,
              by = "paper_url") %>%
    ungroup() %>%
    mutate(n = if_else(is.na(n), 0L, n)) %>%
    rename(!!col_count_name := n) %>%
    select(-found)
}

count_lotsof_commands <- function(df, col, cmds) {
  col <- enquo(col)
  result <- df
  for (cmd in cmds) {
    result <- result %>% count_commands(!!col, cmd)
  }
  return(result)

}

count_file_name_occ <- function(df, list_of_regex) {
  result <- df
  for (regex in list_of_regex) {
    result <- result %>%
      mutate(!!regex := if_else(str_detect(str_to_lower(name), regex), 1, 0))
  }
  return(result %>%
           group_by(paper_url, repo_name) %>%
           summarize_at(vars(list_of_regex), function(x) sum(x)))
}