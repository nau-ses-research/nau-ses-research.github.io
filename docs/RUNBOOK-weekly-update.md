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
   git add data/publications.csv data/deferred.csv
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
4. **If it reported "No changes this week":** usually nothing else to do,
   but if `git status` shows `data/deferred.csv` changed (deferral counts
   advanced), commit and PR just that file the same way; it auto-merges
   like any data-only PR. Never leave a modified tracked file uncommitted,
   or next week's `git pull` will conflict.
5. **If it ABORTED (guard failure or crash):** do **not** commit, do not
   retry more than once, and do not edit data by hand. Open an issue:
   ```bash
   gh issue create --title "Weekly update failed $(date +%Y-%m-%d)" \
     --body "<paste the abort message and the last ~30 lines of output>"
   ```
   Then stop. Nick (or a later supervised run) takes it from there.

6. **Suggest a news story** (after a successful run from step 3 that added
   new publications; skip entirely after step 4 or 5).
   Once the data PR is open, look at the new rows from *this* run whose
   `year` is the current year (a backfilled older paper is not news). If
   there are none, do nothing: no email, no "nothing this week" note.

   Rank the candidates by these criteria, in order:

   1. **Student lead author.** The first-listed author matches a person in
      `data/students.csv` (grad or undergrad, current or recent alumni), or
      matches a name in the row's `ses_grad_students`. **Report every one of
      these**, even if there are several: Nick wants to know about all
      student-led papers, and expects to write stories about most of them.
   2. **SES faculty first author, high-profile journal.**
   3. **SES faculty first author**, any other journal.
   4. **SES coauthorship on a high-profile paper**: an SES person is on the
      author list but is *not* the first author.

   Skip anything that is not a research paper: conference abstracts, posters,
   datasets, corrections, and program documents such as IODP prospectuses and
   cruise reports. If the row would be parked in `data/deferred.csv`, it is
   not a story.

   Two rules are deliberate; don't re-raise them each week. Only *first*
   authorship makes a paper student-led (a student in the middle of an author
   list does not), and only current-year papers are candidates (a
   late-indexed older paper is catalog work, not news).

   If two papers tie on criterion, prefer the one where the SES person is
   first or last author over a middle author, then the one with the clearer
   hook for a general reader, then the one whose SES authors have not been
   featured on the site recently.

   Treat as high-profile: *Nature*, *Science*, *PNAS*, and the Nature- and
   Science-family journals (*Nature Geoscience*, *Nature Climate Change*,
   *Nature Communications*, *Science Advances*, and similar), plus the
   flagship journal of the paper's own field. If a call is borderline, say so
   in the email rather than deciding silently.

   Email Nick **one** message with the student-led papers (all of them) plus
   **a single best suggestion** from tiers 2–4 if any exist:

   ```bash
   printf '%s\n' "..." | ses-send nick.mckay2@gmail.com \
     "News story suggestion, week of $(date +%Y-%m-%d)"
   ```

   For each paper give: title, authors as listed (mark the SES people), journal,
   DOI, the `id` from `data/publications.csv`, which criterion it met, and one or
   two sentences on why it would make a good story. Skip any paper whose `id`
   already appears as `publication_id` in `src/content/news/*/index.md`.

   This is a suggestion only. Do not contact students or authors, and do not
   start drafting; Nick picks, and the story itself then follows
   `docs/RUNBOOK-monthly-news.md`.

## Notes

- The pipeline may only change `citations` and append rows. If a diff shows
  anything else changing, that is a bug: abort, revert, open an issue.
- A publication whose detail-fetch was throttled is skipped with a "deferred"
  note in the summary; it will be picked up automatically next week. If it
  still can't be resolved after 3 runs it is **parked** in
  `data/deferred.csv` and never retried (these are abstracts, datasets, and
  posters that Crossref/OpenAlex will never index). A human can unpark one
  by deleting its row.
- New rows arrive with `verified=false`. Nick periodically reviews and
  verifies them (or asks Guy to propose corrections in a separate,
  reviewable PR).
- Fallback if `scholarly` breaks entirely: the retired R pipeline in
  `archive/` still contains the logic (see `archive/update_publications_2025.R`),
  but do not run it against Google Sheets; coordinate with Nick first.
