#!/usr/bin/env python3
# /// script
# requires-python = ">=3.10"
# dependencies = ["playwright>=1.45", "pyyaml>=6"]
# ///
"""Submit a published SES news story to the CEFNS college blog.

The college takes story submissions through a Gravity Forms page:
https://in.nau.edu/college-environment-forestry-natural-sciences/blog/submit-post/
This script turns one story under src/content/news/ into that form's fields
and fills the form in headless Chromium. A real browser is needed because
the form's spam honeypot is set by JavaScript; a bare HTTP POST would be
accepted and then silently filed as spam.

Run from the repo root, after the story is live on ses-nau.org:

    uv run scripts/submit_cefns_story.py <story-slug>            # dry run
    uv run scripts/submit_cefns_story.py <story-slug> --submit   # for real

The dry run prints every field, fills the form without uploading or
submitting anything, and saves a screenshot. --submit uploads the photo,
submits, checks for the form's confirmation message, and appends a row to
the ledger. A slug already in the ledger is refused unless --force, so a
story is never sent to the college twice. A story over the form's 4,000
characters needs a shortened version passed with --story-file; the script
checks its length and that its quotes are verbatim. See
docs/RUNBOOK-monthly-news.md step 5c.

First run on a new machine: uv run --with playwright playwright install chromium
"""
from __future__ import annotations

import argparse
import csv
import os
import re
import sys
import tempfile
import time
import urllib.request
from datetime import datetime
from pathlib import Path

import yaml

FORM_URL = "https://in.nau.edu/college-environment-forestry-natural-sciences/blog/submit-post/"
SITE = "https://ses-nau.org"
REPO = Path(__file__).resolve().parent.parent
NEWS = REPO / "src" / "content" / "news"
STORY_MAX = 4000  # the form's maxlength on "Tell us your story"
DEFAULT_LEDGER = Path(os.environ.get(
    "CEFNS_LEDGER", "~/.local/state/ses/cefns-submissions.tsv")).expanduser()
LEDGER_FIELDS = ["slug", "status", "submitted_at", "title", "url", "confirmation"]

DEPARTMENT = "School of Earth & Sustainability"
AUDIENCES = [
    "Prospective students",
    "Current students",
    "Researchers and academic audiences",
    "General public",
]
CONTACT = "Nick McKay (nick@nau.edu)"


def load_story(slug: str) -> dict:
    path = NEWS / slug / "index.md"
    if not path.exists():
        sys.exit(f"No story at {path.relative_to(REPO)}")
    _, front, body = path.read_text(encoding="utf-8").split("---", 2)
    story = yaml.safe_load(front)
    story["slug"] = slug
    story["body"] = body.strip()
    story["url"] = f"{SITE}/news/{slug}/"
    images = sorted((NEWS / slug).glob("featured.*"))
    story["image"] = images[0] if images else None
    story["paper"] = find_paper(story.get("publication_id"))
    return story


def find_paper(pub_id: str | None) -> dict | None:
    if not pub_id:
        return None
    with open(REPO / "data" / "publications.csv", newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            if row["id"] == pub_id:
                return row
    return None


def plain_text(md: str) -> str:
    """Markdown story body to the plain text a form textarea can carry."""
    text = re.sub(r"!\[[^\]]*\]\([^)]*\)", "", md)                # images
    text = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r"\1 (\2)", text)   # links
    text = re.sub(r"^#{1,6}\s*", "", text, flags=re.M)             # headings
    text = re.sub(r"(\*\*|__)(.+?)\1", r"\2", text)                 # bold
    text = re.sub(r"(?<![\w*])[*_](?!\s)(.+?)(?<!\s)[*_](?![\w*])", r"\1", text)  # italics
    text = re.sub(r"^\s*[-*]\s+", "- ", text, flags=re.M)          # bullets
    return re.sub(r"\n{3,}", "\n\n", text).strip()


def story_field(story: dict, short_file: Path | None) -> str:
    """The story text for the form: the published story, or a shortened one.

    A story over the form's limit needs a shortened version written for it
    (runbook step 5c), passed with --story-file. It must fit, and every quote
    in it must appear word for word in the published story.
    """
    full = f"{story['title']}\n\n{plain_text(story['body'])}"
    if short_file is None:
        if len(full) > STORY_MAX:
            sys.exit(f"The story is {len(full)} characters; the form takes {STORY_MAX}. "
                     "Write a shortened version (runbook step 5c) and pass it "
                     "with --story-file.")
        return full
    short = short_file.read_text(encoding="utf-8").strip()
    if len(short) > STORY_MAX:
        sys.exit(f"{short_file} is {len(short)} characters; it must be {STORY_MAX} or fewer.")
    norm = lambda s: " ".join(s.split())  # noqa: E731
    quotes = re.findall(r"“(.+?)”", short, flags=re.S) + re.findall(r'"([^"]+)"', short)
    altered = [q for q in quotes if norm(q) not in norm(full)]
    if altered:
        sys.exit("These quotes in the shortened version are not word for word "
                 "in the published story:\n" + "\n".join(f"  {q}" for q in altered))
    return short


