"""Author-matching, dedup, and filtering logic for the SES publications pipeline.

Ported from update_publications_2025.R (archive/) at the 2026-08 cutover.
The regex patterns encode years of accumulated fixes (first-initial matching,
"EJ Baransky"-style middle initials, short-name skips); change them only with
fixture tests in tests/test_matchers.py to back you up.
"""

from __future__ import annotations

import re
from dataclasses import dataclass


def simple_title(title: str) -> str:
    """Dedup key: lowercased alphanumeric-only title."""
    return re.sub(r"[^A-Za-z0-9]", "", title or "").lower()


# Journals matching any of these substrings are not peer-reviewed articles
# (conference abstracts, preprints, awards) and are never added.
JOURNAL_EXCLUSION_PATTERNS = (
    "meeting", "abstracts", "conference", "joint", "abstract", "symposium",
    "proceedings", "workshop", "congress", "summit",
    "rxiv", "preprint", "nsf award",
)


def is_excluded_journal(journal: str | None) -> bool:
    if not journal:
        return False
    j = journal.lower()
    return any(p in j for p in JOURNAL_EXCLUSION_PATTERNS)


@dataclass(frozen=True)
class Faculty:
    first_initial: str
    last_name: str

    @property
    def label(self) -> str:
        return f"{self.first_initial} {self.last_name}"


def match_faculty(authors: str | None, faculty: list[Faculty]) -> list[str]:
    """Return labels ("D Kaufman") of faculty appearing in an author string.

    Mirrors extract_faculty_with_initials() in the R pipeline: strip the
    author string to letters/commas/periods/spaces, lowercase, then match
    "D Kaufman", "D. Kaufman", "Kaufman, D", or "Darrell Kaufman" forms.
    Last names shorter than 3 characters are skipped (too match-prone).
    """
    if not authors:
        return []
    cleaned = re.sub(r"[^a-zA-Z, .]", "", authors).lower()
    matches = []
    for f in faculty:
        fi = f.first_initial.lower()
        # The author string has hyphens stripped, so strip them from the
        # last name too ("Smith-Konter" -> "smithkonter"); the R pipeline
        # missed this and could never match hyphenated names.
        last = re.sub(r"[^a-z]", "", f.last_name.lower())
        if len(last) < 3:
            continue
        patterns = (
            rf"\b{fi}\s*\.?\s*{re.escape(last)}\b",      # "D Kaufman" / "D. Kaufman"
            rf"\b{re.escape(last)}\b.*\b{fi}\b",         # "Kaufman, D"
            rf"\b{fi}[a-z]*\s+{re.escape(last)}\b",      # "Darrell Kaufman"
            rf"\b{fi}[a-z]*\s+[a-z]\.?\s+{re.escape(last)}\b",  # "James B. Gaherty" (Crossref style)
        )
        if any(re.search(p, cleaned) for p in patterns):
            matches.append(f.label)
    return list(dict.fromkeys(matches))


@dataclass(frozen=True)
class Student:
    first: str
    last: str
    start_year: int | None = None
    end_year: int | None = None  # graduation year for alumni; None = current

    @property
    def display_name(self) -> str:
        """Roster name for tagging; title-case only all-caps roster entries."""
        def fix(part: str) -> str:
            return part.title() if part.isupper() else part
        return f"{fix(self.first)} {fix(self.last)}"


def match_grad_students(
    authors: str | None, pub_year: int | None, students: list[Student]
) -> list[str]:
    """Return display names of grad students appearing in an author string.

    Mirrors match_grad_students() in the R pipeline: strip to letters, commas,
    and spaces (periods removed, so "E.J. Baransky" becomes "EJ Baransky"),
    lowercase, require the bare last name, then match first-name/initial/
    middle-initial and "Last, F" forms. A match is rejected if the paper
    predates the student's start_year.
    """
    if not authors:
        return []
    cleaned = re.sub(r"[^a-zA-Z, ]", "", authors).lower()
    matches = []
    for s in students:
        first = re.sub(r"[^a-z]", "", s.first.lower())
        last = re.sub(r"[^a-z]", "", s.last.lower())
        if len(first) < 2 or len(last) < 3:
            continue
        if not re.search(rf"\b{re.escape(last)}\b", cleaned):
            continue
        fi = first[0]
        patterns = (
            rf"\b{re.escape(first)}\s+{re.escape(last)}\b",   # "Eva Baransky"
            rf"\b{fi}\s+{re.escape(last)}\b",                 # "E Baransky"
            rf"\b{fi}[a-z]\s+{re.escape(last)}\b",            # "EJ Baransky"
            rf"\b{fi}[a-z]+\s+{re.escape(last)}\b",           # full first name
            rf"\b{re.escape(first)}\s+[a-z]\s+{re.escape(last)}\b",  # "Joseph H Phillips" (Crossref style)
            rf"\b{fi}[a-z]+\s+[a-z]\s+{re.escape(last)}\b",  # full first + middle initial
            rf"\b{re.escape(last)}\s*,\s*{fi}\b",             # "Baransky, E"
            rf"\b{re.escape(last)}\s*,\s*{fi}[a-z]\b",        # "Baransky, EJ"
        )
        if any(re.search(p, cleaned) for p in patterns):
            after_start = s.start_year is None or pub_year is None or pub_year >= s.start_year
            # 3-year grace: thesis work commonly publishes up to a few
            # years after graduation (policy set by Nick, 2026-08-20)
            before_end = s.end_year is None or pub_year is None or pub_year <= s.end_year + 3
            if after_start and before_end:
                matches.append(s.display_name)
    return list(dict.fromkeys(matches))
