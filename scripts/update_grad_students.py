#!/usr/bin/env python3
"""Rebuild the graduate-student directory from the Marketing folder.

Source of truth is SES Marketing on OneDrive, not this repo:

    Grad_Student_Info_4Web/
      Current list of SES Grad Students contact info.xlsx
      Grad_Student_Photos/

which reaches Guy's machine as a read-only mirror (see ses-drive). This script
turns that into `data/grad_students.csv` plus web-sized portraits under
`src/assets/grad-students/`, and prints a summary listing anything it could not
match, which is the part a human needs to look at.

    uv run scripts/update_grad_students.py [--source DIR] [--dry-run]
                                           [--summary-file PATH]

Nothing here is hand-edited: fix the spreadsheet or the photo filename and run
it again.
"""
import argparse
import csv
import difflib
import re
import sys
import unicodedata
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
OUT_CSV = REPO / "data" / "grad_students.csv"
OUT_PHOTOS = REPO / "src" / "assets" / "grad-students"
XLSX_NAME = "Current list of SES Grad Students contact info.xlsx"
PHOTO_DIR = "Grad_Student_Photos"

# Where the mirror lands, on Guy's machine and on Nick's Mac.
CANDIDATE_SOURCES = [
    Path.home() / ".openclaw-guy/workspace/drive-files/marketing/Grad_Student_Info_4Web",
    Path.home() / "Library/CloudStorage/OneDrive-NorthernArizonaUniversity"
    / "SES - Marketing/Grad_Student_Info_4Web",
]

# Sheet name -> (program code, label, degree). The sheet names are the only
# place the program is recorded, so a renamed sheet is a hard error, not a guess.
PROGRAMS = {
    "Current ESP": ("esp", "MS Environmental Sciences & Policy", "MS"),
    "Current GLG": ("glg", "MS Geosciences", "MS"),
    "Current PhD": ("phd", "PhD Earth Sciences & Environmental Sustainability", "PhD"),
    "Current CSS": ("css", "MS Climate Science & Solutions", "MS"),
}
PROGRAM_ORDER = ["phd", "glg", "esp", "css"]
MIN_STUDENTS = 20  # a real run is ~55; far fewer means the sheet moved or broke
PHOTO_MAX = 900  # px on the long edge


def log(msg):
    print(msg, flush=True)


def slugify(first, last):
    s = f"{first}-{last}".lower()
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode()
    return re.sub(r"-+", "-", re.sub(r"[^a-z0-9]+", "-", s)).strip("-")


def find_source(explicit):
    if explicit:
        p = Path(explicit).expanduser()
        if not p.is_dir():
            sys.exit(f"ABORT: --source {p} is not a directory.")
        return p
    for p in CANDIDATE_SOURCES:
        if p.is_dir():
            return p
    sys.exit(
        "ABORT: no Grad_Student_Info_4Web folder found. On Guy's machine the mirror "
        "is pushed from Nick's Mac: run `ses-drive status` and if it is stale or empty, "
        "tell Nick rather than looking for the files elsewhere."
    )


def read_students(xlsx):
    import openpyxl

    wb = openpyxl.load_workbook(xlsx, data_only=True)
    unknown = [s.title for s in wb.worksheets if s.title not in PROGRAMS]
    if unknown:
        sys.exit(f"ABORT: unexpected sheet(s) {unknown}. Expected {list(PROGRAMS)}. "
                 "If a program was added or renamed, this script needs updating.")
    students = []
    for ws in wb.worksheets:
        code, label, degree = PROGRAMS[ws.title]
        rows = [r for r in ws.iter_rows(values_only=True) if any(c not in (None, "") for c in r)]
        header = [str(c or "").strip().lower() for c in rows[0]]
        idx = {name: header.index(name) for name in header if name}

        def cell(row, *names):
            for n in names:
                if n in idx and idx[n] < len(row) and row[idx[n]] is not None:
                    return str(row[idx[n]]).strip()
            return ""

        for row in rows[1:]:
            last, first = cell(row, "last"), cell(row, "first")
            if not last or not first:
                continue
            students.append({
                "slug": slugify(first, last),
                "first": first,
                "last": last,
                "full_name": f"{first} {last}",
                "program": code,
                "program_label": label,
                "degree": degree,
                "advisor": cell(row, "advisor"),
                "email": cell(row, "email address", "email"),
                # A non-empty Leaders cell marks this year's grad student council rep.
                "council_rep": "true" if cell(row, "leaders", "leader") else "false",
                "cohort": cell(row, "cohort"),
                "photo": "",
            })
    return students


def parse_photo_name(name):
    """'Hartness, Taylor-ESP.jpeg' -> ('hartness', 'taylor'). Separators vary."""
    stem = Path(name).stem
    stem = re.sub(r"[.\-_ ]*(phd|esp|glg|css)\s*$", "", stem, flags=re.I).strip(" .-_")
    parts = [p.strip() for p in re.split(r"[,\-]| (?=[A-Z])", stem) if p.strip()]
    if len(parts) < 2:
        return None
    return parts[0].lower(), parts[1].lower()


def first_names_agree(sheet_first, photo_first):
    """Tolerate nicknames and initials: Lexi/Alexia, Katie/Katherine, Joe/Joseph."""
    a, b = sheet_first.lower(), photo_first.lower()
    if a.startswith(b[:3]) or b.startswith(a[:3]):
        return True
    return len(b) >= 3 and (b in a or a in b)


