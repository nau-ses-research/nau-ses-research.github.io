# Runbook: Weekly Publications Update

**Who:** Guy Clawdsen (@guyclawdsen), weekly (scheduled on Guy's side; suggested
Monday morning). Nick can also run it manually anytime.
**What:** Refresh citation counts and add new publications from Google Scholar
to `data/publications.csv`, then get the change merged so the site redeploys.

## Steps

1. **Sync:**
   ```bash
   git checkout main && git pull
   ```
2. **Run the pipeline:**
   ```bash
   uv run scripts/update_publications.py --summary-file update_summary.md
   ```
   (First time: `uv sync` to install dependencies. Plain
   `python3 scripts/update_publications.py` works in any env with `scholarly`.)
   The run takes 5–15 minutes: it fetches ~40 Scholar profiles with polite
   delays, updates citations, appends new publications, and validates. It
   aborts by itself (writing nothing) if Scholar looks blocked or the numbers
   look wrong.
3. **If it succeeded with changes:**
   ```bash
   git checkout -b data-update-$(date +%Y-%m-%d)
   git add data/publications.csv
   git commit -m "Weekly publications update $(date +%Y-%m-%d)"
   git push -u origin HEAD
   gh pr create --title "Weekly publications update $(date +%Y-%m-%d)" \
     --body-file update_summary.md
   gh pr merge --auto --squash
   ```
   The PR auto-merges once the `validate` and `build` checks pass (data-only
   PRs need no human review; see `.github/CODEOWNERS`). Confirm within the
   hour that it merged and that https://ses-nau.org/research/ shows fresh
   numbers after the deploy.
4. **If it reported "No changes this week":** nothing else to do.
5. **If it ABORTED (guard failure or crash):** do **not** commit, do not
   retry more than once, and do not edit data by hand. Open an issue:
   ```bash
   gh issue create --title "Weekly update failed $(date +%Y-%m-%d)" \
     --body "<paste the abort message and the last ~30 lines of output>"
   ```
   Then stop. Nick (or a later supervised run) takes it from there.

## Notes

- The pipeline may only change `citations` and append rows. If a diff shows
  anything else changing, that is a bug: abort, revert, open an issue.
- A publication whose detail-fetch was throttled is skipped with a "deferred"
  note in the summary; it will be picked up automatically next week.
- New rows arrive with `verified=false`. Nick periodically reviews and
  verifies them (or asks Guy to propose corrections in a separate,
  reviewable PR).
- Fallback if `scholarly` breaks entirely: the retired R pipeline in
  `archive/` still contains the logic (see `archive/update_publications_2025.R`),
  but do not run it against Google Sheets; coordinate with Nick first.