def citation(paper: dict) -> str:
    authors = paper["authors"]
    doi = f" https://doi.org/{paper['doi']}" if paper.get("doi") else ""
    return f"{authors} ({paper['year']}). {paper['title']}. {paper['journal']}.{doi}"


def anything_else(story: dict) -> str:
    published = story["date"]
    lines = [
        f"This story was published on the School of Earth and Sustainability "
        f"website on {published:%B %-d, %Y}: {story['url']}",
        "",
        "Submitted on behalf of SES by Guy Clawdsen, the AI assistant that "
        "helps run the SES website and its news section. The story was "
        "written from an email interview, and every quote in it was approved "
        "in writing by the person quoted. For questions or anything that "
        f"needs a person, please contact {CONTACT}.",
    ]
    people = []
    if story.get("students"):
        people.append("Student researcher(s): " + ", ".join(story["students"]))
    if story.get("faculty"):
        people.append("SES faculty: " + ", ".join(story["faculty"]))
    if people:
        lines += [""] + people
    if story["paper"]:
        lines += ["", "Paper: " + citation(story["paper"])]
    if story["image"]:
        photo = "Photo (attached): " + story.get("image_caption", "").strip()
        if story.get("image_credit"):
            photo += " " + story["image_credit"].strip()
        if story.get("image_alt"):
            photo += f"\nAlt text: {story['image_alt'].strip()}"
        lines += ["", photo]
    return "\n".join(lines)


def topics(story: dict) -> list[str]:
    t = ["Research or discovery"]
    if story.get("students"):
        t.append("Student experience or accomplishment")
    return t


def links(story: dict) -> str:
    out = [story["url"]]
    if story["paper"] and story["paper"].get("doi"):
        out.append(f"https://doi.org/{story['paper']['doi']}")
    return " ".join(out)


def read_ledger(path: Path) -> list[dict]:
    if not path.exists():
        return []
    with open(path, newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f, delimiter="\t"))
    for r in rows:  # rows from before the status column were all confirmed
        r["status"] = r.get("status") or "confirmed"
    return rows


def set_ledger(path: Path, slug: str, row: dict | None) -> None:
    """Replace this slug's latest row with `row`, or drop it when row is None.

    A row goes in as `pending` before the form is submitted and becomes
    `confirmed` only after the thank-you message, so a submission whose
    outcome is unknown still blocks an ordinary rerun.
    """
    rows = read_ledger(path)
    idx = max((i for i, r in enumerate(rows) if r["slug"] == slug), default=None)
    if idx is not None and rows[idx]["status"] == "pending":
        rows.pop(idx)
    if row is not None:
        rows.append(row)
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".tmp")
    with open(tmp, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=LEDGER_FIELDS, delimiter="\t", extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)
    tmp.replace(path)


def check_live(url: str) -> None:
    try:
        with urllib.request.urlopen(url, timeout=30) as r:
            if r.status == 200:
                return
    except Exception as e:  # noqa: BLE001
        sys.exit(f"{url} is not live yet ({e}). Submit after the story renders.")
    sys.exit(f"{url} did not return 200. Submit after the story renders.")


