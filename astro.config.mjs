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
  // for the retired knitted-Rmd URLs from the old Hugo site.
  redirects: {
    "/faculty/": "/publications/",
    "/students/": "/research/",
    "/analytics/": "/research/",
  },
});
