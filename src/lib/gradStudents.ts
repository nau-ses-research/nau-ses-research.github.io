/**
 * Typed access to data/grad_students.csv, which scripts/update_grad_students.py
 * rebuilds from the SES Marketing folder. Never hand-edit that file.
 */
import { parse } from "csv-parse/sync";
import { readFileSync } from "node:fs";
import { getFacultyRecords } from "./publications";

export interface Advisor {
  name: string; // surname as written in the source
  href?: string; // faculty profile, when we have one
}

export interface GradStudent {
  slug: string;
  first: string;
  last: string;
  full_name: string;
  program: string; // phd | glg | esp | css
  program_label: string;
  degree: string;
  advisors: Advisor[];
  email: string;
  council_rep: boolean;
  cohort: string;
  has_photo: boolean;
  initials: string;
}

/** Display order: research degrees first, then the professional master's. */
export const PROGRAM_ORDER = ["phd", "glg", "esp", "css"] as const;

let _students: GradStudent[] | null = null;

export function getGradStudents(): GradStudent[] {
  if (_students) return _students;

  // Advisors appear as bare surnames ("Souther", "Stuart/Radonic"), so resolve
  // them against faculty.csv rather than storing a link in the directory data.
  const faculty = getFacultyRecords();
  const bySurname = new Map<string, { slug: string; profile: string }>();
  for (const f of faculty) {
    bySurname.set(f.last_name.toLowerCase(), { slug: f.slug, profile: f.profile });
  }

  const rows: Record<string, string>[] = parse(
    readFileSync("data/grad_students.csv", "utf-8"),
    { columns: true },
  );

  _students = rows.map((r) => ({
    slug: r.slug,
    first: r.first,
    last: r.last,
    full_name: r.full_name,
    program: r.program,
    program_label: r.program_label,
    degree: r.degree,
    advisors: (r.advisor ? r.advisor.split("/") : [])
      .map((name) => name.trim())
      .filter(Boolean)
      .map((name) => {
        const hit = bySurname.get(name.toLowerCase());
        if (!hit) return { name };
        if (hit.profile === "current") return { name, href: `/faculty-profiles/${hit.slug}/` };
        if (hit.profile === "archived") return { name, href: `/archived-profiles/${hit.slug}/` };
        return { name };
      }),
    email: r.email,
    council_rep: r.council_rep === "true",
    cohort: r.cohort,
    has_photo: r.has_photo === "true",
    initials: (r.first[0] ?? "") + (r.last[0] ?? ""),
  }));
  return _students;
}

export function gradStudentsByProgram(): { code: string; label: string; students: GradStudent[] }[] {
  const all = getGradStudents();
  return PROGRAM_ORDER.map((code) => {
    const students = all.filter((s) => s.program === code);
    return { code, label: students[0]?.program_label ?? code, students };
  }).filter((g) => g.students.length > 0);
}
