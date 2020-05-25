import requests
from bs4 import BeautifulSoup

from papers_analyser.repo import get_repo

AUTHOR_TAG = "span.author-span"
SESSION = requests.Session()
BASE_URL = "http://paperswithcode.com"


class Paper:
    def __init__(self, url, soup, title, date, authors, github_urls):
        self.github_urls = github_urls
        self.authors = authors
        self.date = date
        self.title = title
        self.soup = soup
        self.url = url
        self.repos = list()

    def scrape_repos(self, auth_token=None):
        if not self.github_urls:
            raise AttributeError("Github_urls attribute is empty.")
        for url in self.github_urls:
            self.repos.append(get_repo(url, auth_token))

    def db_dict(self):
        return {"title": self.title,
                "url": self.url,
                "date": self.date,
                "authors": ",".join(self.authors)}

    def db_repo_dicts(self):
        result = list()
        for repo in self.repos:
            repo_dict = repo.db_dict()
            repo_dict["paper_url"] = self.url
            result.append(repo_dict)
        return result


def scrape_paper(url):
    url = BASE_URL + url
    page = SESSION.get(url).content
    soup = BeautifulSoup(page, "html.parser")
    title = parse_title(soup)
    date = parse_date(soup)
    authors = parse_authors(soup)
    github_urls = parse_github_urls(soup)

    return Paper(url, soup, title, date, authors, github_urls)


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


def parse_date(soup: BeautifulSoup):
    """Parse date of paper. Date is inside author-span html-tag."""
    authors_soup = soup.select("span.author-span")
    if len(authors_soup):
        return authors_soup[0].text



def parse_github_urls(soup: BeautifulSoup):
    box = soup.select("#id_paper_implementations_expanded")[0]
    rows = box.select("div.col-md-7")
    github_urls = list()
    for row in rows:
        github_urls.append(row.a["href"])

    return github_urls


def parse_github_clone_link(url: str):
    page = SESSION.get(url)
    soup = BeautifulSoup(page.content, "html.parser")
    box = soup.select("div.clone-options.https-clone-options")[0]
    return box.select("input")[0]["value"]
