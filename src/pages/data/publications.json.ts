/**
 * Trimmed publication dataset consumed by the explorer island.
 * ~1,100 records; regenerated at every build from data/publications.csv.
 */
import type { APIRoute } from "astro";
import { getPublications } from "../../lib/publications";

export const GET: APIRoute = () => {
  const pubs = getPublications().map((p) => ({
    id: p.id,
    t: p.title,
    a: p.authors,
    j: p.journal,
    y: p.year,
    c: p.citations,
    f: p.ses_faculty,
    g: p.ses_grad_students,
    u: p.ses_undergrad_students,
    p: p.pubid,
  }));
  return new Response(JSON.stringify(pubs), {
    headers: { "Content-Type": "application/json" },
  });
};
