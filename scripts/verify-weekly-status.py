#!/usr/bin/env python3
from html.parser import HTMLParser
from pathlib import Path
import re
import sys


MIN_PDF_BYTES = 20_000


class LinkParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.in_action = False
        self.action_depth = 0
        self.pdf_links = []

    def handle_starttag(self, tag, attrs):
        attrs_dict = dict(attrs)
        classes = attrs_dict.get("class", "").split()
        if tag == "div" and "report-actions" in classes:
            self.in_action = True
            self.action_depth = 1
            return
        if self.in_action:
            self.action_depth += 1
            if tag == "a" and "pdf-button" in classes:
                href = attrs_dict.get("href", "")
                if href.endswith(".pdf"):
                    self.pdf_links.append(href)

    def handle_endtag(self, tag):
        if self.in_action:
            self.action_depth -= 1
            if self.action_depth <= 0:
                self.in_action = False


def fail(message):
    print(f"VERIFY FAIL: {message}", file=sys.stderr)
    sys.exit(1)


def main():
    root = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path(__file__).resolve().parents[1]
    index = root / "index.html"

    if not index.exists():
        fail("index.html is missing")

    html = index.read_text(encoding="utf-8")
    parser = LinkParser()
    parser.feed(html)

    if "report-actions" not in html:
        fail("index.html is missing .report-actions")
    if "pdf-button" not in html:
        fail("index.html is missing .pdf-button")
    if not parser.pdf_links:
        fail("index.html has no PDF link inside .report-actions")
    if ".report-actions{display:none}" not in re.sub(r"\s+", "", html):
        fail("print CSS must hide .report-actions")

    for href in parser.pdf_links:
        pdf_path = (root / href).resolve()
        if root not in pdf_path.parents and pdf_path != root:
            fail(f"PDF link leaves repo: {href}")
        if not pdf_path.exists():
            fail(f"linked PDF does not exist: {href}")
        if pdf_path.stat().st_size < MIN_PDF_BYTES:
            fail(f"linked PDF is too small to trust: {href}")

    print(f"VERIFY PASS: {index.name} has PDF action and {len(parser.pdf_links)} linked PDF file(s)")


if __name__ == "__main__":
    main()
