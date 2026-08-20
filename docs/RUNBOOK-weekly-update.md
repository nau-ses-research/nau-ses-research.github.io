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
   A normal week takes 5–15 minutes; a backlog/catch-up run takes
   **20–40 minutes**. Google Scholar is contacted only for the ~40 profile
   pages (discovery + citation counts); per-paper metadata comes from
   Crossref/OpenAlex, which are batch-friendly. Papers those APIs haven't
   indexed yet are deferred to the next run automatically. The pipeline
   aborts by itself (writing nothing) if Scholar looks blocked or the
   numbers look wrong, and every network call has a hard timeout, so it can
   never hang.

   **If your execution environment kills long commands** (agent tool
   timeouts, flaky sessions), run it detached and follow the log instead:

   ```bash
   nohup uv run scripts/update_publications.py --summary-file update_summary.md \
     > update_run.log 2>&1 &
   tail -f update_run.log   # or poll it; the process survives your session
   ```

   The summary file is written twice: a PRELIMINARY version as soon as the
   profile fetch and citation pass finish, and the final version at the end,
   so even an interrupted run leaves usable counts. Progress lines
   (`[N/M candidates processed]`) show where a long run is.

   **Never run two instances at once.** The pipeline refuses to start if
   another instance holds the run lock; if you see that abort, tail the
   existing run's log instead of retrying. A slow run is normal.

   If Scholar blocks mid-run (repeated fetch errors, abort on the
   success-rate guard): **wait at least 3–6 hours before retrying**; repeated
   immediate retries extend the block. geckodriver/Firefox version warnings
   from scholarly are harmless noise; they matter only if every single fetch
   fails even after a wait.
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