def match_photos(students, photo_dir, notes):
    by_last = {}
    for s in students:
        by_last.setdefault(s["last"].lower(), []).append(s)

    for path in sorted(photo_dir.iterdir()):
        if path.name.startswith(".") or not path.is_file():
            continue
        parsed = parse_photo_name(path.name)
        if not parsed:
            notes.append(f"photo not understood, skipped: {path.name}")
            continue
        a, b = parsed
        hit = None
        for last, first in ((a, b), (b, a)):  # filenames are not consistently Last,First
            for s in by_last.get(last, []):
                if first_names_agree(s["first"], first):
                    hit = s
                    break
            if hit:
                if (last, first) != (a, b):
                    notes.append(f"photo name is First,Last rather than Last,First: {path.name}")
                break
        if not hit:  # tolerate spelling slips in the filename
            close = difflib.get_close_matches(a, by_last.keys(), n=1, cutoff=0.82)
            if close:
                for s in by_last[close[0]]:
                    if first_names_agree(s["first"], b):
                        hit = s
                        notes.append(f"photo surname spelled {a!r}, matched {s['last']!r}: {path.name}")
                        break
        if not hit:
            notes.append(f"NO MATCHING STUDENT for photo {path.name} (not on any sheet)")
            continue
        if hit["photo"]:
            notes.append(f"second photo for {hit['full_name']}, ignored: {path.name}")
            continue
        hit["photo"] = str(path)


def write_photos(students, dry_run, notes):
    from PIL import Image

    if not dry_run:
        OUT_PHOTOS.mkdir(parents=True, exist_ok=True)
    written = set()
    for s in students:
        src = s.pop("photo", "")
        s["has_photo"] = "false"
        if not src:
            continue
        dest = OUT_PHOTOS / f"{s['slug']}.jpg"
        s["has_photo"] = "true"
        written.add(dest.name)
        if dry_run:
            continue
        with Image.open(src) as im:
            im = im.convert("RGB")
            im.thumbnail((PHOTO_MAX, PHOTO_MAX), Image.LANCZOS)
            # save() without an exif= argument drops EXIF, which is the point:
            # these are photos of people and may carry camera GPS.
            im.save(dest, "JPEG", quality=85, optimize=True)
    if not dry_run and OUT_PHOTOS.is_dir():
        for stale in OUT_PHOTOS.glob("*.jpg"):
            if stale.name not in written:
                stale.unlink()
                notes.append(f"removed portrait no longer in the source: {stale.name}")
    return len(written)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", help="Grad_Student_Info_4Web folder (default: auto-detect)")
    ap.add_argument("--dry-run", action="store_true", help="report, write nothing")
    ap.add_argument("--summary-file", type=Path, help="write the markdown summary here")
    args = ap.parse_args()

    src = find_source(args.source)
    xlsx, photos = src / XLSX_NAME, src / PHOTO_DIR
    if not xlsx.is_file():
        sys.exit(f"ABORT: {XLSX_NAME} not found in {src}.")
    if not photos.is_dir():
        sys.exit(f"ABORT: {PHOTO_DIR} not found in {src}.")
    log(f"source: {src}")

    notes = []
    students = read_students(xlsx)
    if len(students) < MIN_STUDENTS:
        sys.exit(f"ABORT: only {len(students)} students parsed (expected at least "
                 f"{MIN_STUDENTS}). Nothing was written; check the spreadsheet.")

    dupes = {s["slug"] for s in students if [x["slug"] for x in students].count(s["slug"]) > 1}
    if dupes:
        sys.exit(f"ABORT: duplicate slugs {sorted(dupes)}; two students share a name and "
                 "need distinguishing by hand.")

    match_photos(students, photos, notes)
    n_photos = write_photos(students, args.dry_run, notes)

    students.sort(key=lambda s: (PROGRAM_ORDER.index(s["program"]), s["last"].lower(),
                                 s["first"].lower()))
    cols = ["slug", "first", "last", "full_name", "program", "program_label", "degree",
            "advisor", "email", "council_rep", "cohort", "has_photo"]
    if not args.dry_run:
        with open(OUT_CSV, "w", newline="") as fh:
            w = csv.DictWriter(fh, fieldnames=cols)
            w.writeheader()
            w.writerows(students)

    by_prog = {c: sum(1 for s in students if s["program"] == c) for c in PROGRAM_ORDER}
    summary = [f"Graduate student directory ({len(students)} students)", ""]
    summary += [f"- {PROGRAMS[[k for k, v in PROGRAMS.items() if v[0] == c][0]][1]}: {n}"
                for c, n in by_prog.items()]
    summary.append(f"- Portraits: {n_photos} of {len(students)}")
    no_email = [s["full_name"] for s in students if not s["email"]]
    if no_email:
        summary.append(f"- No email address in the sheet: {', '.join(no_email)}")
    if notes:
        summary.append("")
        summary.append("Needs a human eye:")
        summary += [f"- {n}" for n in notes]
    text = "\n".join(summary)
    log("\n" + text)
    if args.summary_file and not args.dry_run:
        args.summary_file.write_text(text + "\n")
    if args.dry_run:
        log("\n(dry run: nothing written)")


if __name__ == "__main__":
    main()
