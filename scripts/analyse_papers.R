# Title     : TODO
# Objective : TODO
# Created by: Peter
# Created on: 20.05.2020
library(tidyverse)
library(RSQLite)
library(markdown)
library(rvest)
library(DBI)

source("scripts/util.R")

db_path <- "data/paper.db"
con <- dbConnect(SQLite(), db_path)

papers <- dbReadTable(con, "papers") %>%
  rename(paper_url = url)

repos <- dbReadTable(con, "../repos") %>%
  rename(repo_url = url, repo_name = name)

files <- dbReadTable(con, "files") %>%
  mutate(is_root = !str_detect(path,"/")) #%>%
  #left_join(repos, by=c(repo_name="name"))

repo_py_file <- files %>%
  mutate(py_file = str_detect(name, ".*\\.py")) %>%
  group_by(repo_name) %>%
  mutate(has_py_file = any(py_file)) %>%
  filter(row_number() == 1) %>%
  select(repo_name,has_py_file)


paper_repo <- papers %>%
  left_join(repos, by ="paper_url") %>%
  mutate(readme_html = sapply(readme, function(x) markdownToHTML(text = x)),
         code_snippets = getNodes(readme_html, "code")) %>%
  left_join(repo_py_file) %>%
  filter(has_py_file) %>%
  select(-has_py_file)

dbDisconnect(con)

list_of_commands <- c("train|fit", "eval", "requirements|environmen|setup", "docker")
gl_comformity_readme <- paper_repo %>%
   count_lotsof_commands(code_snippets,list_of_commands) %>%
  #mutate(dockerhub = str_detect(str_to_lower(readme),"hub\\.docker")) %>%
  select(-date, -authors, -Timestamp,-repo_url, -readme,-private, -readme_html) %>%
  rename(repo_name = name)

file_regexes <- c("train.*\\.py|fit.py", "eval.*\\.py", "requirements.txt|environment.yml|setup.py", "Dockerfile")
gl_comformity_files <- files %>%
  count_file_name_occ(file_regexes)

all_guideline_regex <- list_of_commands[1:(length(list_of_commands)-2)]
for (i in 1:(length(file_regexes)-2))
  all_guideline_regex <- c(all_guideline_regex, file_regexes[i])

fully_conform <- left_join(gl_comformity_readme, gl_comformity_files, by=c("paper_url", "repo_name")) %>%
  filter_at(vars(all_of(all_guideline_regex)), function (x) x > 0)
#TODO parse links to dockerhub