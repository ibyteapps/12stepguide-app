#!/usr/bin/env python3
"""Sets the Status column of FEATURE_MATRIX.md rows: set_status.py <status> F-001 F-002 ..."""
import re
import sys
from pathlib import Path

status, ids = sys.argv[1], set(sys.argv[2:])
path = Path(__file__).resolve().parents[1] / "FEATURE_MATRIX.md"
lines = path.read_text().splitlines(keepends=True)
done = set()
for i, line in enumerate(lines):
    m = re.match(r"\| (F-\d+[a-z]?) \|", line)
    if m and m.group(1) in ids:
        lines[i] = re.sub(r"\| [☐◐✅✖] \|\s*$", f"| {status} |\n", line)
        done.add(m.group(1))
path.write_text("".join(lines))
missing = ids - done
print(f"{len(done)} rows set to {status}" + (f"; not found: {sorted(missing)}" if missing else ""))
