#!/usr/bin/env python3
"""One-time conversion of the raw Google Sheets export into the repo data/ layer.

Input:  ~/GitHub/SES_dashboard_backups/raw_sheets/*.csv  (from export_sheets_to_csv.R)
Output: data/publications.csv, data/students.csv, data/faculty.csv

Run from the repo root:  python3 archive/convert_raw_export.py

Transformations (2026-08 cutover):
- Drop fully blank rows (no title).
- Legacy column drift: 1,038 pre-2025 rows hold the Scholar pubid in
  Needs_Manual_Review and a faculty last name in Scholar_ID_Source; newer rows
  are correct. pubid = PubID or Needs_Manual_Review; last-name
  Scholar_ID_Source values are normalized to the matching Scholar ID.
- Multi-value fields (ses_faculty, ses_grad_students, ses_undergrad_students)
  switch from ", " to "; " separators.
- simple_title recomputed for all rows (lowercase alphanumeric of title).
- id = first 40 chars of simple_title + "-" + year, uniqued with numeric suffix.
- Booleans lowercased; blank Verified -> false; blank Include_In_Reports -> true
  (matches the old R filter, which only excluded explicit FALSE).
- Faculty who appear in the student roster (Nicholas McKay as "NICHOLAS MCKAY",
  Lisa Thompson) are excluded case-insensitively (the old R exclusion was
  case-sensitive and missed the all-caps alumni row), and their names are
  scrubbed from ses_grad_students on all publication rows.
"""

import csv
import re
from pathlib import Path

RAW = Path.home() / "GitHub/SES_dashboard_backups/raw_sheets"
REPO = Path(__file__).resolve().parent.parent
DATA = REPO / "data"
DATA.mkdir(exist_ok=True)


def simple_title(title: str) -> str:
    return re.sub(r"[^A-Za-z0-9]", "", title).lower()


EXCLUDED_STUDENTS = {"nicholas mckay", "lisa thompson"}


def resep(value: str, drop_excluded: bool = False) -> str:
    """Convert ', '-separated multi-value field to '; ' separators."""
    parts = [p.strip() for p in value.split(",") if p.strip()]
    if drop_excluded:
        parts = [p for p in parts if p.lower() not in EXCLUDED_STUDENTS]
    return "; ".join(parts)


# ---------------------------------------------------------------- faculty.csv
PROFILE_CURRENT = {
    "abraham-springer", "bridget-smith-konter", "casey-tierney",
    "christine-regalla", "clare-aslan", "darrell-kaufman", "deborah-huntzinger",
    "denielle-perry", "diana-stuart", "donna-shillington", "duan-biggs",
    "erik-nielsen", "erika-nowak", "helen-rowe", "james-gaherty",
    "john-fegyveresi", "laura-wasylenki", "michael-smith", "nancy-johnson",
    "nicholas-mckay", "pranay-ranjan", "rebecca-best", "ryan-porter",
    "sara-souther", "scott-anderson", "suzanne-affinati", "taylor-joyal",
}
PROFILE_ARCHIVED = {
    "brett-dickson", "cody-routson", "francisco-apen", "james-sample",
    "julie-mueller", "lucero-radonic", "mary-reid", "michael-erb",
    "paul-umhoefer", "robert-sanford", "rod-parnell", "roger-haro",
    "rosemary-logan", "temuulen-sankey", "thomas-hoisch", "thomas-sisk",
}
# CSV last name -> profile slug where the mechanical match fails
SLUG_OVERRIDES = {"Affinatti": "suzanne-affinati", "Anderson": "scott-anderson"}

faculty_rows = []
with open(REPO / "facultygooglescholarids.csv") as f:
    for r in csv.DictReader(f):
        last = r["Last Name"].strip()
        slug = SLUG_OVERRIDES.get(last)
        if slug is None:
            last_slug = re.sub(r"[^a-z]+", "-", last.lower()).strip("-")
            for s in PROFILE_CURRENT | PROFILE_ARCHIVED:
                if s.endswith("-" + last_slug) or s == last_slug:
                    slug = s
                    break
        profile = (
            "current" if slug in PROFILE_CURRENT
            else "archived" if slug in PROFILE_ARCHIVED
            else "none"
        )
        first_name = ""
        if slug:
            last_slug = SLUG_OVERRIDES.get(last, "")
            stem = re.sub(r"[^a-z]+", "-", last.lower()).strip("-")
            first_name = re.sub(f"-?{re.escape(stem)}$", "", slug) if slug.endswith(stem) else slug.split("-")[0]
            first_name = first_name.split("-")[0].capitalize() if first_name else ""
        faculty_rows.append({
            "slug": slug or "",
            "first_initial": r["First Initial"].strip(),
            "first_name": first_name,
            "last_name": last,
            "scholar_id": r["ID"].strip(),
            "start_year": r["StartYear"].strip(),
            "end_year": r["EndYear"].strip(),
            "active": "false" if r["EndYear"].strip() else "true",
            "profile": profile,
        })

