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
    author: z.string().default("Guy Clawdsen"),
  }),
});

const pages = defineCollection({
  loader: glob({ pattern: "*.md", base: "./src/content/pages" }),
  schema: z.object({
    title: z.string(),
    summary: z.string().optional(),
  }),
});

export const collections = { faculty, archivedFaculty, themes, opportunities, news, pages };
