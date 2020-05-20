from typing import Dict, List

import requests
from bs4 import BeautifulSoup
from urllib import parse
import papers_analyser.github as github
from urllib3.util import Url

AUTHOR_TAG = "span.author-span"
SESSION = requests.Session()
BASE_URL = "http://paperswithcode.com"


class Paper:
    def __init__(self, url: str):
        self.url = BASE_URL + url
        page = requests.get(self.url).content
        self.soup = BeautifulSoup(page, "html.parser")
        self.title = parse_title(self.soup)
        self.date = parse_date(self.soup).text
        self.authors = parse_authors(self.soup)
        self.repos = list()
        github_urls = parse_github_urls(self.soup)
        for url in github_urls:
            self.repos.append(Repo(url, SESSION))

    def db_dict(self):
        return {"title": self.title,
                "url": self.url,
                "date": self.date,
                "authors": ",".join(self.authors)}

    def db_repo_dicts(self):
        result = list()
        for repo in self.repos:
            repo_dict = repo.db_dict()
            repo_dict["paper_title"] = self.title
            result.append(repo_dict)
        return result


def parse_title(soup: BeautifulSoup):
    h1_list = soup.select("h1")
    if len(h1_list):
        return h1_list[0].text


def parse_authors(soup: BeautifulSoup):
    authors_soup = soup.select(AUTHOR_TAG)
    authors = list()
    if len(authors_soup):
        for author in authors_soup[1:]:
            authors.append(author.text)
    return authors


def get_repo(url):
    return Repo(url, SESSION)


def parse_date(soup: BeautifulSoup):
    """Parse date of paper. Date is inside author-span html-tag."""
    authors_soup = soup.select("span.author-span")
    if len(authors_soup):
        return authors_soup[0]


def parse_github_urls(soup: BeautifulSoup):
    box = soup.select("#id_paper_implementations_expanded")[0]
    rows = box.select("div.col-md-7")
    github_urls = list()
    for row in rows:
        github_urls.append(row.a["href"])

    return github_urls


def parse_github_clone_link(url: str):
    page = requests.get(url)
    soup = BeautifulSoup(page.content, "html.parser")
    box = soup.select("div.clone-options.https-clone-options")[0]
    return box.select("input")[0]["value"]


class Repo:
    def __init__(self, url, session):
        self.repo_url = url
        self.clone_url = url + ".git"
        self.repo_name = parse.urlparse(url).path
        self.files = github.get_file_tree(self.repo_name, session)
        self.readme = github.get_readme(self.repo_name, session)

    def db_dict(self):
        return dict(
            name=self.repo_name,
            readme=self.readme,
            url=self.repo_url
        )

    def db_file_dicts(self):
        file_dicts = list()
        for file in self.files:
            file_dict = file.db_dict()
            file_dict["repo_name"] = self.repo_name
            file_dicts.append(file_dict)
        return file_dicts

