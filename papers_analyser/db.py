import sqlite3
from sqlite3 import Error, IntegrityError
from sqlite3.dbapi2 import Connection
import sqlalchemy


def create_connection(db_file):
    """ create a database connection to a SQLite database: Source:SQL lite """
    conn = None
    try:
        conn = sqlite3.connect(db_file)
        print(sqlite3.version)
    except Error as e:
        print(e)

    return conn


def create_table(conn: Connection):
    sql_paper = """ CREATE TABLE IF NOT EXISTS papers (
                                        title text PRIMARY KEY,
                                        url text NOT NULL,
                                        date text,
                                        authors text
                                    );  """
    sql_repo = """CREATE TABLE IF NOT EXISTS repos (
                                        name text PRIMARY KEY,
                                        paper_title text NOT NULL,
                                        url text NOT NULL,
                                        readme text,
                                        FOREIGN KEY (paper_title) REFERENCES papers(title));"""

    sql_files = """CREATE TABLE IF NOT EXISTS files (
                                        path text,
                                        url text,
                                        repo_name text,
                                        name text,
                                        size integer,
                                        FOREIGN KEY (repo_name) REFERENCES repos(name),
                                        PRIMARY KEY (path, repo_name));"""

    if conn:
        c = conn.cursor()
        c.execute(sql_paper)
        c.execute(sql_repo)
        c.execute(sql_files)

        conn.commit()
    else:
        raise AttributeError


def insert_paper(conn, paper):
    c = conn.cursor()
    paper_dict = paper.db_dict()
    repo_dicts = paper.db_repo_dicts()

    insert_paper_sql = dict_to_sql(paper_dict, "papers")
    __insert(c,insert_paper_sql, paper_dict)

    for repo_dict in repo_dicts:
        insert_repo_sql = dict_to_sql(repo_dict, "repos")
        __insert(c, insert_repo_sql, repo_dict)

    for repo in paper.repos:
        for file_dict in repo.db_file_dicts():
            insert_file_sql = dict_to_sql(file_dict, "files")
            __insert(c,insert_file_sql, file_dict)


def __insert(c, sql, my_dict):
    try:
        c.execute(sql, my_dict)
    except IntegrityError:
        pass




def dict_to_sql(my_dict, table):
    columns = ', '.join(my_dict.keys())
    placeholders = ':' + ', :'.join(my_dict.keys())
    return "INSERT INTO " + table + "(%s) VALUES (%s)" % (columns, placeholders)
