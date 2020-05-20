import time
from urllib import parse
import base64

from ppretty.ppretty import ppretty
import requests
import json

API_URL = "https://api.github.com/repos"
MASTER_SUFFIX = "branches/master"
TREE_SUFFIX = "git/trees/"
RECURSIVE_PARAM = "?recursive=true"


def get_file_tree(repo, session):
    api_url = API_URL + repo
    sha = __get_sha(api_url, session)
    file_tree_response = __get(session, api_url + "/" + TREE_SUFFIX + sha + RECURSIVE_PARAM)
    file_tree = json.loads(file_tree_response.content)
    time.sleep(1)
    return __parse_file_tree(file_tree)


def __get_sha(api_url, session: requests.Session):
    url = api_url + "/" + MASTER_SUFFIX
    response = __get(session, url)
    parsed_response = json.loads(response.content)
    return parsed_response['commit']['commit']['tree']['sha']


def __parse_file_tree(tree_object):
    tree = tree_object["tree"]
    github_files = list()
    for file in tree:
        path = __get_dict_value("path", file)
        size = __get_dict_value("size", file)
        url = __get_dict_value("url", file)
        name = path.split("/")[-1]
        github_files.append(File(name, path, size, url))

    return github_files


def __get(session: requests.Session, url):
    response = session.get(url)
    status_code = response.status_code
    if status_code != 200:
        response.raise_for_status()
    return response


def __get_dict_value(key_regex, my_dict):
    for key, value in my_dict.items():  # iter on both keys and values
        if key.startswith(key_regex):
            return value


def get_readme(repo_name, session):
    response = __get(session, API_URL + repo_name + "/readme")
    parsed_response = json.loads(response.content)
    readme = __get_dict_value("content", parsed_response)
    if readme:
        return base64.b64decode(readme).decode("utf-8")


class File:
    def __init__(self, name, path, size, url):
        self.url = url
        self.path = path
        self.name = name
        self.size = size

    def db_dict(self):
        return vars(self)
