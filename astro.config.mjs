// @ts-check
import { defineConfig } from "astro/config";
import preact from "@astrojs/preact";
import sitemap from "@astrojs/sitemap";
import tailwindcss from "@tailwindcss/vite";

// https://astro.build/config
export default defineConfig({
  site: "https://ses-nau.org",
  integrations: [
    preact(),
    sitemap({
      filter: (page) => !page.includes("/archived-profiles/"),
    }),
  ],
  vite: {
    plugins: [tailwindcss()],
  },
  // GitHub Pages has no server redirects; these emit meta-refresh stub pages
  // for the retired knitted-Rmd URLs from the old Hugo site, plus profile
  // moves from the 2026-08-20 roster changes.
  redirects: {
    "/faculty/": "/publications/",
    "/students/": "/research/",
    "/analytics/": "/research/",
    // left NAU (current -> archived)
    "/faculty-profiles/scott-anderson/": "/archived-profiles/scott-anderson/",
    "/faculty-profiles/duan-biggs/": "/archived-profiles/duan-biggs/",
    "/faculty-profiles/nancy-johnson/": "/archived-profiles/nancy-johnson/",
    "/faculty-profiles/laura-wasylenki/": "/archived-profiles/laura-wasylenki/",
    // restored to current faculty (archived -> current)
    "/archived-profiles/francisco-apen/": "/faculty-profiles/francisco-apen/",
    "/archived-profiles/rosemary-logan/": "/faculty-profiles/rosemary-logan/",
    "/archived-profiles/lucero-radonic/": "/faculty-profiles/lucero-radonic/",
    "/archived-profiles/cody-routson/": "/faculty-profiles/cody-routson/",
    "/archived-profiles/temuulen-sankey/": "/faculty-profiles/temuulen-sankey/",
  },
});
