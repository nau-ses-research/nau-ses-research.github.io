import rss from "@astrojs/rss";
import { getCollection } from "astro:content";
import type { APIRoute } from "astro";

export const GET: APIRoute = async (context) => {
  const news = (await getCollection("news")).sort(
    (a, b) => b.data.date.valueOf() - a.data.date.valueOf(),
  );
  return rss({
    title: "NAU School of Earth and Sustainability — News",
    description:
      "Research stories from the School of Earth and Sustainability, including monthly spotlights on graduate-student-led publications.",
    site: context.site!,
    items: news.map((n) => ({
      title: n.data.title,
      description: n.data.summary,
      pubDate: n.data.date,
      link: `/news/${n.id}/`,
    })),
  });
};
