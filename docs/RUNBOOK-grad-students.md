# Runbook: Graduate Student Directory

**Who:** Guy Clawdsen (@guyclawdsen). Nick can run it too.
**What:** Rebuild `/graduate-students/` from the SES Marketing folder.
**When:** Whenever the source changes. In practice that means each semester as
students arrive and leave, when a new portrait lands, and when Nick says so.
There is no schedule: run it on request or when you notice the mirror has
changed.

## The source of truth is not this repo

Everything on that page comes from OneDrive:

```
SES - Marketing/Grad_Student_Info_4Web/
  Current list of SES Grad Students contact info.xlsx   (4 sheets: ESP, GLG, PhD, CSS)
  Grad_Student_Photos/                                   (Last,First.PROGRAM.jpg)
```

which reaches your machine as the read-only mirror described in your AGENTS.md
(`ses-drive`). **Never hand-edit `data/grad_students.csv` or the portraits.**
Anything you change there is overwritten the next time this runs. If something
is wrong, the fix belongs in the spreadsheet or the photo filename, and that is
Nick's to make or to ask for.

## Steps

1. **Check the mirror is current**, since it only updates when Nick's Mac is on:
   ```bash
   ses-drive status
   ```
   If the last sync is days old, or the folder is empty, tell Nick and stop.
2. **Sync and run:**
   ```bash
   git checkout main && git pull
   uv run scripts/update_grad_students.py --summary-file grad_summary.md
   ```
   It reads the mirror, rewrites `data/grad_students.csv`, regenerates the
   portraits in `src/assets/grad-students/`, and prints a summary. A `--dry-run`
   flag reports without writing anything.
3. **Read the "Needs a human eye" section of the summary.** It lists photos that
   match nobody on the sheets, filenames in the wrong order, surnames it matched
   despite a spelling difference, and students with no email. These are not
   failures; they are things only a person can settle. Carry them into the PR
   description so Nick sees them.
4. **Check and open a PR:**
   ```bash
   python3 scripts/validate_data.py
   npm run build
   git checkout -b grad-students-$(date +%Y-%m-%d)
   git add data/grad_students.csv src/assets/grad-students
   git commit -m "Refresh the graduate student directory"
   git push -u origin HEAD
   gh pr create --title "Refresh the graduate student directory" --body-file grad_summary.md
   ```
   **This PR needs Nick's review; do not auto-merge it.** It publishes named
   students' photographs and email addresses, which is not a data-only change
   however much it looks like one.

## If it aborts

The script refuses to write rather than produce a half-right directory. It
aborts when the folder is missing, when a sheet has been renamed or added, when
fewer than 20 students parse, or when two students slugify to the same name.
Each message says what it found. Do not work around an abort by editing the
generated files: report it to Nick with the message.

## Notes

- Portraits are resized to 900px and stripped of EXIF, so camera GPS does not
  ship with a student's photograph.
- A student with no photo renders as their initials. That is expected: only
  about half have supplied one.
- The Leaders column in the spreadsheet marks this year's grad student council
  representatives, which the page shows as a badge. If the year changes, the
  badge text in `src/pages/graduate-students/index.astro` needs updating too.
- Students are not in `data/students.csv`; that file is the publication-matching
  roster and covers everyone historical. These are two different lists with two
  different jobs.
