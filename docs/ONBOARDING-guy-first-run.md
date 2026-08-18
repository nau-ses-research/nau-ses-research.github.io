# Onboarding: Guy's First Run (Catch-Up Update)

**For:** Guy Clawdsen (@guyclawdsen)
**From:** Nick
**Goal:** Get set up on the rebuilt SES site repo, then run your first
publications update. This first run is special: the database hasn't been
refreshed since August 2025, so you're catching up a full year, not a normal
week. Nick is supervising this one; ask questions freely.

## 1. One-time setup

The repo history was rewritten on 2026-08-17 (it shrank from 1.7 GB to
~40 MB). **Any clone you have from before then is unusable; do not pull into
it. Delete it and re-clone:**

```bash
git clone https://github.com/nau-ses-research/nau-ses-research.github.io.git ses-site
cd ses-site
```

Install [uv](https://docs.astral.sh/uv/) if you don't have it, then:

```bash
uv sync                       # installs scholarly + pytest
uv run pytest tests/ -q       # should report 27 passed
uv run python scripts/validate_data.py   # should end with "OK: publications=..."
gh auth status                # confirm you can act on GitHub as guyclawdsen
```

Then read, in this order:

1. `AGENTS.md` (the working rules; short)
2. `data/README.md` (the curation contract; **this is the important one**)
3. `docs/RUNBOOK-weekly-update.md` (the job you're about to do)

## 2. What's different about this first run

- **It's a year of backlog.** Expect several hundred citation updates (a
  2026-08-17 rehearsal found 856) and potentially 100+ new 2025–2026
  publications, instead of a normal week's handful.
- **Dry-run first, always, on this run:**

  ```bash
  uv run scripts/update_publications.py --dry-run --summary-file update_summary.md
  ```

  This catch-up run is long: **expect 30–90 minutes** (polite delays between
  ~40 Scholar profile fetches, plus a detail fetch and DOI lookup per new
  paper; there may be 100+ of them). If your execution environment enforces
  command timeouts, run it detached so it survives:

  ```bash
  nohup uv run scripts/update_publications.py --dry-run \
    --summary-file update_summary.md > update_run.log 2>&1 &
  ```

  and follow `update_run.log`. The summary file appears in a PRELIMINARY
  form once the citation pass finishes and is overwritten with the final
  version at the end. If Scholar starts refusing fetches, stop and wait
  3–6 hours before one retry; don't hammer it. Read the whole summary before
  doing anything else. Sanity checks:
  - Profiles fetched should be ~40/42 (two faculty have flaky profiles).
    If the run aborts with a low fetch rate, Scholar is blocking; wait a few
    hours and try once more, then open an issue per the runbook.
  - New publications should all be from 2025 or 2026, with sensible
    journals and correctly matched `ses_faculty` names.
  - Spot-check 3 or 4 new entries against Google Scholar by hand.
- **The 150-new-row guard may trip.** The pipeline refuses to add 150+ rows
  because in a normal week that means something is wrong. In THIS run it may
  simply be the backlog. If it aborts on that guard: review the dry-run
  summary with Nick, and only after his OK rerun with an explicit override,
  e.g. `--max-new-rows 300`. Never use that flag on a routine weekly run.
- **Post the dry-run summary to Nick before the real run.** For this first
  run only, wait for his thumbs-up between dry run and write.

## 3. The real run

Exactly as in `docs/RUNBOOK-weekly-update.md`:

```bash
git checkout main && git pull
uv run scripts/update_publications.py --summary-file update_summary.md \
  # add --max-new-rows N only if Nick approved it in step 2
git checkout -b data-update-$(date +%Y-%m-%d)
git add data/publications.csv
git commit -m "Catch-up publications update $(date +%Y-%m-%d) (2025-08 to now)"
git push -u origin HEAD
gh pr create --title "Catch-up publications update $(date +%Y-%m-%d)" \
  --body-file update_summary.md
gh pr merge --auto --squash
```

The PR auto-merges once the `Validate data` and `Build site` checks pass; no
human review is required for `data/`-only changes. Then confirm:

- the PR merged and the "Build and deploy site" workflow went green;
- https://ses-nau.org/research/ shows updated citation totals (it currently
  says 71,631 citations; the number should grow);
- https://ses-nau.org/publications/ lists 2026 papers at the top.

## 4. Afterward

- Set up your own weekly schedule for the runbook (suggested: Monday
  mornings). The schedule lives on your side; there is no cron in this repo.
- Report back to Nick: how long the run took, anything confusing in the
  runbook, anything you'd change. The runbooks are living documents; propose
  edits via PR (docs changes need Nick's review).
- Rules that never bend, even when a guard is inconvenient: the pipeline
  only updates `citations` and appends rows; never hand-edit data to get past
  a failing check; when in doubt, stop and open an issue.
