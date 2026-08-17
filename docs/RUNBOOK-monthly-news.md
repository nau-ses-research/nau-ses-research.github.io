# Runbook: Monthly Student-Research News Story

**Who:** Guy Clawdsen (@guyclawdsen), acting as science reporter, once a month.
**What:** Find a recent graduate-student-led SES paper, interview the student
by email, write a short news story, and publish it on the site's News section
**as a PR that Nick reviews**. Never a direct commit; never published without
the student's explicit approval of their quotes.

## 1. Select the paper

From `data/publications.csv`, find candidates where ALL hold:

- `ses_grad_students` is non-empty AND the **first-listed author** matches one
  of those grad students (student-led, not just student-involved);
- recent: `date_added` within the last ~60 days (or `year` is the current
  year for papers added in a backfill);
- not already featured: its `id` appears in no `publication_id` frontmatter
  under `src/content/news/*/index.md`;
- prefer `verified=true` rows, papers in strong venues, and students who have
  not been featured before.

If no candidate qualifies, skip the month (tell Nick). If several qualify or
the choice feels ambiguous, email Nick the shortlist and let him pick.

## 2. Interview by email

- Find the student's email (NAU directory; ask Nick if not findable).
- **CC Nick (nick@nau.edu) on every message in the exchange.**
- First email: introduce yourself honestly as Guy Clawdsen, the AI assistant
  that helps run the SES website, invited by the school to feature their
  paper; say Nick is cc'd; ask the questions from
  `docs/interview-template.md` (pick 4–6, tailored to the paper).
- Iterate at most twice more (follow-ups, clarifications). Be gracious if the
  student declines; pick another candidate.
- Before publishing: send the student the exact quotes you plan to use (or
  the full draft) and get their **explicit OK in writing**. No OK, no story.

## 3. Write the story

- 400–700 words, following `docs/news-style-guide.md`.
- Create `src/content/news/<yyyy-mm>-<short-slug>/index.md`:

  ```yaml
  ---
  title: "..."
  date: 2026-09-15
  summary: "One-sentence dek for cards and RSS."
  publication_id: <id from data/publications.csv>
  students:
    - Full Name
  faculty:
    - Full Name
  ---
  ```

- Optional image: `featured.jpg` in the same folder (photo from the student,
  with their permission, or a relevant field/lab photo we have rights to).
- `npm run build` must pass locally (the page renders the linked paper
  automatically from `publication_id`).

## 4. Publish as a reviewed PR

```bash
git checkout main && git pull
git checkout -b news-<yyyy-mm>-<short-slug>
git add src/content/news/
git commit -m "Add news story: <title>"
git push -u origin HEAD
gh pr create --title "News: <title>" \
  --body "Monthly student-research spotlight. Student approved quotes on <date> (see email thread, Nick cc'd)."
```

The PR blocks on Nick's review (CODEOWNERS). After merge, confirm the story
is live at https://ses-nau.org/news/ and appears in the RSS feed.

## Boundaries

- Quote only what the student wrote or explicitly approved; never invent or
  embellish quotes.
- No personal details beyond name, program, advisor, and what they shared for
  publication.
- If the paper has embargoes or press restrictions (ask the student), respect
  them and check with Nick.
