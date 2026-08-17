#!/usr/bin/env python3
"""Compare two versions of publications.csv (shadow validation).

Usage:  python3 scripts/diff_pipelines.py BASELINE.csv CANDIDATE.csv

Reports rows added/removed, citation deltas, and per-field changes on shared
rows (keyed by simple_title). Used during the R-to-Python pipeline cutover to
compare what each pipeline did to the same baseline, and handy afterward for
reviewing any weekly diff. Name comparisons are case-insensitive so display
case cleanups don't read as regressions.
"""

import csv
import sys
from pathlib import Path


def load(path: str) -> dict[str, dict]:
    with open(path, newline="") as f:
        rows = list(csv.DictReader(f))
    return {r["simple_title"]: r for r in rows}


def norm(v: str) -> str:
    return v.strip().lower()


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__)
        return 2
    base = load(sys.argv[1])
    cand = load(sys.argv[2])

    added = sorted(set(cand) - set(base))
    removed = sorted(set(base) - set(cand))
    print(f"Baseline: {len(base)} rows ({Path(sys.argv[1]).name})")
    print(f"Candidate: {len(cand)} rows ({Path(sys.argv[2]).name})")
    print(f"\nAdded rows: {len(added)}")
    for st in added:
        r = cand[st]
        print(f"  + {r['title'][:70]} ({r['year']}) [{r['ses_faculty']}]")
    print(f"Removed rows: {len(removed)}")
    for st in removed:
        r = base[st]
        print(f"  - {r['title'][:70]} ({r['year']})")

    cite_changes = 0
    field_changes = 0
    for st in set(base) & set(cand):
        b, c = base[st], cand[st]
        if b["citations"] != c["citations"]:
            cite_changes += 1
        for col in b:
            if col in ("citations", "id") or col not in c:
                continue
            if norm(b[col]) != norm(c[col]):
                field_changes += 1
                print(f"  ~ {b['title'][:50]}: {col}: {b[col]!r} -> {c[col]!r}")
    print(f"\nCitation changes on shared rows: {cite_changes}")
    print(f"Other field changes on shared rows: {field_changes}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
