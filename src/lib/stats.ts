/**
 * Build-time aggregates for the research-impact dashboard.
 * Ports the stat definitions from archive/R/generate_website_stats.R exactly:
 * the universe is publications with year >= 2009 and include_in_reports=true.
 */
import { getPublications, type Publication } from "./publications";

/**
 * Excluded from the time-series CHARTS only (never from tables, lists,
 * or headline totals): mega-cited IPCC syntheses whose citation counts
 * swamp the y-axis and hide every other year's signal.
 */
export const CHART_EXCLUDED_IDS = new Set([
  "technicalsummary-2021", // IPCC AR6 WG1 Technical Summary (23k+ citations)
  "intergovernmentalpanelonclimatechangeipc-2023", // IPCC AR6 SYR SPM
]);

export interface YearSeries {
  year: number;
  faculty: number; // pubs with >=1 SES faculty author
  grad: number; // pubs with >=1 SES grad-student author
  citations: number; // citations to faculty pubs of that year
}

export interface SiteStats {
  totalFacultyPubs: number;
  totalCitations: number;
  hIndex: number;
  totalGradPubs: number;
  totalGradStudents: number;
  gradCitations: number;
  uniqueJournals: number;
  lastYear: number;
  facultyLastYear: number;
  studentLastYear: number; // grad + undergrad papers last year
  activelyPublishingCount: number;
  topJournals: { journal: string; count: number }[];
  byYear: YearSeries[];
}

export function reportUniverse(): Publication[] {
  return getPublications().filter((p) => p.year !== null && p.year >= 2009);
}

let _stats: SiteStats | null = null;

export function getStats(): SiteStats {
  if (_stats) return _stats;
  const pubs = reportUniverse();
  const facultyPubs = pubs.filter((p) => p.ses_faculty.length > 0);
  const gradPubs = pubs.filter((p) => p.ses_grad_students.length > 0);

  const cites = facultyPubs.map((p) => p.citations).sort((a, b) => b - a);
  let h = 0;
  while (h < cites.length && cites[h] >= h + 1) h++;

  const gradStudents = new Set(gradPubs.flatMap((p) => p.ses_grad_students));

  const now = new Date().getFullYear();
  const lastYear = now - 1;
  const lastYearPubs = pubs.filter((p) => p.year === lastYear);

  const activeFaculty = new Set(
    pubs
      .filter((p) => p.year! >= now - 2)
      .flatMap((p) => p.ses_faculty),
  );

  const journalCounts = new Map<string, number>();
  for (const p of pubs) {
    if (p.journal) journalCounts.set(p.journal, (journalCounts.get(p.journal) ?? 0) + 1);
  }
  const topJournals = [...journalCounts.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, 8)
    .map(([journal, count]) => ({ journal, count }));

  const years = new Map<number, YearSeries>();
  for (let y = 2009; y <= now; y++) {
    years.set(y, { year: y, faculty: 0, grad: 0, citations: 0 });
  }
  for (const p of pubs) {
    const s = years.get(p.year!);
    if (!s || CHART_EXCLUDED_IDS.has(p.id)) continue;
    if (p.ses_faculty.length > 0) {
      s.faculty++;
      s.citations += p.citations;
    }
    if (p.ses_grad_students.length > 0) s.grad++;
  }

  _stats = {
    totalFacultyPubs: facultyPubs.length,
    totalCitations: facultyPubs.reduce((a, p) => a + p.citations, 0),
    hIndex: h,
    totalGradPubs: gradPubs.length,
    totalGradStudents: gradStudents.size,
    gradCitations: gradPubs.reduce((a, p) => a + p.citations, 0),
    uniqueJournals: journalCounts.size,
    lastYear,
    facultyLastYear: lastYearPubs.filter((p) => p.ses_faculty.length > 0).length,
    studentLastYear:
      lastYearPubs.filter((p) => p.ses_grad_students.length > 0).length +
      lastYearPubs.filter((p) => p.ses_undergrad_students.length > 0).length,
    activelyPublishingCount: activeFaculty.size,
    topJournals,
    byYear: [...years.values()],
  };
  return _stats;
}

export const fmt = (n: number) => n.toLocaleString("en-US");
