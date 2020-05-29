import sqlite3
from sqlite3 import Error, IntegrityError
from sqlite3.dbapi2 import Connection
from .paper import BASE_URL
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


def create_table_if_not_exist(conn: Connection):
    sql_paper = """ CREATE TABLE IF NOT EXISTS papers (
                                        title text,
                                        url text PRIMARY KEY,
                                        date text,
                                        authors text,
                                        tasks text,
                                        url_pdf text,
                                        url_abs text,
                                        arxiv_id text,
                                        Timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
                                    );  """
    sql_repo = """CREATE TABLE IF NOT EXISTS repos (
                                        name text,
                                        paper_url text NOT NULL,
                                        url text NOT NULL,
                                        readme text,
                                        private BOOLEAN NOT NULL CHECK (private IN (0,1)),
                                        framework text,
                                        mentioned_in_paper BOOLEAN NOT NULL CHECK (private IN (0,1)),
                                        mentioned_in_github BOOLEAN NOT NULL CHECK (private IN (0,1)),
                                        PRIMARY KEY(name, paper_url)
                                        FOREIGN KEY (paper_url) REFERENCES papers(url));"""

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

def get_papers(conn):
    c = conn.cursor()
    query ="""SELECT  url FROM papers"""
    # query1 = """SELECT url FROM papers WHERE url IN (%s)""" % (",".join(["?"] * len(paper_urls)))
    c.execute(query)
    result = c.fetchall()
    paper_urls_in_db = []

    for row in result:
        paper_urls_in_db.append(row[0][len(BASE_URL):])
    c.close()
    return paper_urls_in_db




def dict_to_sql(my_dict, table):
    columns = ', '.join(my_dict.keys())
    placeholders = ':' + ', :'.join(my_dict.keys())
    return """INSERT OR REPLACE INTO %s (%s) VALUES (%s)""" % (table, columns, placeholders)
