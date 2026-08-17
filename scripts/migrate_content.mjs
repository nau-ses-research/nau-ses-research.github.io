#!/usr/bin/env node
/**
 * One-time migration of Hugo/Blox content into Astro content collections.
 * Run from the repo root on the astro-rebuild branch:
 *     node scripts/migrate_content.mjs
 *
 * Maps Blox frontmatter to the zod schemas in src/content.config.ts, converts
 * {{< figure >}} shortcodes to markdown, copies page-bundle images, and drops
 * the Blox publication-template boilerplate. Idempotent: wipes and rewrites
 * the destination collections each run.
 */

import fs from "node:fs";
import path from "node:path";
import matter from "gray-matter";

const OUT = "src/content";

function readMd(file) {
  const { data, content } = matter(fs.readFileSync(file, "utf-8"));
  return { fm: data, body: content.trim() };
}

function convertShortcodes(body) {
  // {{< figure src="b.jpeg" caption="..." class="..." >}} -> markdown image + caption
  return body.replace(
    /\{\{<\s*figure\s+([^>]*)>\}\}/g,
    (_, attrs) => {
      const get = (k) => (attrs.match(new RegExp(`${k}="([^"]*)"`)) || [])[1] ?? "";
      const src = get("src");
      const caption = get("caption");
      return caption ? `![${caption}](${src})\n*${caption}*` : `![](${src})`;
    },
  );
}

function writePage(destDir, fm, body) {
  fs.mkdirSync(destDir, { recursive: true });
  const yaml = matter.stringify("\n" + body + "\n", fm);
  fs.writeFileSync(path.join(destDir, "index.md"), yaml);
}

function copyImages(srcDir, destDir) {
  for (const f of fs.readdirSync(srcDir)) {
    if (/\.(jpe?g|png|webp|gif)$/i.test(f)) {
      fs.copyFileSync(path.join(srcDir, f), path.join(destDir, f));
    }
  }
}

function migrateProfiles(srcRoot, destRoot) {
  fs.rmSync(destRoot, { recursive: true, force: true });
  let n = 0;
  for (const slug of fs.readdirSync(srcRoot)) {
    const dir = path.join(srcRoot, slug);
    const md = path.join(dir, "index.md");
    if (!fs.existsSync(md)) continue;
    const { fm, body } = readMd(md);
    const dest = path.join(destRoot, slug);
    writePage(dest, {
      name: fm.title,
      last_name: fm.last_name ?? fm.title.split(" ").at(-1),
      summary: fm.summary ?? fm.abstract ?? "",
      interests: fm.tags ?? [],
      ...(fm.image?.caption ? { image_caption: fm.image.caption } : {}),
    }, convertShortcodes(body));
    copyImages(dir, dest);
    n++;
  }
  console.log(`${destRoot}: ${n} profiles`);
}

function migrateThemes() {
  const srcRoot = "content/research-themes";
  const destRoot = `${OUT}/themes`;
  fs.rmSync(destRoot, { recursive: true, force: true });
  let n = 0;
  for (const slug of fs.readdirSync(srcRoot)) {
    const dir = path.join(srcRoot, slug);
    const md = path.join(dir, "index.md");
    if (!fs.existsSync(md)) continue;
    const { fm, body } = readMd(md);
    const dest = path.join(destRoot, slug);
    writePage(dest, {
      title: fm.title,
      summary: fm.summary ?? "",
      interests: fm.tags ?? [],
      ...(fm.image?.caption ? { image_caption: fm.image.caption } : {}),
    }, convertShortcodes(body));
    copyImages(dir, dest);
    n++;
  }
  console.log(`${destRoot}: ${n} themes`);
}

function migrateOpportunities() {
  const srcRoot = "content/student-opportunities";
  const destRoot = `${OUT}/opportunities`;
  fs.rmSync(destRoot, { recursive: true, force: true });
  let n = 0;
  const weights = {
    "undergraduate-degrees": 10,
    "graduate-degrees": 20,
    "professional-certificates": 30,
    "graduate-certificates": 40,
    "undergraduate-certificates": 50,
    "sisk-fellowship": 60,
  };
  // Page bundles (the nav-linked pages)
  for (const slug of fs.readdirSync(srcRoot)) {
    const dir = path.join(srcRoot, slug);
    if (!fs.statSync(dir).isDirectory()) continue;
    const md = path.join(dir, "index.md");
    if (!fs.existsSync(md)) continue;
    const { fm, body } = readMd(md);
    const dest = path.join(destRoot, slug);
    writePage(dest, {
      title: fm.title,
      summary: fm.summary ?? "",
      weight: weights[slug] ?? 90,
      ...(fm.image?.caption ? { image_caption: fm.image.caption } : {}),
    }, convertShortcodes(body));
    copyImages(dir, dest);
    n++;
  }
  // Loose program pages (geology-ms.md etc.), linked from the degree pages
  for (const f of fs.readdirSync(srcRoot)) {
    if (!f.endsWith(".md") || f === "_index.md") continue;
    const slug = f.replace(/\.md$/, "");
    const { fm, body } = readMd(path.join(srcRoot, f));
    writePage(path.join(destRoot, slug), {
      title: fm.title,
      summary: fm.summary ?? "",
      weight: 100,
    }, convertShortcodes(body));
    n++;
  }
  console.log(`${destRoot}: ${n} pages`);
}

migrateProfiles("content/faculty-profiles", `${OUT}/faculty`);
migrateProfiles("content/archived-profiles", `${OUT}/archived-faculty`);
migrateThemes();
migrateOpportunities();
fs.mkdirSync(`${OUT}/news`, { recursive: true });
fs.mkdirSync(`${OUT}/pages`, { recursive: true });
console.log("Done.");