def fill_and_submit(fields: dict, files: list[Path], submit: bool, shot: Path,
                    before_submit=lambda: None, on_rejected=lambda: None) -> str:
    from playwright.sync_api import sync_playwright

    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page(viewport={"width": 1200, "height": 900})
        # The site serves this page from a cache whose file-upload nonce can be
        # days old, and uploads against it fail with "Your session has
        # expired". A throwaway query string gets a freshly rendered page.
        page.goto(f"{FORM_URL}?nc={time.time_ns()}", wait_until="networkidle")
        form = page.locator("#gform_16")
        form.wait_for()

        form.locator("#input_16_3_3").fill(fields["first"])
        form.locator("#input_16_3_6").fill(fields["last"])
        form.locator("#input_16_5").fill(fields["email"])
        form.locator("#input_16_19").select_option(fields["role"])
        form.locator("#input_16_1").select_option(fields["department"])
        form.locator("#input_16_21").fill(fields["story"])
        for value in fields["topics"]:
            form.locator(f"input[name^='input_8.'][value='{value}']").check()
        for value in fields["audiences"]:
            form.locator(f"input[name^='input_9.'][value='{value}']").check()
        form.locator("#input_16_12").fill(fields["anything_else"])
        form.locator("#input_16_22").fill(fields["links"])

        if submit and files:
            # Gravity Forms uploads each file as it is added and records it in
            # a hidden input; submitting before that finishes drops it. Keep
            # the upload endpoint's replies so a rejection says why.
            replies: list[str] = []
            page.on("response", lambda r: replies.append(f"{r.status} {r.text()[:300]}")
                    if "gf_page=" in r.url else None)
            form.locator("#field_16_14 input[type=file]").set_input_files(
                [str(f) for f in files])
            names = [f.name for f in files]
            try:
                page.wait_for_function(
                    """names => {
                        const v = document.querySelector('#gform_uploaded_files_16').value;
                        return names.every(n => v.includes(n));
                    }""",
                    arg=names, timeout=120_000)
            except Exception:  # noqa: BLE001
                browser.close()
                sys.exit("File upload did not complete; nothing was submitted.\n"
                         "Upload replies:\n" + ("\n".join(replies) or "none"))

        page.screenshot(path=str(shot), full_page=True)
        if not submit:
            browser.close()
            return ""

        before_submit()
        form.locator("#gform_submit_button_16").click()
        page.wait_for_selector(
            ".gform_confirmation_message, .gform_validation_errors, .validation_message",
            timeout=60_000)
        page.screenshot(path=str(shot.with_name(shot.stem + "-result.png")), full_page=True)
        conf = page.locator(".gform_confirmation_message")
        if conf.count() == 0:
            errors = page.locator(".gform_validation_errors, .validation_message").all_inner_texts()
            browser.close()
            on_rejected()
            sys.exit("The form rejected the submission:\n" + "\n".join(errors))
        text = " ".join(conf.first.inner_text().split())
        browser.close()
        return text


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("slug", help="story folder under src/content/news/, e.g. 2026-09-pacific-mantle")
    ap.add_argument("--submit", action="store_true", help="actually submit (default is a dry run)")
    ap.add_argument("--force", action="store_true", help="submit even if the ledger says it was sent")
    ap.add_argument("--no-photo", action="store_true", help="leave the featured image out")
    ap.add_argument("--story-file", type=Path,
                    help="shortened story text, required when the story is over 4,000 characters")
    ap.add_argument("--name", default="Guy Clawdsen")
    ap.add_argument("--email", default="guy@ses-nau.org")
    ap.add_argument("--ledger", type=Path, default=DEFAULT_LEDGER)
    args = ap.parse_args()

    story = load_story(args.slug)
    if args.no_photo:
        story["image"] = None
    sent = [r for r in read_ledger(args.ledger) if r["slug"] == args.slug]
    if sent and args.submit and not args.force:
        last = sent[-1]
        if last["status"] == "pending":
            sys.exit(f"{args.slug} was submitted on {last['submitted_at']} but never "
                     "confirmed, so the college may already have it. Check Guy's inbox "
                     "for their confirmation and ask Nick before rerunning with --force.")
        sys.exit(f"{args.slug} was already submitted on {last['submitted_at']} "
                 f"(ledger {args.ledger}). Use --force only if the college asked for it again.")

    text = story_field(story, args.story_file)
    first, _, last = args.name.partition(" ")
    fields = {
        "first": first, "last": last, "email": args.email, "role": "Other",
        "department": DEPARTMENT, "story": text, "topics": topics(story),
        "audiences": AUDIENCES, "anything_else": anything_else(story),
        "links": links(story),
    }

    workdir = Path(tempfile.mkdtemp(prefix=f"cefns-{args.slug}-"))
    files: list[Path] = []
    if story["image"]:
        files.append(story["image"])

    for key in ["first", "last", "email", "role", "department", "topics", "audiences", "links"]:
        print(f"{key}: {fields[key]}")
    version = f", shortened from {args.story_file}" if args.story_file else ""
    print(f"\nstory ({len(text)}/{STORY_MAX} chars{version}):\n{text}")
    print(f"\nanything_else:\n{fields['anything_else']}")
    print("\nfiles:", ", ".join(str(f) for f in files) or "none")

    if args.submit:
        check_live(story["url"])
    shot = workdir / f"{args.slug}.png"
    row = {"slug": args.slug, "status": "pending",
           "submitted_at": datetime.now().astimezone().isoformat(timespec="seconds"),
           "title": story["title"], "url": story["url"], "confirmation": ""}
    conf = fill_and_submit(
        fields, files, args.submit, shot,
        before_submit=lambda: set_ledger(args.ledger, args.slug, row),
        on_rejected=lambda: set_ledger(args.ledger, args.slug, None))
    print(f"\nscreenshot: {shot}")
    if not args.submit:
        print("Dry run: form filled, nothing uploaded or submitted.")
        return

    set_ledger(args.ledger, args.slug, {**row, "status": "confirmed", "confirmation": conf})
    print(f"Submitted. Confirmation: {conf}\nLedger: {args.ledger}")


if __name__ == "__main__":
    main()
