#!/usr/bin/env python3
"""Weekly SES publications update from Google Scholar.

Replaces the retired R pipeline (archive/update_publications_2025.R).
Run from the repo root, ideally via uv:

    uv run scripts/update_publications.py [--dry-run] [--summary-file PATH]

What it does (see data/README.md for the curation contract):
1. Fetches every faculty Scholar profile listed in data/faculty.csv.
2. Updates `citations` on existing rows of data/publications.csv.
3. Appends genuinely new publications from the last two calendar years,
   with SES faculty and grad-student co-authors auto-tagged.
4. Aborts without writing if guard rails fail (Scholar block detected,
   suspicious row/citation swings, or validator errors).

Exit codes: 0 = success (changes or no changes), 1 = guard/validation failure.
"""

from __future__ import annotations

import argparse
import csv
import datetime
import json
import random
import re
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from matchers import (  # noqa: E402
    Faculty, Student, is_excluded_journal, match_faculty,
    match_grad_students, simple_title,
)

REPO = Path(__file__).resolve().parent.parent
DATA = REPO / "data"
PUB_CSV = DATA / "publications.csv"
CACHE = REPO / ".cache" / "scholar"

MAX_NEW_ROWS = 150
MIN_FETCH_SUCCESS = 0.8
MAX_CITATION_DROP = 0.02


def log(msg: str) -> None:
    print(msg, flush=True)


def read_csv(path: Path) -> list[dict]:
    with open(path, newline="") as f:
        return list(csv.DictReader(f))


def fetch_faculty_pubs(faculty_rows: list[dict], current_year: int) -> tuple[list[dict], int, list[str]]:
    """Fetch publication stubs for every faculty member with a Scholar ID.

    Returns (pubs, n_attempted, failed_names). Each pub dict has:
    simple_title, title, year, cites, scholar_id, faculty_label, _raw
    (the scholarly publication object, fillable later for new pubs).
    """
    from scholarly import scholarly

    CACHE.mkdir(parents=True, exist_ok=True)
    pubs: list[dict] = []
    failed: list[str] = []
    targets = [r for r in faculty_rows if r["scholar_id"]]
    for row in targets:
        label = f"{row['first_initial']} {row['last_name']}"
        start = int(row["start_year"]) if row["start_year"] else 0
        end = int(row["end_year"]) if row["end_year"] else current_year
        got = None
        for attempt in range(3):
            try:
                author = scholarly.search_author_id(row["scholar_id"])
                got = scholarly.fill(author, sections=["publications"])
                break
            except Exception as e:  # noqa: BLE001 - Scholar scraping is messy
                log(f"  {label}: attempt {attempt + 1} failed ({type(e).__name__}: {e})")
                time.sleep(10 * (attempt + 1))
        if got is None:
            failed.append(label)
            continue
        kept = 0
        for p in got.get("publications", []):
            bib = p.get("bib", {})
            title = (bib.get("title") or "").strip()
            year_s = str(bib.get("pub_year") or "")
            year = int(year_s) if year_s.isdigit() else None
            if not title or year is None or not (start <= year <= end):
                continue
            pubs.append({
                "simple_title": simple_title(title),
                "title": title,
                "year": year,
                "cites": int(p.get("num_citations") or 0),
                "scholar_id": row["scholar_id"],
                "faculty_label": label,
                "_raw": p,
            })
            kept += 1
        log(f"  {label}: {kept} pubs")
        with open(CACHE / f"{row['scholar_id']}.json", "w") as f:
            json.dump([{k: v for k, v in p.items() if k != "_raw"}
                       for p in pubs if p["scholar_id"] == row["scholar_id"]], f)
        time.sleep(random.uniform(2, 5))
    return pubs, len(targets), failed


def fill_publication(raw: dict) -> dict:
    """Fetch full details (complete author list, journal, volume/pages)."""
    from scholarly import scholarly

    filled = scholarly.fill(raw)
    bib = filled.get("bib", {})
    authors = ", ".join(a.strip() for a in (bib.get("author") or "").split(" and ") if a.strip())
    journal = (bib.get("journal") or bib.get("citation") or "").strip()
    number = ""
    if bib.get("volume"):
        number = str(bib["volume"])
        if bib.get("number"):
            number += f" ({bib['number']})"
        if bib.get("pages"):
            number += f", {bib['pages']}"
    elif bib.get("pages"):
        number = str(bib["pages"])
    return {
        "authors": authors,
        "journal": journal,
        "number": number,
        "pubid": filled.get("author_pub_id", ""),
    }


