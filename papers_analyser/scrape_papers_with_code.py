from datetime import datetime

from selenium.webdriver import Chrome
from bs4 import BeautifulSoup
import time

SCROLL_PAUSE_TIME = 3
SCROLL_DOWN_FULL = False
URL = "https://paperswithcode.com/latest"


def get_paper_index_page(driver: Chrome, date):
    driver.get(URL)

    last_height = -1
    date_reached = no_more_to_load = False
    while not date_reached and not no_more_to_load:
        __scroll(driver)
        time.sleep(SCROLL_PAUSE_TIME)
        date_reached = date > get_date(__get_raw_html(driver))

        curr_height = __get_scroll_height(driver)
        if curr_height == last_height:
            no_more_to_load = True
        else:
            last_height = curr_height

    return __get_raw_html(driver)


def get_papers(page):
    soup = BeautifulSoup(page, "html.parser")
    elements = soup.select("div.row.infinite-item.item")
    links = list()
    for ele in elements:
        box = ele.select("a.badge.badge-light")[0]
        links.append(box["href"])
    return links


def __get_scroll_height(driver):
    return driver.execute_script("return document.body.scrollHeight")


def __scroll(driver: Chrome):
    driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")


def __get_raw_html(driver):
    return driver.find_element_by_xpath('//*').get_attribute("outerHTML")


def get_date(page):
    soup = BeautifulSoup(page, "html.parser")
    date_headers = soup.select("span.author-name-text")
    for date_header in reversed(date_headers):
        try:
            date = datetime.strptime(date_header.text, '%d %b %Y')
            print(date)
            return date
        except ValueError:
            print("could not parse" + date_header.text)
            pass
