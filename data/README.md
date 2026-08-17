# SES Publications Data

These CSVs are the **system of record** for the SES publications site. They
replaced the Google Sheets database at the August 2026 cutover (final export
preserved in the repo history and in `~/GitHub/SES_dashboard_backups/`).
Everything on the site's publications explorer and research-impact dashboard is
built from these files at deploy time.

Validate any change with `python3 scripts/validate_data.py` (CI runs it on
every PR that touches `data/`).

## Files

### `publications.csv`

One row per publication, sorted by `year` descending then `simple_title`
ascending (keep this sort; it makes weekly diffs line-scoped).

| column | meaning |
|---|---|
| `id` | Stable key: first 40 chars of `simple_title` + `-` + year. Used by news articles (`publication_id` frontmatter) and explorer deep links. Never change it once assigned. |
| `title`, `authors`, `journal`, `number`, `year` | Bibliographic fields from Google Scholar. `authors` is a plain author string ("A Springer, LE Stevens"). |
| `citations` | Google Scholar citation count; refreshed weekly. |
| `ses_faculty` | SES faculty co-authors as `"; "`-separated `"F Last"` labels matching `faculty.csv` (`first_initial` + `last_name`). |
| `ses_grad_students` | Grad-student co-authors, `"; "`-separated full names, auto-detected against `students.csv`. |
| `ses_undergrad_students` | Undergrad co-authors, manually curated. |
| `verified` | `true` once a human has checked the row. |
| `include_in_reports` | `false` hides the row from all site stats and listings. |
| `additional_notes` | Free-text curation notes. |
| `pubid` | Google Scholar per-publication id. |
| `scholar_id_source` | Scholar profile ID the row was first fetched from. |
| `date_added` | ISO date the row entered the database. |
| `simple_title` | Lowercased alphanumeric-only title; the **dedup key** (must be unique). |

Multi-value fields use `"; "` separators, never bare commas.

### `faculty.csv`

One row per faculty member ever mined. `first_initial` + `last_name` drive
author matching; `scholar_id` (blank = no Scholar profile) drives fetching;
`start_year`/`end_year` bound which publication years count for that person
(blank `end_year` = still active, and `active` mirrors that); `slug` +
`profile` (`current` / `archived` / `none`) link names to profile pages on the
site.

### `students.csv`

Graduate student roster (snapshot of the old Google Sheet, now hand-maintained
here). `status` is `current` or `alumni`; `start_year` is used to reject
author matches on papers published before the student plausibly started
(alumni heuristic: PhD = graduation year - 5, MS = - 2, otherwise - 3).
Faculty who also appear in old rosters (Nicholas McKay, Lisa Thompson) are
excluded and must stay excluded.

## Curation contract

The weekly pipeline (`scripts/update_publications.py`, run by Guy Clawdsen)
and human curators share `publications.csv` under these rules:

**The pipeline may only:**
- update `citations` on existing rows (including `verified` ones);
- append new rows, always with `verified=false`, `include_in_reports=true`;
- never delete rows, never resort beyond the canonical sort, never edit any
  other field on an existing row.

**Humans (Nick, or Guy acting on Nick's instruction) own:**
- `verified`, `include_in_reports`, `ses_undergrad_students`,
  `additional_notes`, and every field except `citations` on `verified=true`
  rows. Fix a bad auto-match by editing the row and setting `verified=true`
  so the pipeline never touches it again.

"Featured in a news story" is deliberately **not** a column here; it lives in
the news article frontmatter (`publication_id`) under `src/content/news/`, so
the pipeline and the news workflow can never clobber each other.