def build_new_row(cand: dict, details: dict, faculty: list[Faculty],
                  students: list[Student], existing_ids: set[str]) -> dict:
    fac = match_faculty(details["authors"], faculty)
    # Union with the profiles the pub was fetched from (mirrors the R
    # pipeline, which trusted the source profile even without a text match).
    for label in cand["faculty_labels"]:
        if label not in fac:
            fac.append(label)
    grads = match_grad_students(details["authors"], cand["year"], students)
    base = f"{cand['simple_title'][:40]}-{cand['year']}"
    pub_id, n = base, 1
    while pub_id in existing_ids:
        n += 1
        pub_id = f"{base}-{n}"
    existing_ids.add(pub_id)
    return {
        "id": pub_id,
        "title": cand["title"],
        "authors": details["authors"],
        "journal": details["journal"],
        "number": details["number"],
        "year": str(cand["year"]),
        "citations": str(cand["cites"]),
        "ses_faculty": "; ".join(fac),
        "ses_grad_students": "; ".join(grads),
        "ses_undergrad_students": "",
        "verified": "false",
        "include_in_reports": "true",
        "additional_notes": "",
        "pubid": details["pubid"],
        "scholar_id_source": cand["scholar_ids"][0],
        "date_added": datetime.date.today().isoformat(),
        "simple_title": cand["simple_title"],
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true",
                    help="report changes but do not modify data/publications.csv")
    ap.add_argument("--summary-file", type=Path,
                    help="write the markdown change summary here (for PR bodies)")
    args = ap.parse_args()

    current_year = datetime.date.today().year
    faculty_rows = read_csv(DATA / "faculty.csv")
    student_rows = read_csv(DATA / "students.csv")
    db = read_csv(PUB_CSV)
    original_text = PUB_CSV.read_text()
    log(f"Loaded {len(db)} publications, {len(faculty_rows)} faculty, "
        f"{len(student_rows)} students")

    faculty = [Faculty(r["first_initial"], r["last_name"]) for r in faculty_rows]
    students = [
        Student(r["first"], r["last"],
                int(r["start_year"]) if r["start_year"] else None)
        for r in student_rows
    ]

    log("Fetching Google Scholar profiles...")
    scholar_pubs, attempted, failed = fetch_faculty_pubs(faculty_rows, current_year)
    success_rate = (attempted - len(failed)) / attempted if attempted else 0
    log(f"Fetched {len(scholar_pubs)} publication records from "
        f"{attempted - len(failed)}/{attempted} profiles")

    # ---- Guard: Scholar block detector -------------------------------------
    if not scholar_pubs or success_rate < MIN_FETCH_SUCCESS:
        log(f"ABORT: fetch success rate {success_rate:.0%} below "
            f"{MIN_FETCH_SUCCESS:.0%} or zero publications returned "
            f"(failed: {', '.join(failed) or 'none'}). "
            "Google Scholar may be blocking; nothing was written.")
        return 1

    # ---- Citation pass -----------------------------------------------------
    max_cites: dict[str, int] = {}
    for p in scholar_pubs:
        st = p["simple_title"]
        max_cites[st] = max(max_cites.get(st, 0), p["cites"])
    citation_updates = []
    for row in db:
        new = max_cites.get(row["simple_title"])
        if new is not None and str(new) != row["citations"]:
            citation_updates.append((row["title"][:60], row["citations"], new))
            row["citations"] = str(new)
    log(f"Citation updates: {len(citation_updates)}")

    # ---- New-publication pass ----------------------------------------------
    existing_titles = {r["simple_title"] for r in db}
    candidates: dict[str, dict] = {}
    for p in scholar_pubs:
        if p["year"] < current_year - 1 or p["simple_title"] in existing_titles:
            continue
        c = candidates.setdefault(p["simple_title"], {
            "simple_title": p["simple_title"], "title": p["title"],
            "year": p["year"], "cites": p["cites"], "faculty_labels": [],
            "scholar_ids": [], "_raw": p["_raw"],
        })
        c["cites"] = max(c["cites"], p["cites"])
        if p["faculty_label"] not in c["faculty_labels"]:
            c["faculty_labels"].append(p["faculty_label"])
        if p["scholar_id"] not in c["scholar_ids"]:
            c["scholar_ids"].append(p["scholar_id"])

    new_rows = []
    skipped_fills = []
    existing_ids = {r["id"] for r in db}
    for cand in candidates.values():
        try:
            details = fill_publication(cand["_raw"])
        except Exception as e:  # noqa: BLE001 - Scholar throttling mid-run
            skipped_fills.append(cand["title"])
            log(f"  skip (detail fetch failed, will retry next run): "
                f"{cand['title'][:70]} ({type(e).__name__})")
            time.sleep(random.uniform(20, 30))
            continue
        time.sleep(random.uniform(2, 5))
        journal = details["journal"]
        if is_excluded_journal(journal):
            log(f"  skip (journal filter): {cand['title'][:70]} [{journal[:40]}]")
            continue
        row = build_new_row(cand, details, faculty, students, existing_ids)
        new_rows.append(row)
        log(f"  new: {cand['title'][:70]} ({cand['year']}) "
            f"[{row['ses_faculty']}]"
            + (f" +grad: {row['ses_grad_students']}" if row["ses_grad_students"] else ""))

    # ---- Guards on the candidate result ------------------------------------
    if len(new_rows) >= MAX_NEW_ROWS:
        log(f"ABORT: {len(new_rows)} new rows >= {MAX_NEW_ROWS}; "
            "that is not a normal week. Nothing was written.")
        return 1
    old_total_cites = sum(int(r["citations"]) for r in read_csv(PUB_CSV))
    new_total_cites = sum(int(r["citations"]) for r in db) + sum(
        int(r["citations"]) for r in new_rows)
    if new_total_cites < old_total_cites * (1 - MAX_CITATION_DROP):
        log(f"ABORT: total citations would drop {old_total_cites} -> "
            f"{new_total_cites}; Scholar data looks wrong. Nothing was written.")
        return 1

    # ---- Summary -----------------------------------------------------------
    summary = [
        f"Weekly publications update ({datetime.date.today().isoformat()})",
        "",
        f"- Profiles fetched: {attempted - len(failed)}/{attempted}"
        + (f" (failed: {', '.join(failed)})" if failed else ""),
        f"- Citation updates: {len(citation_updates)}",
        f"- New publications: {len(new_rows)}",
    ]
    if skipped_fills:
        summary.append(
            f"- Deferred (detail fetch throttled, retry next run): {len(skipped_fills)}")
        for t in skipped_fills:
            summary.append(f"  - {t}")
    for r in new_rows:
        summary.append(f"  - {r['title']} ({r['year']}) — {r['ses_faculty']}"
                       + (f"; grad: {r['ses_grad_students']}" if r["ses_grad_students"] else ""))
    summary_text = "\n".join(summary)
    log("\n" + summary_text)
    if args.summary_file:
        args.summary_file.write_text(summary_text + "\n")

    if not citation_updates and not new_rows:
        log("\nNo changes this week.")
        return 0
    if args.dry_run:
        log("\nDry run: data/publications.csv not modified.")
        return 0

    # ---- Write + validate --------------------------------------------------
    final = db + new_rows
    final.sort(key=lambda r: (-(int(r["year"]) if r["year"] else 0), r["simple_title"]))
    with open(PUB_CSV, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(final[0].keys()), quoting=csv.QUOTE_MINIMAL)
        w.writeheader()
        w.writerows(final)
    check = subprocess.run([sys.executable, str(REPO / "scripts" / "validate_data.py")])
    if check.returncode != 0:
        PUB_CSV.write_text(original_text)
        log("ABORT: validator rejected the update; data/publications.csv restored.")
        return 1
    log(f"\nWrote data/publications.csv: {len(final)} rows "
        f"({len(new_rows)} new, {len(citation_updates)} citation updates).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
