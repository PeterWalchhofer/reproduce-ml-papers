# Title     : TODO
# Objective : TODO
# Created by: Peter
# Created on: 20.05.2020
library(tidyverse)
library(urltools)
library(RSQLite)
library(markdown)
library(rvest)
library(lubridate)
library(DBI)
library(stringi)
library(reshape2)

end_date <- as.Date("2020-05-31", "%Y-%m-%d")
source("scripts/util.R")

db_path <- "data/paper.db"
con <- dbConnect(SQLite(), db_path)

papers <- dbReadTable(con, "papers") %>%
  rename(paper_url = url) %>%
  mutate(date = as.Date(date)) #%>%
#left_join(repos %>%
#            group_by(paper_url) %>%
#            count(name = "repo_count"), by = "paper_url") %>%
#mutate(missing_repo = !paper_url %in% repos$paper_url)

repos <- dbReadTable(con, "repos") %>%
  rename(repo_url = url, repo_name = name) %>%
  filter(paper_url %in% papers$paper_url)
Encoding(repos$readme) <- "UTF-8"
repos <- repos %>%
  rename(readme_old = readme) %>%
  mutate(readme = iconv(readme_old, "UTF-8", "UTF-8", "")) %>%
  mutate(readme = suppressWarnings(repair_encoding(readme, from = "UTF-8"))) %>%
  mutate(readme = if_else(is.na(readme), "", readme)) %>%
  mutate(readme_html = sapply(readme, function(x) md_to_html(x)))


files <- dbReadTable(con, "files") %>%
  mutate(is_root = !str_detect(path, "/")) #%>%
#left_join(repos, by=c(repo_name="name"))

repo_stats <- files %>%
  mutate(py_file = str_detect(name, ".*\\.py")) %>%
  group_by(repo_name) %>%
  mutate(has_py_file = any(py_file), one_file = n() == 1, only_readme = one_file & str_detect(str_to_lower(name), "readme")) %>%
  filter(row_number() == 1) %>%
  select(repo_name, has_py_file, only_readme) %>%
  mutate(empty = FALSE) %>%
  rbind(anti_join(repos %>%
                    distinct(repo_name), ., by = "repo_name") %>%
          mutate(has_py_file = FALSE, only_readme = FALSE, empty = TRUE) %>%
          select(repo_name, has_py_file, only_readme, empty))

# There is a problem with utf-8 encoding and emojis, which I did not manage to solve with iconv()
# The emojis and some other chinese symbols are just removed.

paper_repo <- papers %>%
  left_join(repos, by = "paper_url") %>%
  filter(date <= end_date)



paper_repo_analysed <- paper_repo %>%
  mutate(code_snippets = getNodes(readme_html, "code"),
         titles = getNodes(readme_html, "h2"),
         pre_trained_urls = get_paragraph_urls(readme_html, "Pretrained models", NULL)) %>%
  mutate(conversion_error = readme != readme_old) %>%
  left_join(repo_stats) %>%
  filter(has_py_file) %>%
  select(-has_py_file)

dbDisconnect(con)

repos_containing_pre_trained <- paper_repo_analysed %>%
  filter(str_detect(str_to_lower(readme_old), "[pre]?-?trained\\smodel"))

pre_trained_domains <- repos_containing_pre_trained %>%
  mutate(urls = getUrls(readme_html)) %>%
  select(repo_name, urls) %>%
  unnest(urls, keep_empty = TRUE) %>%
  filter(startsWith(urls, "http")) %>%
  mutate(domain = domain(urls))

pre_trained_domains_counted <- pre_trained_domains %>%
  group_by(domain, repo_name) %>%
  filter(row_number() == 1) %>%
  group_by(domain) %>%
  count() %>%
  arrange(-n)

domain_cat <- read_csv("categorisation/domain_model_cat.csv") %>%
  filter(!is.na(hosting) | !is.na(model)) %>%
  select(domain)

papers_refer_hosting <- repos_containing_pre_trained %>%
  left_join(pre_trained_domains %>%
              mutate(storage = domain %in% domain_cat$domain) %>%
              group_by(repo_name) %>%
              mutate(refers_to_hosting_page = any(storage)) %>%
              filter(row_number() == 1) %>%
              select(repo_name, refers_to_hosting_page)) %>%
  group_by(paper_url) %>%
  mutate(refers_to_hosting_page = if_else(is.na(refers_to_hosting_page), FALSE, refers_to_hosting_page)) %>%
  mutate(one_repo_refers_to_hosting_page = any(refers_to_hosting_page)) %>%
  filter(row_number() == 1)

