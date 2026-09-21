/** Shared labels for the graduate programs advisors recruit into. */
export const PROGRAMS = {
  "geosciences-ms": {
    short: "MS Geosciences",
    long: "MS in Geosciences",
    href: "/student-opportunities/geology-ms/",
  },
  "esp-ms": {
    short: "MS Environmental Sciences & Policy",
    long: "MS in Environmental Sciences and Policy",
    href: "/student-opportunities/environmental-sciences-policy/",
  },
  "eses-phd": {
    short: "PhD Earth Sciences & Environmental Sustainability",
    long: "PhD in Earth Sciences and Environmental Sustainability",
    href: "/student-opportunities/earth-sciences-environmental-sustainability-phd/",
  },
} as const;

export type ProgramKey = keyof typeof PROGRAMS;
