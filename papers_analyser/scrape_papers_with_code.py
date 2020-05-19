from selenium.webdriver import Chrome
from bs4 import BeautifulSoup
import time

SCROLL_PAUSE_TIME = 3
SCROLL_DOWN_FULL = False


def get_paper_index_page(driver: Chrome, url="https://paperswithcode.com/latest"):
    driver.get(url)

    last_height = 0
    while last_height != __get_scroll_height(driver) & SCROLL_DOWN_FULL:
        __scroll(driver)
        time.sleep(SCROLL_PAUSE_TIME)

    return __get_raw_html(driver)


def get_papers(page):
    soup = BeautifulSoup(page, "html.parser")
    elements = soup.select("div.row.infinite-item.item")
    print(len(elements))
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
