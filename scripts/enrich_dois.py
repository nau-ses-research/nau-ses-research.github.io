#!/usr/bin/env python3
"""Add DOIs to data/publications.csv by matching titles against OpenAlex.

Run from the repo root:  python3 scripts/enrich_dois.py [--limit N] [--dry-run]

Conservative matching: a candidate is accepted only when the normalized
(alphanumeric, lowercased) titles are equal, or one contains the other and
they differ by less than 20 characters, AND the publication year matches
within one year. Rows that already have a doi are skipped, so this is safe
to re-run and is also called for new rows by the weekly pipeline.

Uses the anonymous OpenAlex pool with a descriptive User-Agent; be patient.
"""

import argparse
import csv
import difflib
import json
import re
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
PUB_CSV = REPO / "data" / "publications.csv"
UA = ("ses-nau.org publications pipeline "
      "(https://github.com/nau-ses-research/nau-ses-research.github.io)")


def norm(title: str) -> str:
    return re.sub(r"[^a-z0-9]", "", title.lower())


def _accept(want: str, got: str, year: str, got_year) -> bool:
    if not got:
        return False
    contained = (want in got or got in want) and abs(len(want) - len(got)) < 20
    if want != got and not contained:
        return False
    if year and got_year and abs(int(year) - int(got_year)) > 1:
        return False
    return True


def _accept_loose(want: str, got: str, year: str, got_year,
                  first_author_surname: str, got_surnames: set[str]) -> bool:
    """Second-pass matching: fuzzier titles, but the year must agree within
    one AND our first author's surname must appear among the candidate's
    authors. The author check is what makes the looseness safe."""
    if not got or not first_author_surname:
        return False
    if not (year and got_year and abs(int(year) - int(got_year)) <= 1):
        return False
    if first_author_surname not in got_surnames:
        return False
    if want in got or got in want:
        return True
    return difflib.SequenceMatcher(None, want, got).ratio() >= 0.93


def first_surname(authors: str) -> str:
    """Normalized surname of the first author from our 'LP Marshall, ...'
    or 'Marshall, LP' style strings."""
    first = (authors or "").split(",")[0].strip()
    if not first:
        return ""
    parts = first.split()
    # 'LP Marshall' -> Marshall; bare 'Marshall' (from 'Marshall, LP') -> itself
    cand = parts[-1] if len(parts) > 1 else parts[0]
    return re.sub(r"[^a-z]", "", cand.lower())


def lookup_doi(title: str, year: str, authors: str = "",
               loose: bool = False) -> str | None:
    """Crossref first (fast, tolerant of our volume), OpenAlex as fallback."""
    want = norm(title)
    surname = first_surname(authors) if loose else ""
    q = urllib.parse.quote(title[:250])
    # --- Crossref
    url = f"https://api.crossref.org/works?query.bibliographic={q}&rows=3"
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            items = json.load(r)["message"]["items"]
        for it in items:
            got = norm((it.get("title") or [""])[0])
            got_year = (it.get("issued", {}).get("date-parts", [[None]]) or [[None]])[0][0]
            if _accept(want, got, year, got_year):
                return it.get("DOI") or None
            if loose:
                got_surnames = {
                    re.sub(r"[^a-z]", "", (a.get("family") or "").lower())
                    for a in it.get("author", [])
                }
                if _accept_loose(want, got, year, got_year, surname, got_surnames):
                    return it.get("DOI") or None
    except Exception as e:  # noqa: BLE001 - fall through to OpenAlex
        print(f"  crossref error ({type(e).__name__})", flush=True)
        time.sleep(2)
    # --- OpenAlex fallback
    url = f"https://api.openalex.org/works?search={q}&per-page=3"
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            results = json.load(r).get("results", [])
    except Exception as e:  # noqa: BLE001 - network lookups fail; skip row
        print(f"  openalex error ({type(e).__name__}); skipping", flush=True)
        time.sleep(2)
        return None
    for w in results:
        got = norm(w.get("title") or w.get("display_name") or "")
        if _accept(want, got, year, w.get("publication_year")):
            doi = (w.get("doi") or "").replace("https://doi.org/", "")
            return doi or None
    return None


