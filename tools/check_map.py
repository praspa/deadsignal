#!/usr/bin/env python3
"""Verifies every outpost layout in data/maps/: mission objectives reachable in
order (and the next stage locked until then), every terminal / container /
enemy reachable, no walled-off floor. Exit code = number of failing layouts."""
import glob
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_maps import Grid, validate  # noqa: E402

here = os.path.dirname(os.path.abspath(__file__))
fails = 0
for path in sorted(glob.glob(os.path.join(here, '..', 'data', 'maps', 'outpost_*.txt'))):
    rows = open(path).read().rstrip('\n').split('\n')
    w = max(len(r) for r in rows)
    grid = Grid(w, len(rows))
    grid.g = [list(r.ljust(w)) for r in rows]
    ok, why = validate(grid)
    print(f"{os.path.basename(path)}: {'all reachable' if ok else 'FAIL ' + why}")
    fails += 0 if ok else 1
sys.exit(fails)
