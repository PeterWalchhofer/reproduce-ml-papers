# Title     : TODO
# Objective : TODO
# Created by: Peter
# Created on: 20.05.2020
library(tidyverse)
library(RSQLite)
library(markdown)
library(rvest)
library(DBI)

source("util.R")

db_path <- "paper.db"
con <- dbConnect(SQLite(), db_path)

papers <- dbReadTable(con, "papers") %>%
  rename(paper_url = url)
files <- dbReadTable(con, "files")
repos <- dbReadTable(con, "repos") %>%
  rename(repo_url = url)
dbDisconnect(con)

paper_repo <- papers %>%
  left_join(repos, by = c("title" = "paper_title")) %>%
  mutate(readme_html = sapply(readme, function(x) markdownToHTML(text = x)),
         bash_snippets = getNodes(readme_html, ".bash"), code_snippets = getNodes(readme_html, "code"))

gl_comformity <- paper_repo %>%
  unnest(bash_snippets)
  mutate(has_train = str_detect((code_snippets), "train"))
