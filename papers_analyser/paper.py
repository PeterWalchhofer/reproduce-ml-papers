import gzip
import shutil
from typing import List

import pandas as pd
import requests
from bs4 import BeautifulSoup

from papers_analyser.repo import Repo

AUTHOR_TAG = "span.author-span"
SESSION = requests.Session()
BASE_URL = "http://paperswithcode.com"


class Paper:
    def __init__(self, url, soup=None, title=None, date=None, authors=None, github_urls=None,
                 arxiv_id=None, url_abs=None, url_pdf=None, tasks=None, repos=None):
        if tasks is None:
            tasks = list()
        if repos is None:
            repos = list()
        self.tasks = tasks
        self.url_pdf = url_pdf
        self.url_abs = url_abs
        self.arxiv_id = arxiv_id
        self.github_urls = github_urls
        self.authors = authors
        self.date = date
        self.title = title
        self.soup = soup
        self.url = url
        self.repos = repos

    def db_dict(self):
        return {"title": self.title,
                "url": self.url,
                "date": self.date.strftime("%Y-%m-%d"),
                "authors": ",".join(self.authors),
                "arxiv_id": self.arxiv_id,
                "url_abs": self.url_abs,
                "url_pdf": self.url_pdf,
                "tasks": ",".join(self.tasks)
                }

    def db_repo_dicts(self):
        result = list()
        for repo in self.repos:
            repo_dict = repo.db_dict()
            repo_dict["paper_url"] = self.url
            result.append(repo_dict)
        return result

    def repos_scraped(self):
        for repo in self.repos:
            if not repo.scraped:
                return False
        return True


def scrape_paper(url):
    """Scrape paperswithcode.com manually"""
    url = BASE_URL + url
    page = SESSION.get(url).content
    soup = BeautifulSoup(page, "html.parser")
    title = __parse_title(soup)
    date = __parse_date(soup)
    authors = __parse_authors(soup)
    github_urls = __parse_github_urls(soup)

    return Paper(url, soup, title, date, authors, github_urls)


def __parse_title(soup: BeautifulSoup):
    h1_list = soup.select("h1")
    if len(h1_list):
        return h1_list[0].text


def __parse_authors(soup: BeautifulSoup):
    authors_soup = soup.select(AUTHOR_TAG)
    authors = list()
    if len(authors_soup):
        for author in authors_soup[1:]:
            authors.append(author.text)
    return authors


def __parse_date(soup: BeautifulSoup):
    """Parse date of paper. Date is inside author-span html-tag."""
    authors_soup = soup.select("span.author-span")
    if len(authors_soup):
        return authors_soup[0].text


def __parse_github_urls(soup: BeautifulSoup):
    box = soup.select("#id_paper_implementations_expanded")[0]
    rows = box.select("div.col-md-7")
    github_urls = list()
    for row in rows:
        github_urls.append(row.a["href"])

    return github_urls


def __parse_github_clone_link(url: str):
    page = SESSION.get(url)
    soup = BeautifulSoup(page.content, "html.parser")
    box = soup.select("div.clone-options.https-clone-options")[0]
    return box.select("input")[0]["value"]


def download_json_files(path):
    """ Source: https://github.com/paperswithcode/paperswithcode-data"""
    papers_with_abstracts_url = "https://paperswithcode.com/media/about/papers-with-abstracts.json.gz"
    links_url = "https://paperswithcode.com/media/about/links-between-papers-and-code.json.gz"
    paper_zip_path = path + "/" +papers_with_abstracts_url.split("/")[-1]
    link_zip_path = path + "/" + links_url.split("/")[-1]

    __download_file(paper_zip_path, papers_with_abstracts_url)
    __download_file(link_zip_path, links_url)

    __unzip(paper_zip_path)
    __unzip(link_zip_path)

def __unzip(path: str):
    """ Source: https://stackoverflow.com/questions/31028815/how-to-unzip-gz-file-using-python"""
    if path.endswith(".gz"):
        with gzip.open(path, 'rb') as f_in:
            with open(path[:-3], 'wb') as f_out:
                shutil.copyfileobj(f_in, f_out)



def __download_file(path, url):
    """ Source: https://stackoverflow.com/questions/22676/how-do-i-download-a-file-over-http-using-python"""
    with SESSION.get(url, stream=True) as response:
        with open(path, "wb") as handle:
            shutil.copyfileobj(response.raw, handle)

def load_papers(path, since_date) -> List[Paper]:
    """Load papers from the json files provided at https://github.com/paperswithcode/paperswithcode-data and return a
    list of papers """
    merged_df = __load_json_files(path)
    filtered_df = merged_df[merged_df["date"] > since_date]
    filtered_df.set_index("paper_url")
    papers = list()

    # Duplicates due to multiple repo referencing one paper
    for k, g in filtered_df.groupby("paper_url"):
        papers_eq_link_list = (list(g.T.to_dict().values()))
        paper = __dict_to_paper(papers_eq_link_list[0])
        for paper_repo_dict in papers_eq_link_list[1:]:
            repo_url = paper_repo_dict["repo_url"]
            if repo_url not in paper.github_urls:
                paper.github_urls.append(repo_url)
                paper.repos.append(__dict_to_repo(paper_repo_dict))
        papers.append(paper)

    return papers


def __load_json_files(path):
    with open(path + "/links-between-papers-and-code.json") as links_to_github_file, \
            open(path + "/papers-with-abstracts.json") as papers_file:
        links_to_github, papers = pd.read_json(links_to_github_file), pd.read_json(papers_file)
        merged_df = pd.merge(links_to_github, papers, on="paper_url")
        return merged_df


def __dict_to_paper(paper_dict):
    paper_url = paper_dict["paper_url"]
    arxiv_id = paper_dict["arxiv_id"]
    title = paper_dict["title"]
    url_abs = paper_dict["url_abs"]
    url_pdf = paper_dict["url_pdf"]
    authors = paper_dict["authors"]
    tasks = paper_dict["tasks"]
    date = paper_dict["date"]
    github_urls = list()
    github_urls.append("repo_url")
    repos = list()
    repo = __dict_to_repo(paper_dict)
    repos.append(repo)
    return Paper(url=paper_url, title=title, date=date, authors=authors, arxiv_id=arxiv_id, url_abs=url_abs,
                 url_pdf=url_pdf, tasks=tasks, repos=repos, github_urls=github_urls)


def __dict_to_repo(paper_dict):
    repo_url = paper_dict["repo_url"]
    framework = paper_dict["framework"]
    mentioned_in_paper = paper_dict["mentioned_in_paper"]
    mentioned_in_github = paper_dict["mentioned_in_github"]
    return Repo(repo_url, framework=framework, mentioned_in_paper=mentioned_in_paper,
                mentioned_in_github=mentioned_in_github)
