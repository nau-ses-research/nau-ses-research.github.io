/**
 * Upcoming events from the public SES Google Calendar, fetched at build time.
 * The site rebuilds at least weekly (data PRs), which keeps this fresh enough
 * for a "next few events" strip. Fails soft: network trouble means an empty
 * list, never a broken build.
 */

const ICS_URL =
  "https://calendar.google.com/calendar/ical/nau.edu_acmpndn8fdcdf7dtebe6p26khg%40group.calendar.google.com/public/basic.ics";

export interface CalEvent {
  title: string;
  start: Date;
  allDay: boolean;
  location?: string;
}

function parseIcsDate(value: string): { date: Date; allDay: boolean } | null {
  // forms: 20260901T170000Z · 20260901T170000 (floating/local) · 20260901 (all-day)
  const m = value.match(/^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})(Z)?)?$/);
  if (!m) return null;
  const [, y, mo, d, h, mi, s, z] = m;
  if (!h) return { date: new Date(`${y}-${mo}-${d}T12:00:00-07:00`), allDay: true };
  if (z) return { date: new Date(`${y}-${mo}-${d}T${h}:${mi}:${s}Z`), allDay: false };
  // floating times on this calendar are Arizona local (no DST)
  return { date: new Date(`${y}-${mo}-${d}T${h}:${mi}:${s}-07:00`), allDay: false };
}

function unescapeIcs(v: string): string {
  return v.replace(/\\n/g, " ").replace(/\\([,;\\])/g, "$1").trim();
}

export async function getUpcomingEvents(limit = 3): Promise<CalEvent[]> {
  let text: string;
  try {
    const res = await fetch(ICS_URL, { signal: AbortSignal.timeout(15000) });
    if (!res.ok) return [];
    text = await res.text();
  } catch {
    return [];
  }
  // unfold continuation lines, then walk VEVENT blocks
  const lines = text.replace(/\r\n[ \t]/g, "").split(/\r?\n/);
  const events: CalEvent[] = [];
  let cur: Partial<CalEvent> | null = null;
  for (const line of lines) {
    if (line === "BEGIN:VEVENT") cur = {};
    else if (line === "END:VEVENT") {
      if (cur?.title && cur.start) events.push(cur as CalEvent);
      cur = null;
    } else if (cur) {
      const idx = line.indexOf(":");
      if (idx < 0) continue;
      const key = line.slice(0, idx).split(";")[0];
      const value = line.slice(idx + 1);
      if (key === "SUMMARY") cur.title = unescapeIcs(value);
      else if (key === "DTSTART") {
        const p = parseIcsDate(value.trim());
        if (p) {
          cur.start = p.date;
          cur.allDay = p.allDay;
        }
      } else if (key === "LOCATION" && value.trim()) cur.location = unescapeIcs(value);
    }
  }
  const now = Date.now();
  return events
    .filter((e) => e.start.getTime() > now - 12 * 3600 * 1000)
    .sort((a, b) => a.start.getTime() - b.start.getTime())
    .slice(0, limit);
}

export function fmtEventDate(e: CalEvent): string {
  const opts: Intl.DateTimeFormatOptions = e.allDay
    ? { month: "short", day: "numeric", timeZone: "America/Phoenix" }
    : { month: "short", day: "numeric", hour: "numeric", minute: "2-digit", timeZone: "America/Phoenix" };
  return e.start.toLocaleString("en-US", opts);
}