#pre_trained_domains %>% arrange(-n) %>% write_csv("categorisation/domain_model_cat_2.csv")


commands_rm <- c("train|fit", "eval", "pip\\sinstall", "requirements|environment|env", "docker")
gl_comformity_readme <- paper_repo_analysed %>%
  count_lotsof_commands(code_snippets, commands_rm) %>%
  #mutate(dockerhub = str_detect(str_to_lower(readme),"hub\\.docker")) %>%
  select(-authors, -Timestamp, -repo_url, -readme_old, -private)

file_regexes <- c(".*train.*\\.py|fit.*\\.py|train.*\\.sh\\.sh|fit.*\\.sh", ".*eval.*\\.py",
                  "requirements.txt|environment.yml|setup.py", "dockerfile")
gl_comformity_files <- files %>%
  count_file_name_occ(file_regexes)

# For train and eval, there has to be a description in the readme and a file that contains the name
# For the dependencies, it is sufficient to provide pip commands in the readme, without having a requirements.txt file
# However, if just a requirements.txt file is provided, there is no need for providing a command.
# Idea: List of vectors - Column names of inner vectors are being connected with AND, which means that each occurance
# has to be >0. Outer vectors with OR, which means one of the occurrances has to be > 0.
train_satisfaction_rm <- list(c(commands_rm[1], file_regexes[1]))
eval_satisfaction_rm <- list(c(commands_rm[2], file_regexes[2]))
requ_satisfaction_rm <- list(c(file_regexes[3]), c(file_regexes[4]))

low_gl_satisfactory <- left_join(gl_comformity_readme, gl_comformity_files, by = "repo_name") %>%
  check_satisfaction(train_satisfaction_rm, "train_sat") %>%
  check_satisfaction(eval_satisfaction_rm, "eval_sat") %>%
  check_satisfaction(requ_satisfaction_rm, "req_sat") %>%
  mutate(full_sat = train_sat & req_sat & eval_sat)

full_satisfactory_rm <- low_gl_satisfactory %>%
  filter(train_sat & req_sat & eval_sat)

prefix_aut_code <- c("python.?\\s", "conda\\s", "sh\\s")
commands_aut_code <- c("train", "fit", ".*eval.*")

aut_commands <- command_concat(prefix_aut_code, commands_aut_code)

train_satisfaction_aut <- list(c(aut_commands[1], file_regexes[1]), c(aut_commands[2], file_regexes[1]))
eval_satisfaction_aut <- list(c(aut_commands[3], file_regexes[2]))
requ_satisfaction_aut <- list(c(file_regexes[3]), c(file_regexes[4]))

automatation_satisfactory <- paper_repo_analysed %>%
  count_lotsof_commands(code_snippets, aut_commands) %>%
  left_join(gl_comformity_files, by = "repo_name") %>%
  check_satisfaction(requ_satisfaction_aut, "req_sat") %>%
  check_satisfaction(eval_satisfaction_aut, "eval_sat") %>%
  check_satisfaction(train_satisfaction_aut, "train_sat")
#filter_at(vars(unlist(aut_commands)), any_vars(.>0))




paper_amount_month <- papers %>%
  left_join(repos, by = "paper_url") %>%
  left_join(repo_stats, by = "repo_name") %>%
  group_by(paper_url, date) %>%
  mutate(has_py_repo = any(has_py_file), all_repos_empty = all(empty), all_repos_readme_only = all(only_readme)) %>%
  filter(row_number() == 1) %>%
  mutate(year_month = floor_date(ymd(date), "month")) %>%
  group_by(year_month, has_py_repo, all_repos_empty, all_repos_readme_only) %>%
  count()

paper_amount_month_mentioned_paper <- papers %>%
  left_join(repos, by = "paper_url") %>%
  filter(mentioned_in_paper == 1) %>%
  left_join(repo_stats, by = "repo_name") %>%
  group_by(paper_url, date) %>%
  mutate(has_py_repo = any(has_py_file), all_repos_empty = all(empty), all_repos_readme_only = all(only_readme)) %>%
  filter(row_number() == 1) %>%
  mutate(year_month = floor_date(ymd(date), "month")) %>%
  group_by(year_month, has_py_repo, all_repos_empty, all_repos_readme_only) %>%
  count()

aut_gl_plotable <- automatation_satisfactory %>%
  mutate(year_month = floor_date(ymd(date), "month")) %>%
  group_by(year_month) %>%
  summarise_at(vars(c("train_sat", "eval_sat", "req_sat")), function(x) sum(x) / n())


#TODO if there is no master branch, files is NA
