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

getUrls <- function(html) {
  parsed <- sapply(html, function(x) {
    x %>%
      read_html() %>%
      html_nodes("a") %>%
      html_attr("href")
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
  col_count_name <- paste0(cmd) #, "_count")
  df %>%
    left_join(extract_commands(df, !!col, cmd) %>%
                group_by(paper_url) %>%
                filter(found) %>%
                count(found),
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
      mutate(!!regex := as.integer(if_else(str_detect(str_to_lower(name), regex),
                                           1, 0)))
  }
  return(result %>%
           group_by(repo_name) %>%
           summarize_at(vars(all_of(list_of_regex)), function(x) sum(x)))
}

get_paragraph_urls <- function(html, title1, title2) {
  if (is.null(title2)) {
    xpath <- paste0("//h2[preceding-sibling::h2 = '", title1, "']")
  }else {
    xpath <- paste0("//h2[preceding-sibling::h2 = '", title1, "' and following-sibling::h2 = '", title2, "']")
  }

  xpath <-

    parsed <- sapply(html, function(x) {
      tryCatch({
                 page <- read_html(x)

                 # Make sure you scope on the content of the website
                 content <- html_node(page, "#mw-content-text")
                 headlines <- html_nodes(content, "h2")
                 xpath <- sprintf("./p[count(preceding-sibling::h2)=%d]", seq_along(headlines) - 1)
                 map(xpath, ~html_nodes(x = content, xpath = .x)) %>% # Get the text inside the headlines
                   map(html_text, trim = TRUE) %>% # get per node in between
                   map_chr(paste, collapse = "\n") %>%
                   html_text() %>%
                   return

               }, return(NA))
    }) %>%
      return

}

check_satisfaction <- function(df, sat_vec, name) {
  to_or <- NULL

  for (sat_group in sat_vec) {
    satisfy_and <- df %>%
      filter_at(vars(all_of(sat_group)), all_vars(. > 0))

    if (is.null(to_or)) {
      to_or <- satisfy_and %>% select(repo_name)
      #to_or %>% View()
    } else {
      to_or <- bind_rows(to_or, satisfy_and %>% select(repo_name)) %>% distinct()
      #to_or %>% View()
    }
  }
  return(df %>% mutate(!!name := repo_name %in% to_or$repo_name))
}

command_concat <- function(prefix_aut_code, commands_aut_code) {
  commands <- list()
  i <- 1
  for (com in commands_aut_code) {
    command <- ""
    for (prefix in prefix_aut_code) {
      command <- paste0(command, prefix, com, "|")
    }
    commands[[i]] <- substr(command, 1, nchar(command) - 1)
    i <- i + 1
  }
  return(unlist(commands))
}