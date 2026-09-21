import { defineCollection, z } from "astro:content";
import { glob } from "astro/loaders";

/** "darrell-kaufman/index.md" -> id "darrell-kaufman" */
const bundleId = ({ entry }: { entry: string }) => entry.replace(/\/index\.md$/, "");

const profileSchema = z.object({
  name: z.string(),
  last_name: z.string(),
  title: z.string().optional(), // academic title, e.g. "Regents' Professor"
  summary: z.string().optional(),
  interests: z.array(z.string()).default([]),
  image_caption: z.string().optional(),
  email: z.string().email().optional(),
  weight: z.number().default(0),
});

const faculty = defineCollection({
  loader: glob({ pattern: "*/index.md", base: "./src/content/faculty", generateId: bundleId }),
  schema: profileSchema,
});

const archivedFaculty = defineCollection({
  loader: glob({ pattern: "*/index.md", base: "./src/content/archived-faculty", generateId: bundleId }),
  schema: profileSchema,
});

const themes = defineCollection({
  loader: glob({ pattern: "*/index.md", base: "./src/content/themes", generateId: bundleId }),
  schema: z.object({
    title: z.string(),
    summary: z.string(),
    icon: z.string().optional(), // name of an icon in src/components/icons.ts
    interests: z.array(z.string()).default([]),
    image_caption: z.string().optional(),
    weight: z.number().default(0),
  }),
});

const opportunities = defineCollection({
  loader: glob({ pattern: "**/index.md", base: "./src/content/opportunities", generateId: bundleId }),
  schema: z.object({
    title: z.string(),
    nav_title: z.string().optional(), // short name for menus/cards
    summary: z.string(),
    image_caption: z.string().optional(),
    weight: z.number().default(0),
    // Recruitment videos rendered above the page body
    videos: z
      .array(z.object({ title: z.string(), youtube_id: z.string() }))
      .default([]),
  }),
});

const news = defineCollection({
  loader: glob({ pattern: "*/index.md", base: "./src/content/news", generateId: bundleId }),
  schema: z.object({
    title: z.string(),
    date: z.coerce.date(),
    summary: z.string(),
    publication_id: z.string().optional(), // id in data/publications.csv
    students: z.array(z.string()).default([]),
    faculty: z.array(z.string()).default([]),
    image_caption: z.string().optional(),
    image_alt: z.string().optional(), // describes the photo; falls back to image_caption
    image_credit: z.string().optional(),
  }),
});

/** Faculty recruiting graduate students in a given cycle. One file per advisor,
 *  named for their slug in the faculty collection. Frontmatter drives the cards
 *  and the filters; the body, when present, is the full position description. */
const advisors = defineCollection({
  loader: glob({ pattern: "*.md", base: "./src/content/advisors" }),
  schema: z.object({
    faculty: z.string(), // slug in the faculty collection
    cycle: z.string().default("2027/28"),
    programs: z.array(z.enum(["geosciences-ms", "esp-ms", "eses-phd"])).min(1),
    seeking: z.string().optional(), // how many students, as the advisor put it
    summary: z.string(), // what they are recruiting for, in their own words
    contact: z.string().email().optional(),
    links: z
      .array(z.object({ label: z.string(), url: z.string().url() }))
      .default([]),
    apply_by: z.string().optional(),
    details_pending: z.boolean().default(false), // said yes, description still to come
  }),
});

const gradResources = defineCollection({
  loader: glob({ pattern: "*.md", base: "./src/content/grad-resources" }),
  schema: z.object({
    title: z.string(),
    nav_title: z.string(), // short label for menus/cards
    summary: z.string(),
    weight: z.number().default(0),
  }),
});

const pages = defineCollection({
  loader: glob({ pattern: "*.md", base: "./src/content/pages" }),
  schema: z.object({
    title: z.string(),
    summary: z.string().optional(),
  }),
});

export const collections = {
  advisors, faculty, archivedFaculty, themes, opportunities, news, gradResources, pages };
