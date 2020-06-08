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

end_date <- as.Date("2020-05-31", "%Y-%m-%d")
source("scripts/util.R")

db_path <- "data/paper.db"
con <- dbConnect(SQLite(), db_path)

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
         readme_html = sapply(readme, function(x) markdownToHTML(text = x)))%>%
  filter(date<=end_date)

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

most_used_titles <- paper_repo_analysed %>%
  unnest(titles) %>%
  group_by(titles) %>% count()


commands_rm <- c("train|fit", "eval", "pip\\sinstall", "requirements|environment|env", "docker")
gl_comformity_readme <- paper_repo_analysed %>%
  count_lotsof_commands(code_snippets, commands_rm) %>%
  #mutate(dockerhub = str_detect(str_to_lower(readme),"hub\\.docker")) %>%
  select(-authors, -Timestamp, -repo_url, -readme_old, -private)

file_regexes <- c(".*train.*\\.py|fit.*\\.py|train.*\\.sh\\.sh|fit.*\\.sh", ".*eval.*\\.py",
                  "requirements.txt|environment.yml|setup.py", "Dockerfile")
gl_comformity_files <- files %>%
  count_file_name_occ(file_regexes)

# For train and eval, there has to be a description in the readme and a file that contains the name
# For the dependencies, it is sufficient to provide pip commands in the readme, without having a requirements.txt file
# However, if just a requirements.txt file is provided, there is no need for providing a command.
# Idea: List of vectors - Column names of inner vectors are being connected with AND, which means that each occurance
# has to be >0. Outer vectors with OR, which means one of the occurrances has to be > 0.
train_satisfaction_rm <- list(c(commands_rm[1], file_regexes[1]))
eval_satisfaction_rm <- list(c(commands_rm[2], file_regexes[2]))
requ_satisfaction_rm <- list(c(file_regexes[3]), c(commands_rm[3]), c(commands_rm[5]), c(file_regexes[4]))

guidline_satisfactory <- left_join(gl_comformity_readme, gl_comformity_files, by = "repo_name") %>%
  check_satisfaction(train_satisfaction_rm, "train_sat") %>%
  check_satisfaction(eval_satisfaction_rm, "eval_sat") %>%
  check_satisfaction(requ_satisfaction_rm, "req_sat")

full_satisfactory_rm <- guidline_satisfactory %>%
  filter(train_sat & req_sat & eval_sat)

prefix_aut_code <- c("python.?\\s", "conda\\s", "sh\\s")
commands_aut_code <- c("train","fit", ".*eval.*")

aut_commands <- command_concat(prefix_aut_code, commands_aut_code)

train_satisfaction_aut <- list(c(aut_commands[1], file_regexes[1]), c(aut_commands[2], file_regexes[1]))
eval_satisfaction_aut <- list(c(aut_commands[3], file_regexes[2]))
requ_satisfaction_aut <- list(c(file_regexes[3]), c(file_regexes[4]))

automatation_satisfactory <- paper_repo_analysed %>%
  count_lotsof_commands(code_snippets, aut_commands) %>%
  left_join(gl_comformity_files, by="repo_name") %>%
  check_satisfaction(requ_satisfaction_aut, "req_sat") %>%
  check_satisfaction(eval_satisfaction_aut, "eval_sat") %>%
  check_satisfaction(train_satisfaction_aut, "train_sat")
  #filter_at(vars(unlist(aut_commands)), any_vars(.>0))

full_satisfactory_automation <- automatation_satisfactory %>%
  filter(train_sat & req_sat & eval_sat)
#TODO parse links to dockerhub
#TODO parse  automatable repos

#TODO check for validity
plotable <- guidline_satisfactory %>%
  mutate(month = month(date), year = year(date)) %>%
  group_by(month, year) %>%
  summarise_at(vars(c("train_sat","eval_sat", "req_sat")), function (x) sum(x)/n())

time_rm_sat_plot <- ggplot(plotable, aes(x=month, y=1))+
  geom_line(aes(x=month, y=train_sat, color="train")) +
  geom_line(aes(x=month, y=eval_sat, color="eval")) +
  geom_line(aes(x=month, y=req_sat, color="req"))

time_rm_sat_plot
