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
- **not already asked about**: its `id` appears nowhere in Guy's interview
  register (`workspace/interview-register.tsv` on his machine, private because
  it holds personal addresses; this repo is public, so it is never copied
  here, not even as a bare list of ids, which would still say who was asked
  and imply who said no). If you are running this by hand rather than as Guy,
  read it over SSH (`cut -f1,2,7 ~/.openclaw-guy/workspace/interview-register.tsv`
  gives id, person and status) or ask Guy to run the check. Do not skip it. Every request ever made is in there as
  published, waiting or declined, and a paper listed in *any* of those states is
  finished business. A different paper by an author already in the register is
  still a fair candidate; note their earlier outcome when proposing it;
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
- **In the email's own prose, say "the School of Earth and Sustainability",
  not "NAU" or "Northern Arizona University".** guy@ses-nau.org is not a
  university address, and mail that brands itself with the university's name
  from a domain resembling `nau.edu` gets filtered as impersonation by exactly
  the mail systems our recipients use. This covers how you introduce yourself,
  frame what you are sending, and sign off.

  It does **not** cover material the email is *carrying* for publication
  somewhere else. A story draft sent for approval keeps the wording it will
  publish with, because that is the text the person is approving, and the
  social drafts in step 5b keep their intended branding, including the `#NAU`
  hashtag that `docs/news-style-guide.md` calls for on LinkedIn. Never weaken
  copy that is bound for the site or for social media to satisfy a mail-filter
  rule, and never edit a quote at all. The site keeps its NAU branding
  throughout; this is about the words you write as the sender.
- Iterate at most twice more (follow-ups, clarifications). Be gracious if the
  student declines; pick another candidate.
- **Add the register row as you send that first email**, not later: the paper's
  `publication_id`, the person, their address, the paper title, today's date,
  and `waiting`. The register is what stops this paper being proposed again, so
  a request that is never recorded will come back around.
- Iterate at most twice more (follow-ups, clarifications), updating
  `last_contact` in the register each time. Be gracious if the student
  declines: set their row to `declined`, say in the notes that it is closed,
  and pick another candidate. A decline is recorded so nobody asks again, and
  for no other purpose; do not carry the reason into anything public.
- Before publishing: send the student the exact quotes you plan to use (or
  the full draft) and get their **explicit OK in writing**. No OK, no story.
  In the same message, tell them that once the story is live it will also be
  submitted to the college blog (step 5c), along with their photo if they sent
  one, and ask them to say if they would rather it were not. If they object,
  skip 5c or use `--no-photo`, as they asked.

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
- Optional image: `featured.jpg` (or `.png`) in the same folder, picked up
  automatically; there is no `image:` frontmatter key. Use a photo from the
  student, with their permission, or a relevant field/lab photo we have
  rights to. Describe it in frontmatter:

  ```yaml
  image_alt: "What is literally visible, for screen readers."
  image_caption: "The sentence readers see under the photo."
  image_credit: "Photo courtesy of Full Name."
  ```

  `image_alt` describes the picture; `image_caption` says what it means to
  the story. Don't put the credit in either one.
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

**Close the register row first:** set the person's status to `published`, fill
in the story URL, and set `last_contact` to today. Everything below assumes
that is done.

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

**c. Submit the story to the CEFNS college blog.** The college collects
stories for its blog and email newsletters through a form at
https://in.nau.edu/college-environment-forestry-natural-sciences/blog/submit-post/.
Every published story goes there too, through
`scripts/submit_cefns_story.py`, never by filling the form by hand:

```bash
cd ~/ses-site && git pull
uv run scripts/submit_cefns_story.py <yyyy-mm>-<short-slug>            # dry run
uv run scripts/submit_cefns_story.py <yyyy-mm>-<short-slug> --submit
```

- **Dry run first, and read what it prints.** It shows every field exactly
  as it will be sent and saves a screenshot of the filled form. Nothing is
  uploaded or submitted.
- The script fills the form from the published story: the story text under
  its headline, the people, the paper, the photo with its caption and credit,
  and links to the story and the paper's DOI. It submits as Guy Clawdsen
  (guy@ses-nau.org), says plainly that Guy is the AI assistant that runs the
  SES site, and names Nick as the person to contact. Do not paste in extra
  text or rewrite the story for the form; the college does its own editing.
- **The story field holds 4,000 characters, headline included. If the story
  is longer, shorten it to 4,000 or fewer before submitting.** The script
  refuses an over-long story and tells you the count. Write the shortened
  version to `~/.openclaw-guy/workspace/cefns/<yyyy-mm>-<short-slug>.txt`
  (headline, blank line, then the text) and pass it with
  `--story-file <that path>`. Shorten by cutting and condensing:
  - Keep the headline, the opening paragraph's main finding, who did the work,
    and the closing "why it matters".
  - Cut background and methods detail first, then secondary numbers.
  - Every quote you keep stays word for word; drop a whole quote rather than
    trim one. The script checks every “quoted” passage against the published
    story and refuses a mismatch.
  - Add nothing that isn't in the published story, and leave out the
    "Paper:" line, since the citation already goes in its own field.
  - Aim for 3,500 to 3,900 characters, not far below; the college does its
    own editing and is better served by more of the story than less.
- `--submit` refuses to run until the story URL is live, and it only counts a
  submission as made when the form shows its confirmation message. If the
  form rejects it, the script prints the form's errors and records nothing;
  fix the cause and run it again.
- Each submission is logged in `~/.local/state/ses/cefns-submissions.tsv`. A
  story already in that ledger is refused, so a rerun cannot send it twice.
  Use `--force` only if the college asks for it again.
- If the person you interviewed asked you to leave out their photo or not to
  share the story beyond the SES site (step 2), honor that: `--no-photo`, or
  skip this step.
- The form uses a JavaScript spam check, which is why the script drives a
  real headless browser. If the form's layout changes and a field can't be
  found, stop and tell Nick rather than working around it.

Send Nick a one-line note once it has gone through. The college's reply, if
any, arrives in Guy's inbox like any other mail.

## Boundaries

- Quote only what the student wrote or explicitly approved; never invent or
  embellish quotes.
- No personal details beyond name, program, advisor, and what they shared for
  publication.
- If the paper has embargoes or press restrictions (ask the student), respect
  them and check with Nick.
