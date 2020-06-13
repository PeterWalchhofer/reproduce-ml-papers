import base64
import json
import time

import requests
import yaml

API_URL = "https://api.github.com/repos"
MASTER_SUFFIX = "branches/master"
TREE_SUFFIX = "git/trees/"
RECURSIVE_PARAM = "?recursive=true"


def load_auth_token(path):
    config = yaml.load(open(path, "r"))
    try:
        return config["auth_token"]
    except KeyError:
        print("No configuration file with auth_token found.")
        return None


def get_file_tree(repo, session, auth_token=None, root_only=False):
    api_url = API_URL + repo
    sha = __get_sha(api_url, session, auth_token=auth_token)
    time.sleep(1)
    rec_param = RECURSIVE_PARAM

    if root_only:
        rec_param = ""

    file_tree_response = __get(session, api_url + "/" + TREE_SUFFIX + sha + rec_param, auth_token=auth_token)
    file_tree = json.loads(file_tree_response.content)

    return __parse_file_tree(file_tree["tree"])


def get_sub_dir(repo, session, path=None, auth_token=None, root_only=False):
    if "tree/master" in repo:
        split_repo_url = repo.split("tree/master")
        repo = split_repo_url[0]
        if path is None:
            path = split_repo_url[1] if len(split_repo_url) > 1 else ""
    api_url = API_URL + repo + "contents/" + path

    rec_param = RECURSIVE_PARAM

    if root_only:
        rec_param = ""

    url = api_url + "/" + rec_param
    url.replace("//", "/")
    file_tree_response = __get(session, url, auth_token=auth_token)
    file_tree = json.loads(file_tree_response.content)
    if type(file_tree) == list:
        return __parse_file_tree(file_tree)
    else:
        return None

def __get_sha(api_url, session: requests.Session, auth_token=None):
    url = api_url + "/" + MASTER_SUFFIX
    response = __get(session, url, auth_token=auth_token)
    parsed_response = json.loads(response.content)
    return parsed_response['commit']['commit']['tree']['sha']


def __parse_file_tree(tree):
    github_files = list()
    for file in tree:
        path = __get_dict_value("path", file)
        size = __get_dict_value("size", file)
        url = __get_dict_value("url", file)
        name = path.split("/")[-1]
        github_files.append(File(name, path, size, url))

    return github_files


def __get(session: requests.Session, url, auth_token=None):
    if auth_token is not None:
        response = session.get(url, headers={"Authorization": "token " + auth_token})
    else:
        response = session.get(url)
    status_code = response.status_code
    if status_code != 200:
        response.raise_for_status()
    return response


def __get_dict_value(key_regex, my_dict):
    for key, value in my_dict.items():  # iter on both keys and values
        if key.startswith(key_regex):
            return value


def get_readme(repo_name, session, auth_token=None, url=None):
    if url is None:
        url = API_URL + repo_name + "/readme"
    response = __get(session, url, auth_token=auth_token)
    parsed_response = json.loads(response.content)
    readme = __get_dict_value("content", parsed_response)
    if readme:
        return base64.b64decode(readme).decode("utf-8")


def get_repo_metadata(repo_name, session, auth_token=None):
    response = __get(session, API_URL + repo_name, auth_token)
    parsed_response = json.loads(response.content)
    stars = parsed_response["stargazers_count"]
    lang = parsed_response["language"]
    forks = parsed_response["forks_count"]
    return dict(stars=stars, lang=lang, forks=forks)


class File:
    def __init__(self, name, path, size, url):
        self.url = url
        self.path = path
        self.name = name
        self.size = size

    def db_dict(self):
        return vars(self)
