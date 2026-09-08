# Runbook: Monthly Student-Research News Story

**Who:** Guy Clawdsen (@guyclawdsen), acting as science reporter, once a month.
**What:** Find a recent graduate-student-led SES paper, interview the student
by email, write a short news story, and publish it on the site's News section
**as a PR that Nick reviews**. Never a direct commit; never published without
the student's explicit approval of their quotes.

## 1. Select the paper

Start from the weekly news-story suggestions emailed to Nick (step 6 of
`docs/RUNBOOK-weekly-update.md`) and from Nick's replies to them. Otherwise,
from `data/publications.csv`, find candidates where ALL hold:

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
- **CC Nick (nick.mckay2@gmail.com) on every message in the exchange.** (That
  address is where Guy-to-Nick traffic goes; students should still be given
  nick@nau.edu if they ask how to reach Nick directly.)
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

- **No byline.** Stories carry no `author` field and render none; the school
  is the sole credit line. Do not add an `author` key back to the frontmatter
  (the schema has no such field, so one would simply be ignored), and do not
  sign a story in the prose.
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

## 5. After it's live

Do not start this step until the story actually renders at
`https://ses-nau.org/news/<yyyy-mm>-<short-slug>/`. The deploy runs a few
minutes behind the merge, so fetch the URL and confirm you see the finished
story, not a 404 or a stale index. If it hasn't appeared within ~15 minutes,
check the Actions run before doing anything else.

**a. Thank the person you interviewed.** One short email, via `ses-send`
(Nick is CC'd automatically):

```bash
printf '%s\n' "..." | ses-send <their address> "Your story is live on the SES site"
```

Tell them it's published, give the full link, thank them for the time they
put into the interview, and say they're welcome to share it. Keep it to a few
sentences; no new questions, no requests.

**b. Draft social copy and send it to Donna.** SES posts on **LinkedIn,
Bluesky, Instagram, and Facebook**. Write one draft per platform in that
platform's own voice, following the social section of
`docs/news-style-guide.md`, and email all four to
**donna.shillington@nau.edu** (`ses-send` CCs Nick automatically):

```bash
printf '%s\n' "..." | ses-send donna.shillington@nau.edu \
  "Social drafts: <story title>"
```

- Label each draft with its platform, and keep them clearly separated so any
  one can be copied out on its own.
- **Every draft links back to the story** at
  `https://ses-nau.org/news/<yyyy-mm>-<short-slug>/`. On Instagram, where a
  caption link isn't clickable, still give the URL and note it needs to go in
  the bio or story.
- Say which image goes with each post, and include alt text for it. If the
  photo came from the person you interviewed, repeat the credit and confirm
  they cleared it for use.
- Draw only on the published story and the approved quotes. No new claims, no
  quotes that didn't survive approval, no superlatives the story doesn't
  support.
- Names, degrees, programs, emphases, titles, and affiliations come from
  `data/`, the published story, the site's own pages, or the person's own
  words. **A person approving a draft does not turn a detail you invented in
  that draft into a sourced fact**; if you wrote it first, it still needs a
  source. Program names in particular are easy to get almost right: check the
  exact wording rather than reconstructing it.
- Send Donna the copy and nothing else. Your own working notes (character
  counts, checklists, reasoning about the specs) stay out of the drafts.

**You draft; you do not post.** Guy has no social accounts and must not
create any. Donna decides what runs, when, and in what form.

## Boundaries

- Quote only what the student wrote or explicitly approved; never invent or
  embellish quotes.
- No personal details beyond name, program, advisor, and what they shared for
  publication.
- If the paper has embargoes or press restrictions (ask the student), respect
  them and check with Nick.
