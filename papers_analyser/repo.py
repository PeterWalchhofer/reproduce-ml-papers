from urllib import parse

import requests

from papers_analyser import github as github

SESSION = requests.Session()


class Repo:
    def __init__(self, repo_url, framework=None, clone_url=None, repo_name=None, files=None, readme=None, private=None,
                 mentioned_in_github=None, mentioned_in_paper=None, stars=None, forks=None, lang=None):
        self.lang = lang
        self.forks = forks
        self.stars = stars
        self.mentioned_in_github = mentioned_in_github
        self.mentioned_in_paper = mentioned_in_paper
        self.framework = framework
        self.readme = readme
        self.files = files
        self.repo_name = repo_name
        self.clone_url = clone_url
        self.repo_url = repo_url
        self.private = private
        self.scraped = False

    def db_dict(self):
        return dict(
            name=self.repo_name,
            readme=self.readme,
            url=self.repo_url,
            private=1 if self.private else 0,
            framework=self.framework,
            mentioned_in_paper=1 if self.mentioned_in_paper else 0,
            mentioned_in_github=1 if self.mentioned_in_github else 0,
            stars=self.stars,
            lang=self.lang,
            forks=self.forks
        )

    def db_file_dicts(self):
        file_dicts = list()
        for file in self.files:
            file_dict = file.db_dict()
            file_dict["repo_name"] = self.repo_name
            file_dicts.append(file_dict)
        return file_dicts

    def scrape(self, auth_token=None):
        self.clone_url = self.repo_url + ".git"
        self.repo_name = parse.urlparse(self.repo_url).path
        self.private = False
        self.files = []
        self.readme = None
        try:
            self.files = github.get_file_tree(self.repo_name, SESSION, auth_token)
            self.readme = github.get_readme(self.repo_name, SESSION, auth_token)
            repo_meta = github.get_repo_metadata(self.repo_name, SESSION, auth_token)
            self.stars = repo_meta["stars"]
            self.lang = repo_meta["lang"]
            self.forks = repo_meta["forks"]
            self.scraped = True
        except requests.HTTPError as err:
            if err.response.status_code == 403:
                str(err)
                if not auth_token:
                    print("WARNING: No auth-token specified. Rate Limit will be exceeded easily.")