def resolve_work(title: str, year: str, authors_hint: str = "") -> dict | None:
    """Full bibliographic record for a title+year: Crossref first, OpenAlex
    fallback, same conservative matching as lookup_doi (plus the loose tier
    gated on first-author surname when an authors hint is available).

    Returns {authors, journal, number, doi} with authors as
    "Given Family, Given Family, ..." — or None when unmatched.
    """
    want = norm(title)
    surname = first_surname(authors_hint)
    q = urllib.parse.quote(title[:250])
    # --- Crossref
    url = f"https://api.crossref.org/works?query.bibliographic={q}&rows=3"
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            items = json.load(r)["message"]["items"]
        for it in items:
            # Supplements/datasets carry near-identical titles ("component"
            # type, e.g. 10.1130/geol.s.*); only real publications qualify.
            if it.get("type") not in ("journal-article", "proceedings-article",
                                      "book-chapter", "book", "monograph"):
                continue
            got = norm((it.get("title") or [""])[0])
            got_year = (it.get("issued", {}).get("date-parts", [[None]]) or [[None]])[0][0]
            got_surnames = {
                re.sub(r"[^a-z]", "", (a.get("family") or "").lower())
                for a in it.get("author", [])
            }
            if _accept(want, got, year, got_year) or _accept_loose(
                    want, got, year, got_year, surname, got_surnames):
                authors = ", ".join(
                    f"{a.get('given', '')} {a.get('family', '')}".strip()
                    for a in it.get("author", []))
                number = it.get("volume", "") or ""
                if it.get("issue"):
                    number += f" ({it['issue']})"
                if it.get("page"):
                    number += f", {it['page']}" if number else it["page"]
                return {
                    "authors": authors,
                    "journal": (it.get("container-title") or [""])[0],
                    "number": number,
                    "doi": it.get("DOI") or "",
                }
    except Exception as e:  # noqa: BLE001 - fall through to OpenAlex
        print(f"  crossref error ({type(e).__name__})", flush=True)
        time.sleep(2)
    # --- OpenAlex fallback
    url = f"https://api.openalex.org/works?search={q}&per-page=3"
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            results = json.load(r).get("results", [])
        for w in results:
            if w.get("type") not in ("article", "review", "book-chapter", "book"):
                continue
            got = norm(w.get("title") or w.get("display_name") or "")
            got_surnames = {
                re.sub(r"[^a-z]", "", (a.get("author", {}).get("display_name", "")
                                        .split()[-1] if a.get("author", {}).get("display_name") else "").lower())
                for a in w.get("authorships", [])
            }
            if _accept(want, got, year, w.get("publication_year")) or _accept_loose(
                    want, got, year, w.get("publication_year"), surname, got_surnames):
                authors = ", ".join(
                    a.get("author", {}).get("display_name", "")
                    for a in w.get("authorships", []) if a.get("author"))
                bib = w.get("biblio") or {}
                number = bib.get("volume") or ""
                if bib.get("issue"):
                    number += f" ({bib['issue']})"
                pages = "-".join(filter(None, [bib.get("first_page"), bib.get("last_page")]))
                if pages:
                    number += f", {pages}" if number else pages
                src = ((w.get("primary_location") or {}).get("source") or {})
                return {
                    "authors": authors,
                    "journal": src.get("display_name") or "",
                    "number": number,
                    "doi": (w.get("doi") or "").replace("https://doi.org/", ""),
                }
    except Exception as e:  # noqa: BLE001
        print(f"  openalex error ({type(e).__name__})", flush=True)
    return None


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, help="only process the first N missing-DOI rows")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--loose", action="store_true",
                    help="second-pass matching: fuzzier titles, but requires "
                         "year agreement AND first-author surname match")
    args = ap.parse_args()

    with open(PUB_CSV, newline="") as f:
        reader = csv.DictReader(f)
        cols = list(reader.fieldnames or [])
        rows = list(reader)
    if "doi" not in cols:
        cols.insert(cols.index("pubid"), "doi")
        for r in rows:
            r["doi"] = ""

    todo = [r for r in rows if not r.get("doi") and r["title"]]
    if args.limit:
        todo = todo[: args.limit]
    print(f"{len(rows)} rows; {len(todo)} to look up", flush=True)

    def write_out():
        if args.dry_run:
            return
        with open(PUB_CSV, "w", newline="") as f:
            w = csv.DictWriter(f, fieldnames=cols, quoting=csv.QUOTE_MINIMAL)
            w.writeheader()
            w.writerows(rows)

    found = 0
    for i, r in enumerate(todo, 1):
        doi = lookup_doi(r["title"], r["year"], r.get("authors", ""), loose=args.loose)
        if doi:
            r["doi"] = doi
            found += 1
        if i % 25 == 0:
            print(f"  {i}/{len(todo)} processed, {found} DOIs found", flush=True)
        if i % 100 == 0:
            write_out()  # checkpoint so an interrupted run keeps its progress
        time.sleep(0.2)

    print(f"Done: {found}/{len(todo)} matched "
          f"({sum(1 for r in rows if r.get('doi'))} total rows now have DOIs)", flush=True)
    if args.dry_run:
        print("Dry run: not writing.")
        return 0
    write_out()
    print(f"Wrote {PUB_CSV}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
