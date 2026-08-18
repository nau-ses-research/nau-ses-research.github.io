# Content Registry

Every page's freshness has an owner and a review cadence. Guy Clawdsen checks
this table **quarterly** (Jan / Apr / Jul / Oct): for each row past its review
date, verify the page against its source of truth and open ONE GitHub issue
listing everything that needs human eyes. Update `last_reviewed` in the same
PR as any fix.

Derived content (publication lists, stats, theme rosters, homepage pulse)
regenerates from `data/` at every build and is not registered here; keeping
`data/faculty.csv` current IS the review for those.

| Page / area | Source of truth | Owner | Cadence | Last reviewed |
|---|---|---|---|---|
| Faculty profiles (`src/content/faculty/`) | Each faculty member | Nick | Yearly (fall) | 2026-08 |
| Research theme prose (`src/content/themes/`) | Theme faculty | Nick | Yearly | 2026-08 |
| Program pages (`src/content/opportunities/`) | Program advisors / catalog | Nick | Yearly (spring, before catalog) | 2026-08 |
| Grad resources (`src/content/grad-resources/`) | sesgrad Google Site, handbooks | Rebecca Best / Tracy Tiedemann via Nick | Yearly (Aug) + AGENTS.md checklist | 2026-08 |
| Handbook / Program of Study links | OGPS + Rebecca's Drive | Tracy Tiedemann via Nick | Yearly (Aug) | 2026-08 |
| Grad Student Council roster | Council | Guy proposes, Nick reviews | Yearly (fall) | 2026-08 |
| Seminar schedules & times | Department listservs | Guy proposes | Each semester | 2026-08 |
| Alumni page | Clare Aslan / alumni network | Nick | Yearly | 2026-08 |
| Announcement banner | Recruitment calendar | Guy proposes, Nick approves | Each semester | 2026-08 |
| Contact info / footer | Front office | Nick | Yearly | 2026-08 |
| Homepage copy | School leadership | Nick | Yearly | 2026-08 |
| `data/faculty.csv` (roster, themes, active flags) | Department roster | Nick | Each semester | 2026-08 |
| `data/students.csv` | Grad program roster | Tracy via Nick | Yearly (fall) | 2026-08 |
