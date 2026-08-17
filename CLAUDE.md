# SES Website and Publications Dashboard

The website of NAU's School of Earth and Sustainability (https://ses-nau.org):
an Astro static site on GitHub Pages, backed by a version-controlled
publication database mined weekly from Google Scholar.

Rebuilt August 2026 from the original R blogdown / Hugo Blox / Google Sheets
system (retired code in `archive/`). **Read `AGENTS.md` for the working rules
and `data/README.md` for the data curation contract before changing
anything.**

## Architecture

```
Google Scholar ──weekly──> scripts/update_publications.py ──PR──> data/*.csv
                                                                    │
                            src/ (Astro 5 + Tailwind 4) <──build────┘
                                       │
        .github/workflows/deploy.yml (validate -> build -> deploy-pages)
                                       │
                              https://ses-nau.org (GitHub Pages)
```

- `data/publications.csv` is the system of record (1,000+ publications,
  curation flags, ~unique `simple_title` dedup key, stable `id` for
  cross-references). Google Sheets is retired.
- The site reads the CSVs at build time (`src/lib/publications.ts`,
  `src/lib/stats.ts`); the `/publications/` explorer is a Preact island fed by
  a build-time JSON endpoint; `/research/` charts are build-time SVG.
- Content lives in Astro collections under `src/content/` (faculty,
  archived-faculty, themes, opportunities, news, pages).

## Recurring operations (run by Guy Clawdsen, @guyclawdsen)

- **Weekly data update:** `docs/RUNBOOK-weekly-update.md`. Data-only PRs
  auto-merge on green checks (CODEOWNERS leaves `data/` unowned).
- **Monthly student-research news story:** `docs/RUNBOOK-monthly-news.md`.
  Interview by email (Nick cc'd), student approves quotes, PR requires
  Nick's review.

## Commands

```bash
npm run dev                          # dev server
npm run build                        # production build to dist/
python3 scripts/validate_data.py     # data integrity gate (CI runs this)
python3 -m pytest tests/ -q          # matcher fixture tests
uv run scripts/update_publications.py --dry-run   # rehearse the weekly update
```

## Git workflow

- `main` is protected: changes land via PR with the `validate` and `build`
  checks. Site/content/docs changes need Nick's review; `data/`-only PRs
  auto-merge.
- Commit messages: present tense, specific subject, body says why. End with:

  ```
  🤖 Generated with [Claude Code](https://claude.ai/code)

  Co-Authored-By: Claude <noreply@anthropic.com>
  ```

## History note

Repo history was rewritten at the 2026-08 cutover (committed Hugo build
output stripped); clones from before then must be re-cloned, not pulled.
Mirror backups: `~/GitHub/SES_dashboard_backups/` on Nick's machine.
