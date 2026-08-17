/**
 * Typed access to the data/ CSVs (the system of record; see data/README.md).
 * Parsed once at build time and cached module-level.
 */
import { parse } from "csv-parse/sync";
import { readFileSync } from "node:fs";

export interface Publication {
  id: string;
  title: string;
  authors: string;
  journal: string;
  number: string;
  year: number | null;
  citations: number;
  ses_faculty: string[];
  ses_grad_students: string[];
  ses_undergrad_students: string[];
  verified: boolean;
  include_in_reports: boolean;
  pubid: string;
  date_added: string;
}

export interface FacultyRecord {
  slug: string;
  first_initial: string;
  first_name: string;
  last_name: string;
  scholar_id: string;
  active: boolean;
  profile: "current" | "archived" | "none";
  label: string; // "D Kaufman" — matches ses_faculty entries
}

function csv(path: string): Record<string, string>[] {
  return parse(readFileSync(path, "utf-8"), { columns: true });
}

function splitMulti(v: string): string[] {
  return v ? v.split("; ").filter(Boolean) : [];
}

let _pubs: Publication[] | null = null;

/** All publications marked include_in_reports, newest first. */
export function getPublications(): Publication[] {
  if (_pubs) return _pubs;
  _pubs = csv("data/publications.csv")
    .map((r) => ({
      id: r.id,
      title: r.title,
      authors: r.authors,
      journal: r.journal,
      number: r.number,
      year: r.year ? parseInt(r.year, 10) : null,
      citations: parseInt(r.citations, 10) || 0,
      ses_faculty: splitMulti(r.ses_faculty),
      ses_grad_students: splitMulti(r.ses_grad_students),
      ses_undergrad_students: splitMulti(r.ses_undergrad_students),
      verified: r.verified === "true",
      include_in_reports: r.include_in_reports === "true",
      pubid: r.pubid,
      date_added: r.date_added,
    }))
    .filter((p) => p.include_in_reports);
  return _pubs;
}

let _faculty: FacultyRecord[] | null = null;

export function getFacultyRecords(): FacultyRecord[] {
  if (_faculty) return _faculty;
  _faculty = csv("data/faculty.csv").map((r) => ({
    slug: r.slug,
    first_initial: r.first_initial,
    first_name: r.first_name,
    last_name: r.last_name,
    scholar_id: r.scholar_id,
    active: r.active === "true",
    profile: r.profile as FacultyRecord["profile"],
    label: `${r.first_initial} ${r.last_name}`,
  }));
  return _faculty;
}

/** Publications co-authored by the faculty member with this label. */
export function publicationsByFaculty(label: string): Publication[] {
  return getPublications().filter((p) => p.ses_faculty.includes(label));
}

/** Map profile slug -> faculty record (for profile pages). */
export function facultyBySlug(slug: string): FacultyRecord | undefined {
  return getFacultyRecords().find((r) => r.slug === slug);
}