faculty_rows.sort(key=lambda r: (r["last_name"].lower(), r["first_initial"]))
with open(DATA / "faculty.csv", "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=list(faculty_rows[0].keys()))
    w.writeheader()
    w.writerows(faculty_rows)
print(f"faculty.csv: {len(faculty_rows)} rows "
      f"({sum(1 for r in faculty_rows if r['profile'] != 'none')} with profiles)")

last_to_id = {r["last_name"].lower(): r["scholar_id"] for r in faculty_rows if r["scholar_id"]}

# ----------------------------------------------------------- publications.csv
PUB_COLS = [
    "id", "title", "authors", "journal", "number", "year", "citations",
    "ses_faculty", "ses_grad_students", "ses_undergrad_students", "verified",
    "include_in_reports", "additional_notes", "pubid", "scholar_id_source",
    "date_added", "simple_title",
]

pubs = []
seen_ids = {}
with open(RAW / "Enhanced_Publications.csv") as f:
    raw_rows = list(csv.DictReader(f))

dropped = 0
for r in raw_rows:
    title = r["Title"].strip()
    if not title:
        dropped += 1
        continue
    st = simple_title(title)
    year = r["Year"].strip()
    pubid = r["PubID"].strip() or r["Needs_Manual_Review"].strip()
    sid = r["Scholar_ID_Source"].strip()
    sid = last_to_id.get(sid.lower(), sid)  # normalize last names to Scholar IDs
    base_id = f"{st[:40]}-{year or 'nd'}"
    n = seen_ids.get(base_id, 0)
    seen_ids[base_id] = n + 1
    pubs.append({
        "id": base_id if n == 0 else f"{base_id}-{n + 1}",
        "title": title,
        "authors": r["Authors"].strip(),
        "journal": r["Journal"].strip(),
        "number": r["Number"].strip(),
        "year": year,
        "citations": r["Citations"].strip() or "0",
        "ses_faculty": resep(r["SES_Faculty"]),
        "ses_grad_students": resep(r["SES_Grad_Students"], drop_excluded=True),
        "ses_undergrad_students": resep(r["SES_Undergrad_Students"]),
        "verified": str(r["Verified"].strip().upper() == "TRUE").lower(),
        "include_in_reports": str(r["Include_In_Reports"].strip().upper() != "FALSE").lower(),
        "additional_notes": r["Additional_Notes"].strip(),
        "pubid": pubid,
        "scholar_id_source": sid,
        "date_added": r["Date_Added"].strip(),
        "simple_title": st,
    })

pubs.sort(key=lambda p: (-(int(p["year"]) if p["year"] else 0), p["simple_title"]))
with open(DATA / "publications.csv", "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=PUB_COLS, quoting=csv.QUOTE_MINIMAL)
    w.writeheader()
    w.writerows(pubs)
print(f"publications.csv: {len(pubs)} rows ({dropped} blank dropped, "
      f"{sum(1 for p in pubs if p['verified'] == 'true')} verified)")

# --------------------------------------------------------------- students.csv
def parse_year(text: str):
    m = re.search(r"\d{2,4}", text or "")
    if not m:
        return ""
    y = int(m.group())
    return str(2000 + y if y < 100 else y)


students = []

with open(RAW / "students_Alumni.csv") as f:
    for r in csv.DictReader(f):
        first, last = r["FIRST"].strip(), r["LAST"].strip()
        if not first or not last:
            continue
        degree = (r.get("DEGREE") or "").strip()
        year = parse_year(r.get("YEAR", ""))
        start = ""
        if year:
            d = degree.upper()
            offset = 5 if ("PHD" in d or "DOCTOR" in d) else 2 if ("MS" in d or "MASTER" in d) else 3
            start = str(int(year) - offset)
        students.append({
            "first": first, "last": last, "full_name": f"{first} {last}",
            "degree": degree, "program": (r.get("SUBJECT") or "").strip(),
            "advisor": (r.get("Advisor") or "").strip(),
            "start_year": start, "status": "alumni", "notes": "",
        })

for tab, program in [("Current_ESP", "ESP"), ("Current_GLG", "GLG"),
                     ("Current_PhD", "PhD"), ("Current_CSS", "CSS")]:
    with open(RAW / f"students_{tab}.csv") as f:
        for r in csv.DictReader(f):
            first, last = (r.get("First") or "").strip(), (r.get("Last") or "").strip()
            if not first or not last:
                continue
            students.append({
                "first": first, "last": last, "full_name": f"{first} {last}",
                "degree": "PhD" if program == "PhD" else "MS",
                "program": program,
                "advisor": (r.get("Advisor") or "").strip(),
                "start_year": parse_year(r.get("Start Semester", "")),
                "status": "current", "notes": "",
            })

# Deduplicate on full_name (first occurrence wins, matching the old R logic)
# and drop the faculty members who appear in the roster.
seen = set()
deduped = []
for s in students:
    key = s["full_name"].lower()
    if key in seen or key in EXCLUDED_STUDENTS:
        continue
    seen.add(key)
    deduped.append(s)

deduped.sort(key=lambda s: (s["last"].lower(), s["first"].lower()))
with open(DATA / "students.csv", "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=list(deduped[0].keys()))
    w.writeheader()
    w.writerows(deduped)
print(f"students.csv: {len(deduped)} rows "
      f"({sum(1 for s in deduped if s['status'] == 'current')} current)")
