# Title     : TODO
# Objective : TODO
# Created by: Peter
# Created on: 20.05.2020
library(tidyverse)
library(urltools)
library(RSQLite)
library(markdown)
library(rvest)
library(DBI)
library(stringi)

source("scripts/util.R")

db_path <- "data/paper.db"
con <- dbConnect(SQLite(), db_path)
db_list_tables(con)
papers <- dbReadTable(con, "papers") %>%
  rename(paper_url = url)

repos <- dbReadTable(con, "repos") %>%
  rename(repo_url = url, repo_name = name)

files <- dbReadTable(con, "files") %>%
  mutate(is_root = !str_detect(path, "/")) #%>%
#left_join(repos, by=c(repo_name="name"))

repo_py_file <- files %>%
  mutate(py_file = str_detect(name, ".*\\.py")) %>%
  group_by(repo_name) %>%
  mutate(has_py_file = any(py_file)) %>%
  filter(row_number() == 1) %>%
  select(repo_name, has_py_file)


# There is a problem with utf-8 encoding and emojis, which I did not manage to solve with iconv()
# The emojis and some other chinese symbols are just removed.
paper_repo <- papers %>%
  left_join(repos, by = "paper_url") %>%
  rename(readme_old = readme) %>%
  mutate(readme = suppressWarnings(repair_encoding(readme_old, from = "UTF-8")),
         readme_html = sapply(readme, function(x) markdownToHTML(text = x)))
paper_repo_analysed <- paper_repo %>%
  mutate(code_snippets = getNodes(readme_html, "code"),
         titles = getNodes(readme_html, "h2"),
         pre_trained_urls = get_paragraph_urls(readme_html, "Pretrained models", NULL)) %>%
  mutate(conversion_error = readme != readme_old) %>%
  left_join(repo_py_file) %>%
  filter(has_py_file) %>%
  select(-has_py_file)

dbDisconnect(con)

most_reference_domains <- paper_repo_analysed %>%
  mutate(urls = getUrls(readme_html)) %>%
  select(paper_url, urls) %>%
  unnest(urls) %>%
  mutate(domain = domain(urls)) %>%
  group_by(domain) %>%
  count()


list_of_commands <- c("train|fit", "eval", "pip\\sinstall", "requirements|environment|env", "docker")
gl_comformity_readme <- paper_repo_analysed %>%
  count_lotsof_commands(code_snippets, list_of_commands) %>%
  #mutate(dockerhub = str_detect(str_to_lower(readme),"hub\\.docker")) %>%
  select(-date, -authors, -Timestamp, -repo_url, -readme_old, -private)

file_regexes <- c(".*train.*\\.py|fit.*\\.py|train.*\\.sh\\.sh|fit.*\\.sh", ".*eval.*\\.py", "requirements.txt|environment.yml|setup.py", "Dockerfile")
gl_comformity_files <- files %>%
  count_file_name_occ(file_regexes)

# For train and eval, there has to be a description in the readme and a file that contains the name
# For the dependencies, it is sufficient to provide pip commands in the readme, without having a requirements.txt file
# However, if just a requirements.txt file is provided, there is no need for providing a command.
# Idea: List of vectors - elements of inner vectors are being connected with AND. Outer vectors with OR.
train_satisfaction <- list(c(list_of_commands[1], file_regexes[1]))
eval_satisfaction <- list(c(list_of_commands[2], file_regexes[2]))
requ_satisfaction <- list(c(file_regexes[3]), c(list_of_commands[3]), c(list_of_commands[5]))

guidline_satisfactory <- left_join(gl_comformity_readme, gl_comformity_files, by = "repo_name") %>%
  fullfills_satisfaction(train_satisfaction, "train_sat") %>%
  fullfills_satisfaction(eval_satisfaction, "eval_sat") %>%
  fullfills_satisfaction(requ_satisfaction, "req_sat")

full_satisfactory <- guidline_satisfactory %>%
  filter(train_sat & req_sat & eval_sat)

prefix <- c("python.?\\s", "conda\\s", "sh\\s")
commands_to_run <- c("python.?\\strain|python.?\\sfit|train.*\\.sh")
#TODO parse links to dockerhub
#TODO parse  automatable repos
