"""Fixture tests for the matcher logic ported from update_publications_2025.R.

These encode the accumulated fixes from a year of running the R pipeline;
if a pattern change breaks one of these, it will re-break a known case.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))

from matchers import (
    Faculty, Student, is_excluded_journal, match_faculty,
    match_grad_students, simple_title,
)

KAUFMAN = Faculty("D", "Kaufman")
MCKAY = Faculty("N", "McKay")
SMITH_KONTER = Faculty("B", "Smith-Konter")
SHORT = Faculty("A", "Yu")  # sub-3-char last name must be skipped
FACULTY = [KAUFMAN, MCKAY, SMITH_KONTER, SHORT]

BARANSKY = Student("Eva", "Baransky", start_year=2020)
HANCOCK = Student("Chris", "Hancock", start_year=2019)
CAPS = Student("STEPHANIE", "ARCUSA", start_year=2015)
STUDENTS = [BARANSKY, HANCOCK, CAPS]


class TestSimpleTitle:
    def test_strips_punctuation_and_case(self):
        assert simple_title("A 15,800-year record: Alaska!") == "a15800yearrecordalaska"

    def test_empty(self):
        assert simple_title("") == ""


class TestFacultyMatching:
    def test_initial_space_last(self):
        assert match_faculty("D Kaufman, J Smith", FACULTY) == ["D Kaufman"]

    def test_initial_period_last(self):
        assert match_faculty("D. Kaufman, J Smith", FACULTY) == ["D Kaufman"]

    def test_last_comma_initial(self):
        assert match_faculty("Kaufman, D and others", FACULTY) == ["D Kaufman"]

    def test_full_first_name(self):
        assert match_faculty("Darrell Kaufman, Jane Doe", FACULTY) == ["D Kaufman"]

    def test_initials_with_middle(self):
        # "DS Kaufman" / "NP McKay" is how Scholar renders middle initials;
        # the "\bd[a-z]*\s+kaufman" pattern covers them.
        # (results follow faculty-list order, not author order)
        assert match_faculty("NP McKay, DS Kaufman", FACULTY) == ["D Kaufman", "N McKay"]

    def test_hyphenated_last_name(self):
        assert match_faculty("B Smith-Konter", FACULTY) == ["B Smith-Konter"]

    def test_short_last_name_skipped(self):
        assert match_faculty("A Yu, B Wong", FACULTY) == []

    def test_wrong_initial_no_match(self):
        assert match_faculty("Q Kaufman", FACULTY) == []

    def test_multiple_and_order(self):
        got = match_faculty("D Kaufman, NP McKay", FACULTY)
        assert got == ["D Kaufman", "N McKay"]

    def test_empty_authors(self):
        assert match_faculty("", FACULTY) == []
        assert match_faculty(None, FACULTY) == []


class TestStudentMatching:
    def test_full_name(self):
        assert match_grad_students("Eva Baransky, D Kaufman", 2022, STUDENTS) == ["Eva Baransky"]

    def test_single_initial(self):
        assert match_grad_students("E Baransky, D Kaufman", 2022, STUDENTS) == ["Eva Baransky"]

    def test_middle_initial_pair(self):
        # The "EJ Baransky" fix the R pipeline added explicitly.
        assert match_grad_students("EJ Baransky, D Kaufman", 2022, STUDENTS) == ["Eva Baransky"]

    def test_periods_stripped(self):
        assert match_grad_students("E.J. Baransky", 2022, STUDENTS) == ["Eva Baransky"]

    def test_last_comma_initial(self):
        assert match_grad_students("Baransky, E", 2022, STUDENTS) == ["Eva Baransky"]

    def test_timeline_rejects_pre_start_papers(self):
        assert match_grad_students("Eva Baransky", 2018, STUDENTS) == []

    def test_timeline_allows_missing_years(self):
        assert match_grad_students("Eva Baransky", None, STUDENTS) == ["Eva Baransky"]

    def test_all_caps_roster_name_display(self):
        assert match_grad_students("S Arcusa, NP McKay", 2020, STUDENTS) == ["Stephanie Arcusa"]

    def test_wrong_initial_no_match(self):
        assert match_grad_students("Q Baransky", 2022, STUDENTS) == []

    def test_no_match_without_last_name(self):
        assert match_grad_students("Eva Smith", 2022, STUDENTS) == []


class TestJournalExclusion:
    def test_conference_abstracts(self):
        assert is_excluded_journal("AGU Fall Meeting Abstracts")
        assert is_excluded_journal("EGU General Assembly Conference Abstracts")

    def test_preprints(self):
        assert is_excluded_journal("bioRxiv")
        assert is_excluded_journal("EarthArXiv preprint")
        assert is_excluded_journal("ESS Open Archive Preprint")

    def test_awards(self):
        assert is_excluded_journal("NSF Award 1234567")

    def test_real_journals_pass(self):
        assert not is_excluded_journal("Nature")
        assert not is_excluded_journal("Hydrogeology Journal")
        assert not is_excluded_journal("Quaternary Science Reviews")

    def test_empty(self):
        assert not is_excluded_journal("")
        assert not is_excluded_journal(None)
