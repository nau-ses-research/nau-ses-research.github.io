#!/usr/bin/env node
/**
 * Internal link checker for the built site. Run after `npm run build`:
 *     node scripts/check_links.mjs
 * Walks every HTML file in dist/, collects internal hrefs/srcs, and fails
 * if any points at a page or asset that the build did not produce.
 * External URLs are not checked (deterministic CI beats flaky CI).
 */

import fs from "node:fs";
import path from "node:path";

const DIST = "dist";
const htmlFiles = [];
(function walk(dir) {
  for (const f of fs.readdirSync(dir)) {
    const p = path.join(dir, f);
    if (fs.statSync(p).isDirectory()) walk(p);
    else if (f.endsWith(".html")) htmlFiles.push(p);
  }
})(DIST);

const exists = (url) => {
  const clean = url.split("#")[0].split("?")[0];
  if (!clean || clean === "/") return true;
  const p = path.join(DIST, clean);
  return (
    fs.existsSync(p) ||
    fs.existsSync(path.join(p, "index.html")) ||
    fs.existsSync(p + ".html")
  );
};

let errors = 0;
for (const file of htmlFiles) {
  const html = fs.readFileSync(file, "utf-8");
  const refs = [...html.matchAll(/(?:href|src)="(\/[^"]*)"/g)].map((m) => m[1]);
  for (const ref of new Set(refs)) {
    if (ref.startsWith("//")) continue; // protocol-relative external
    if (ref.startsWith("/pagefind/")) continue; // generated post-build by pagefind
    if (!exists(ref)) {
      console.error(`BROKEN: ${ref}  (in ${file})`);
      errors++;
    }
  }
}
console.log(`${htmlFiles.length} pages checked, ${errors} broken internal links`);
process.exit(errors ? 1 : 0);
