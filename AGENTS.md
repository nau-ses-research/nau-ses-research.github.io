# Agent Guide: SES Publications Site

This repo is the website of NAU's School of Earth and Sustainability
(https://ses-nau.org) plus the publication database and pipeline behind it.
It is maintained by Nick McKay (@nickmckay) with automated help from
Guy Clawdsen (@guyclawdsen), an OpenClaw agent. This file orients any agent
working here.

## Repo map

| Path | What it is |
|---|---|
| `data/` | **System of record**: publications, faculty, students CSVs. Read `data/README.md` before touching anything here. |
| `scripts/` | Python pipeline (`update_publications.py`), matcher logic + validator, content-migration tooling. |
| `tests/` | Fixture tests for the matcher logic. Run with `pytest`. |
| `src/` | Astro site (Astro 5, Tailwind 4, Preact islands). Content collections in `src/content/`. |
| `docs/` | Runbooks for the recurring jobs, interview template, style guide. |
| `public/` | Static passthrough assets (CNAME, favicon, robots.txt). |
| `archive/` | Retired R pipeline, kept as fallback until the Python pipeline is proven. Do not run against Google Sheets. |
| `.github/workflows/deploy.yml` | validate → build → deploy to GitHub Pages on push to main. |

## The two recurring jobs

1. **Weekly data update** (`docs/RUNBOOK-weekly-update.md`): refresh citation
   counts and add new publications from Google Scholar. Data-only PRs
   auto-merge when checks pass.
2. **Monthly student-research news story** (`docs/RUNBOOK-monthly-news.md`):
   pick a recent grad-student-led paper, interview the student by email, and
   publish a news article. **Always a PR requiring Nick's review; never a
   direct commit.**

## Hard rules

- **Respect the curation contract** in `data/README.md`: the pipeline only
  updates `citations` and appends new rows; it never edits human-owned fields
  (`verified`, `include_in_reports`, `ses_undergrad_students`,
  `additional_notes`) or any field except `citations` on verified rows.
- **Never bypass a failing guard.** If `update_publications.py` aborts, open a
  GitHub issue with the log and stop. Do not hand-edit data to make checks pass.
- **News stories need two sign-offs**: the featured student's explicit OK on
  their quotes, and Nick's PR review. Public prose about named students never
  ships on agent authority alone.
- Run `python3 scripts/validate_data.py` after any change to `data/`.
- Site changes: `npm run build` must pass. Keep the design system (pine/gold
  tokens in `src/styles/global.css`, existing components) rather than
  inventing new styles per page.
- Commit style: present tense, concise subject, body explains why. Data PRs
  use the summary printed by the pipeline as the PR body.

## Annual content updates (each fall)

The Current Students section (`src/content/grad-resources/` and
`src/pages/current-students/index.astro`) mirrors the SES grad program's
Google Site and links to staff-maintained Google Drive documents. Once a year
(August), propose a PR that:

- updates the handbook and Program of Study links to the new academic year's
  Drive files (ask Nick or Rebecca Best for them);
- refreshes the Grad Student Council roster;
- checks the seminar schedules, times, and rooms.

The recruitment banner (`src/components/AnnouncementBanner.astro`) is
seasonal: confirm with Nick each fall/spring whether it should be enabled and
what it should say.

## Local commands

```bash
python3 scripts/validate_data.py     # data integrity gate
python3 -m pytest tests/ -q          # matcher fixtures
uv run scripts/update_publications.py --dry-run   # pipeline rehearsal
npm ci && npm run build              # site build (dist/)
npm run dev                          # dev server
```
