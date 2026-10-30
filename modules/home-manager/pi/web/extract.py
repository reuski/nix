#!/usr/bin/env python3
"""Extract readable Markdown from fetched HTML.

Called by core.ts as: python3 extract.py <final-url> < html. With an HTTP
charset, core.ts delivers UTF-8; otherwise trafilatura detects the original
encoding. Its decoder preserves valid UTF-8 before considering other encodings.
The parser is pinned to UTF-8 so stale HTML/XML metadata cannot re-decode text.
Relative links are resolved against the final URL (and <base href>) because
trafilatura resolves them against the origin. Reads stdin, writes stdout; no network or filesystem access. Exit 0
with text, 2 when no text was found, 1 on error.
"""

import sys
from urllib.parse import urljoin

import trafilatura
from lxml import etree
from lxml import html as lxml_html
from trafilatura.utils import decode_file

MAX_INPUT_BYTES = 4 * 1024 * 1024


def fail(message: str, code: int) -> None:
    sys.stderr.write(message + "\n")
    raise SystemExit(code)


def absolutize_links(document, final_url: str) -> None:
    base_url = final_url
    base_hrefs = document.xpath("//base[@href]/@href")
    if base_hrefs:
        base_url = urljoin(final_url, base_hrefs[0].strip())
    for anchor in document.xpath("//a[@href]"):
        href = anchor.get("href").strip()
        if href:
            anchor.set("href", urljoin(base_url, href))


def main() -> int:
    if len(sys.argv) != 2:
        fail("usage: extract.py <final-url> < html", 1)
    final_url = sys.argv[1]

    raw = sys.stdin.buffer.read(MAX_INPUT_BYTES + 1)
    if len(raw) > MAX_INPUT_BYTES:
        fail(f"html input exceeded {MAX_INPUT_BYTES} bytes", 1)

    parser = lxml_html.HTMLParser(encoding="utf-8")
    try:
        html = decode_file(raw, max_size=MAX_INPUT_BYTES)
        document = lxml_html.fromstring(html.encode("utf-8"), parser=parser)
    except (etree.ParserError, ValueError) as error:
        fail(f"could not parse html: {error}", 1)

    absolutize_links(document, final_url)
    resolved_html = lxml_html.tostring(document, encoding="unicode")

    try:
        extracted = trafilatura.extract(
            resolved_html,
            output_format="markdown",
            include_links=True,
            include_tables=True,
            include_formatting=True,
            include_comments=False,
            deduplicate=False,
        )
    except Exception as error:  # extraction failures must not crash the tool
        fail(f"extraction failed: {error}", 1)

    text = (extracted or "").strip()
    if not text:
        fail("extraction produced no text", 2)

    sys.stdout.buffer.write(text.encode("utf-8"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
