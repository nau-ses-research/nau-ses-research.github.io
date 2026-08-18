#!/usr/bin/env python3
"""Validate the data/ CSVs that drive the SES publications site.

Run from the repo root:  python3 scripts/validate_data.py
Exits non-zero on any error; warnings are printed but do not fail the run.

This is the shared gate: CI runs it on every PR touching data/, and the
weekly pipeline (scripts/update_publications.py) runs it before writing.
"""

import csv
import datetime
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
DATA = REPO / "data"

PUB_COLS = [
    "id", "title", "authors", "journal", "number", "year", "citations",
    "ses_faculty", "ses_grad_students", "ses_undergrad_students", "verified",
    "include_in_reports", "additional_notes", "doi", "pubid",
    "scholar_id_source", "date_added", "simple_title",
]
FACULTY_COLS = [
    "slug", "first_initial", "first_name", "last_name", "scholar_id",
    "start_year", "end_year", "active", "profile", "themes",
]
THEME_SLUGS = {
    "climate-change", "ecology-conservation", "environment-society",
    "sedimentary-geology", "tectonics-interior", "water-management",
}
STUDENT_COLS = [
    "first", "last", "full_name", "degree", "program", "advisor",
    "start_year", "status", "notes",
]

errors: list[str] = []
warnings: list[str] = []


def err(msg: str) -> None:
    errors.append(msg)


def warn(msg: str) -> None:
    warnings.append(msg)


def read(name: str, cols: list[str]) -> list[dict]:
    path = DATA / name
    if not path.exists():
        err(f"{name}: file missing")
        return []
    with open(path, newline="") as f:
        reader = csv.DictReader(f)
        if reader.fieldnames != cols:
            err(f"{name}: columns {reader.fieldnames} != expected {cols}")
            return []
        return list(reader)


def check_bool(rows: list[dict], name: str, col: str) -> None:
    for i, r in enumerate(rows, start=2):
        if r[col] not in ("true", "false"):
            err(f"{name} line {i}: {col}={r[col]!r} is not true/false")


current_year = datetime.date.today().year

# ---------------------------------------------------------------- faculty.csv
faculty = read("faculty.csv", FACULTY_COLS)
faculty_names = set()
for i, r in enumerate(faculty, start=2):
    if not r["last_name"]:
        err(f"faculty.csv line {i}: empty last_name")
    if not r["first_initial"]:
        err(f"faculty.csv line {i}: empty first_initial")
    faculty_names.add(f"{r['first_initial']} {r['last_name']}")
    if r["scholar_id"] and not re.fullmatch(r"[A-Za-z0-9_-]{12}", r["scholar_id"]):
        err(f"faculty.csv line {i}: malformed scholar_id {r['scholar_id']!r}")
    if r["profile"] not in ("current", "archived", "none"):
        err(f"faculty.csv line {i}: profile={r['profile']!r}")
    for t in filter(None, r["themes"].split("; ")):
        if t not in THEME_SLUGS:
            err(f"faculty.csv line {i}: unknown theme {t!r}")
check_bool(faculty, "faculty.csv", "active")

# --------------------------------------------------------------- students.csv
students = read("students.csv", STUDENT_COLS)
for i, r in enumerate(students, start=2):
    if not r["first"] or not r["last"]:
        err(f"students.csv line {i}: empty first/last")
    if r["status"] not in ("current", "alumni"):
        err(f"students.csv line {i}: status={r['status']!r}")

# ----------------------------------------------------------- publications.csv
pubs = read("publications.csv", PUB_COLS)
seen_ids: set[str] = set()
seen_titles: set[str] = set()
for i, r in enumerate(pubs, start=2):
    if not r["title"]:
        err(f"publications.csv line {i}: empty title")
    st = r["simple_title"]
    if not st:
        err(f"publications.csv line {i}: empty simple_title")
    elif st != re.sub(r"[^A-Za-z0-9]", "", r["title"]).lower():
        err(f"publications.csv line {i}: simple_title does not match title")
    if st in seen_titles:
        err(f"publications.csv line {i}: duplicate simple_title {st[:50]!r}")
    seen_titles.add(st)
    if not r["id"]:
        err(f"publications.csv line {i}: empty id")
    if r["id"] in seen_ids:
        err(f"publications.csv line {i}: duplicate id {r['id']!r}")
    seen_ids.add(r["id"])
    if r["year"]:
        if not r["year"].isdigit() or not (1900 <= int(r["year"]) <= current_year + 1):
            err(f"publications.csv line {i}: year={r['year']!r} out of range")
    elif r["verified"] != "true":
        warn(f"publications.csv line {i}: unverified row with no year")
    if not r["citations"].isdigit():
        err(f"publications.csv line {i}: citations={r['citations']!r} not a non-negative integer")
    for col in ("ses_faculty", "ses_grad_students", "ses_undergrad_students"):
        v = r[col]
        if v and (", " in v.replace("; ", "|") or v.startswith(";") or v.endswith(";")):
            err(f"publications.csv line {i}: {col} must use '; ' separators, got {v!r}")
    for name in filter(None, r["ses_faculty"].split("; ")):
        if name not in faculty_names:
            warn(f"publications.csv line {i}: ses_faculty {name!r} not in faculty.csv")
check_bool(pubs, "publications.csv", "verified")
check_bool(pubs, "publications.csv", "include_in_reports")

# Sort order: year desc, simple_title asc (keeps weekly diffs line-scoped)
def sort_key(r: dict):
    return (-(int(r["year"]) if r["year"] else 0), r["simple_title"])

if pubs != sorted(pubs, key=sort_key):
    err("publications.csv: rows are not sorted by year desc, simple_title asc")

# ------------------------------------------------------------------- report
for w in warnings:
    print(f"WARNING: {w}")
if errors:
    for e in errors:
        print(f"ERROR: {e}")
    print(f"\nFAILED: {len(errors)} error(s), {len(warnings)} warning(s)")
    sys.exit(1)
print(f"OK: publications={len(pubs)} faculty={len(faculty)} students={len(students)}, "
      f"{len(warnings)} warning(s)")
