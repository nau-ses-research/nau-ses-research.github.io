/**
 * Client-side publications explorer. Loads /data/publications.json once,
 * filters in memory, and mirrors filter state to the URL query string so
 * profile pages can deep-link (e.g. /publications/?faculty=D+Kaufman).
 */
import { useEffect, useMemo, useState } from "preact/hooks";

interface Pub {
  id: string;
  t: string; // title
  a: string; // authors
  j: string; // journal
  y: number | null; // year
  c: number; // citations
  f: string[]; // ses faculty labels
  g: string[]; // grad students
  u: string[]; // undergrads
  p: string; // scholar pubid
  d: string; // doi
}

interface Props {
  facultyOptions: { label: string; name: string }[];
  minYear: number;
  maxYear: number;
}

type SortKey = "year" | "citations";

function readParams() {
  const q = new URLSearchParams(window.location.search);
  return {
    search: q.get("q") ?? "",
    faculty: q.get("faculty") ?? "",
    students: q.get("students") === "1",
    from: q.get("from") ?? "",
    to: q.get("to") ?? "",
    sort: (q.get("sort") as SortKey) ?? "year",
  };
}

export default function PublicationExplorer({ facultyOptions, minYear, maxYear }: Props) {
  const [pubs, setPubs] = useState<Pub[] | null>(null);
  const [error, setError] = useState(false);
  const [search, setSearch] = useState("");
  const [faculty, setFaculty] = useState("");
  const [students, setStudents] = useState(false);
  const [from, setFrom] = useState("");
  const [to, setTo] = useState("");
  const [sort, setSort] = useState<SortKey>("year");
  const [limit, setLimit] = useState(50);

  useEffect(() => {
    const p = readParams();
    setSearch(p.search);
    setFaculty(p.faculty);
    setStudents(p.students);
    setFrom(p.from);
    setTo(p.to);
    setSort(p.sort === "citations" ? "citations" : "year");
    fetch("/data/publications.json")
      .then((r) => r.json())
      .then(setPubs)
      .catch(() => setError(true));
  }, []);

  // Mirror state to URL (replaceState: no history spam)
  useEffect(() => {
    if (pubs === null) return;
    const q = new URLSearchParams();
    if (search) q.set("q", search);
    if (faculty) q.set("faculty", faculty);
    if (students) q.set("students", "1");
    if (from) q.set("from", from);
    if (to) q.set("to", to);
    if (sort !== "year") q.set("sort", sort);
    const qs = q.toString();
    history.replaceState(null, "", qs ? `?${qs}` : window.location.pathname);
  }, [search, faculty, students, from, to, sort]);

  const filtered = useMemo(() => {
    if (!pubs) return [];
    const needle = search.trim().toLowerCase();
    const fromY = parseInt(from, 10) || minYear;
    const toY = parseInt(to, 10) || maxYear;
    const out = pubs.filter((p) => {
      if (p.y !== null && (p.y < fromY || p.y > toY)) return false;
      if (p.y === null && (from || to)) return false;
      if (faculty && !p.f.includes(faculty)) return false;
      if (students && p.g.length === 0 && p.u.length === 0) return false;
      if (needle) {
        const hay = `${p.t} ${p.a} ${p.j}`.toLowerCase();
        if (!hay.includes(needle)) return false;
      }
      return true;
    });
    out.sort(
      sort === "year"
        ? (a, b) => (b.y ?? 0) - (a.y ?? 0) || b.c - a.c
        : (a, b) => b.c - a.c || (b.y ?? 0) - (a.y ?? 0),
    );
    return out;
  }, [pubs, search, faculty, students, from, to, sort]);

  const totalCites = useMemo(
    () => filtered.reduce((s, p) => s + p.c, 0),
    [filtered],
  );

  if (error) {
    return <p class="py-12 text-center text-slate-500">Could not load the publication database.</p>;
  }
  if (pubs === null) {
    return <p class="py-12 text-center text-slate-400">Loading publications…</p>;
  }

  return (
    <div>
      <div class="rounded-xl border border-slate-200 bg-white p-4 shadow-sm">
        <div class="grid gap-3 md:grid-cols-[1fr_220px]">
          <input
            type="search"
            placeholder="Search titles, authors, journals…"
            value={search}
            onInput={(e) => setSearch((e.target as HTMLInputElement).value)}
            class="w-full rounded-lg border border-slate-300 px-3 py-2 focus:border-pine-500 focus:outline-none"
          />
          <select
            value={faculty}
            aria-label="Filter by faculty member"
            onChange={(e) => setFaculty((e.target as HTMLSelectElement).value)}
            class="rounded-lg border border-slate-300 px-3 py-2 focus:border-pine-500 focus:outline-none"
          >
            <option value="">All faculty</option>
            {facultyOptions.map((f) => (
              <option value={f.label}>{f.name}</option>
            ))}
          </select>
        </div>
        <div class="mt-3 flex flex-wrap items-center gap-x-5 gap-y-2 text-sm">
          <label class="flex items-center gap-1.5">
            <span class="text-slate-600">From</span>
            <input
              type="number"
              min={minYear}
              max={maxYear}
              placeholder={String(minYear)}
              value={from}
              onInput={(e) => setFrom((e.target as HTMLInputElement).value)}
              class="w-20 rounded-md border border-slate-300 px-2 py-1"
            />
          </label>
          <label class="flex items-center gap-1.5">
            <span class="text-slate-600">To</span>
            <input
              type="number"
              min={minYear}
              max={maxYear}
              placeholder={String(maxYear)}
              value={to}
              onInput={(e) => setTo((e.target as HTMLInputElement).value)}
              class="w-20 rounded-md border border-slate-300 px-2 py-1"
            />
          </label>
          <label class="flex items-center gap-1.5">
            <input
              type="checkbox"
              checked={students}
              onChange={(e) => setStudents((e.target as HTMLInputElement).checked)}
              class="h-4 w-4 accent-pine-700"
            />
            <span class="text-slate-600">Student authors only</span>
          </label>
          <label class="ml-auto flex items-center gap-1.5">
            <span class="text-slate-600">Sort by</span>
            <select
              value={sort}
              onChange={(e) => setSort((e.target as HTMLSelectElement).value as SortKey)}
              class="rounded-md border border-slate-300 px-2 py-1"
            >
              <option value="year">Newest</option>
              <option value="citations">Most cited</option>
            </select>
          </label>
        </div>
      </div>

      <p class="mt-4 text-sm text-slate-500">
        {filtered.length.toLocaleString()} publications · {totalCites.toLocaleString()} citations
        {faculty && <span> · {facultyOptions.find((f) => f.label === faculty)?.name ?? faculty}</span>}
      </p>

      <div class="mt-2">
        {filtered.slice(0, limit).map((p) => (
          <article key={p.id} id={p.id} class="border-b border-slate-100 py-4">
            <h3 class="font-medium text-slate-900">
              {p.d || p.p ? (
                <a
                  href={p.d ? `https://doi.org/${p.d}` : `https://scholar.google.com/citations?view_op=view_citation&citation_for_view=${p.p}`}
                  class="hover:text-pine-700 hover:underline"
                >
                  {p.t}
                </a>
              ) : (
                p.t
              )}
            </h3>
            <p class="mt-1 text-sm text-slate-600">{p.a}</p>
            <p class="mt-1 text-sm">
              <span class="italic text-slate-700">{p.j}</span>
              {p.y && <span class="text-slate-500"> · {p.y}</span>}
              {p.c > 0 && <span class="text-slate-500"> · {p.c.toLocaleString()} {p.c === 1 ? "citation" : "citations"}</span>}
            </p>
            {(p.g.length > 0 || p.u.length > 0) && (
              <p class="mt-1 text-xs text-pine-600">
                Student authors: {[...p.g, ...p.u].join(", ")}
              </p>
            )}
          </article>
        ))}
      </div>

      {filtered.length > limit && (
        <div class="py-6 text-center">
          <button
            onClick={() => setLimit(limit + 100)}
            class="rounded-lg border border-pine-300 px-5 py-2 text-sm font-medium text-pine-800 hover:bg-pine-50"
          >
            Show more ({(filtered.length - limit).toLocaleString()} remaining)
          </button>
        </div>
      )}
    </div>
  );
}
