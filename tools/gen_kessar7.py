#!/usr/bin/env python3
"""Builds the Kessar VII (the Tangle) maps, deterministic per variant:

  data/maps/kessar7_shore.txt/.json      the Shoreline: black-sand beach, ocean behind you
  data/maps/kessar7_tangle_<n>.txt/.json the jungle maze, Kurast-style (3 layouts)
  data/maps/kessar7_caldera.txt/.json    the Brood King's arena

The Tangle is a maze of clearings on a coarse grid joined by winding jungle
paths: a randomised spanning tree (long corridors, dead ends) plus ~15% extra
loops. Rivers meander across it; wherever one crosses a path it becomes a
bridge or a ford, so the maze stays connected. The King's trail (tracks) runs
only along the true route to the Caldera gate. Dead ends always hold something.

Map characters (jungle set; see data/locations.json "enemy_chars" and level.gd):
  #  tree line / cliff        ,  jungle floor / basalt   .  black sand    _  old causeway
  ~  water (impassable)       =  bridge                  :  ford (shallow, slows)
  @  arrival   Y  exit shore <-> tangle   U  the Caldera gate (tangle <-> caldera)
  ^ palm  $ giant tree  " fern  ! glowing flowers  ? carved stone head  + pillar
  ( fallen log  ) bones  [ primate hut  ] skull totem  { the King's tracks  } wrecked boat
  c / C cache   J survey log   i boulder   j brood resin   v steam vent   * campfire
  1 Canopy Stalker  2 Gibberer  3 Thornback  4 Elder Thornback  5 the Brood King
  w swarmling  y spitter  G broodguard
"""
import json
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_kessar import Grid, compass, pack, scatter, DIRS4  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "data", "maps")
SOLID = set("#~^$?+([]}goi")
FLOOR = set(",._=:")


class JungleGrid(Grid):
    def walkable(self, x, y):
        return self.get(x, y) not in SOLID

    def is_floor(self, x, y):
        return self.get(x, y) in FLOOR


def validate(g, start, keys):
    dist = g.bfs(*start)
    floor = [(x, y) for y in range(g.h) for x in range(g.w) if g.walkable(x, y) and g.get(x, y) != " "]
    if len(dist) != len(floor):
        return False, "walled-off floor (%d of %d)" % (len(dist), len(floor))
    for k in keys:
        if k not in dist:
            return False, "unreachable %s %s" % (k, g.get(*k))
    return True, ""


def prune(g, start):
    """Floor the player can't reach becomes jungle again (stray sand, cut-off nooks)."""
    dist = g.bfs(*start)
    for y in range(g.h):
        for x in range(g.w):
            if g.walkable(x, y) and g.get(x, y) != " " and (x, y) not in dist:
                g.g[y][x] = "#"


def place_solid(g, rng, ch, count, ok, start):
    cands = [(x, y) for y in range(g.h) for x in range(g.w) if g.get(x, y) == "," and ok(x, y)]
    rng.shuffle(cands)
    total = sum(1 for y in range(g.h) for x in range(g.w) if g.walkable(x, y) and g.get(x, y) != " ")
    out = []
    for (x, y) in cands:
        if len(out) >= count:
            break
        if any(abs(x - a) + abs(y - b) < 3 for a, b in out):
            continue
        g.g[y][x] = ch
        if len(g.bfs(*start)) == total - 1:
            out.append((x, y))
            total -= 1
        else:
            g.g[y][x] = ","
    return out


def near_wall(g, x, y):
    return any(g.get(x + dx, y + dy) == "#" for dx, dy in DIRS4)


def sprinkle(g, rng, ch, p, ok):
    for y in range(g.h):
        for x in range(g.w):
            if g.get(x, y) == "," and ok(x, y) and rng.random() < p:
                g.g[y][x] = ch


# ---------------------------------------------------------------- the Tangle

def gen_tangle(variant):
    for attempt in range(400):
        rng = random.Random(31000 + variant * 1000 + attempt)
        COLS, ROWS, CW, CH = 6, 5, 16, 15
        W, H = COLS * CW + 4, ROWS * CH + 4
        g = JungleGrid(W, H, "#")
        centres = {}
        for cy in range(ROWS):
            for cx in range(COLS):
                x = 2 + cx * CW + CW // 2 + rng.randint(-3, 3)
                y = 2 + cy * CH + CH // 2 + rng.randint(-3, 3)
                centres[(cx, cy)] = (x, y)
                r = rng.randint(3, 4)
                for yy in range(y - r, y + r + 1):
                    for xx in range(x - r - 1, x + r + 2):
                        if (xx - x) ** 2 * 0.8 + (yy - y) ** 2 <= r * r + 1:
                            g.set(xx, yy, ",")
        # the maze: randomised depth-first spanning tree, plus a few loops
        start_c = (0, ROWS - 1) if variant % 2 else (0, 0)
        seen, stack, edges = {start_c}, [start_c], set()
        while stack:
            cur = stack[-1]
            nbrs = [(cur[0] + dx, cur[1] + dy) for dx, dy in DIRS4]
            nbrs = [n for n in nbrs if 0 <= n[0] < COLS and 0 <= n[1] < ROWS and n not in seen]
            if not nbrs:
                stack.pop()
                continue
            n = rng.choice(nbrs)
            edges.add(frozenset((cur, n)))
            seen.add(n)
            stack.append(n)
        tree = set(edges)
        all_edges = [frozenset(((x, y), (x + dx, y + dy))) for x in range(COLS) for y in range(ROWS)
                     for dx, dy in [(1, 0), (0, 1)] if x + dx < COLS and y + dy < ROWS]
        extra = [e for e in all_edges if e not in edges]
        rng.shuffle(extra)
        for e in extra[: max(2, int(len(all_edges) * 0.15))]:
            edges.add(e)
        # carve winding 3-wide paths between linked clearings
        path_cells = {}
        for e in edges:
            a, b = tuple(e)
            (x0, y0), (x1, y1) = centres[a], centres[b]
            x, y = x0, y0
            cells = []
            guard = 0
            while (abs(x - x1) + abs(y - y1)) > 0 and guard < 400:
                guard += 1
                if rng.random() < 0.72:
                    if abs(x1 - x) > abs(y1 - y):
                        x += (x1 > x) - (x1 < x)
                    else:
                        y += (y1 > y) - (y1 < y)
                else:
                    dx, dy = rng.choice(DIRS4)
                    x, y = max(3, min(W - 4, x + dx)), max(3, min(H - 4, y + dy))
                for ox in (-1, 0, 1):
                    for oy in (-1, 0, 1):
                        if abs(ox) + abs(oy) <= 1 or rng.random() < 0.35:
                            g.set(x + ox, y + oy, ",")
                cells.append((x, y))
            path_cells[e] = cells
        # the true route: tree path from the start clearing to the farthest one
        adj = {}
        for e in tree:
            a, b = tuple(e)
            adj.setdefault(a, []).append(b)
            adj.setdefault(b, []).append(a)
        parent, order = {start_c: None}, [start_c]
        for c in order:
            for n in adj.get(c, []):
                if n not in parent:
                    parent[n] = c
                    order.append(n)
        depth = {start_c: 0}
        for c in order[1:]:
            depth[c] = depth[parent[c]] + 1
        gate_c = max(depth, key=lambda c: depth[c])
        route, c = [], gate_c
        while c is not None:
            route.append(c)
            c = parent[c]
        route.reverse()
        route_edges = {frozenset((route[i], route[i + 1])) for i in range(len(route) - 1)}
        # rivers: two meandering water courses; where they cross a path or a
        # clearing they become a bridge or a ford, so nothing gets cut off
        floor_before = {(x, y) for y in range(H) for x in range(W) if g.get(x, y) == ","}
        for k in range(2):
            vertical = k == 0
            pos = rng.randint(W // 3, 2 * W // 3) if vertical else rng.randint(H // 3, 2 * H // 3)
            crossing_kind = "=" if k == 0 else ":"
            for t in range(2, (H if vertical else W) - 2):
                pos += rng.choice([-1, 0, 0, 1])
                pos = max(4, min((W if vertical else H) - 5, pos))
                for wdt in range(2):
                    x, y = (pos + wdt, t) if vertical else (t, pos + wdt)
                    if (x, y) in floor_before:
                        g.g[y][x] = crossing_kind
                    elif g.get(x, y) == "#":
                        g.g[y][x] = "~"
        # arrival and the gate
        sx, sy = centres[start_c]
        g.g[sy][sx - 2] = "Y"
        g.g[sy][sx] = "@"
        gx, gy = centres[gate_c]
        door = None
        for r in range(1, 8):
            for dx, dy in [(0, -1), (1, 0), (0, 1), (-1, 0)]:
                x, y = gx + dx * r, gy + dy * r
                if g.get(x, y) == "," and g.get(x + dx, y + dy) == "#":
                    door = (x, y)
                    break
            if door:
                break
        if door is None:
            continue
        g.g[door[1]][door[0]] = "U"
        start = (sx, sy)
        # the King's trail and the old causeway, only along the true route
        for e in route_edges:
            for i, (x, y) in enumerate(path_cells[e]):
                if g.get(x, y) == "," and i % 3 == 0:
                    g.g[y][x] = "{"
                elif g.get(x, y) == "," and rng.random() < 0.25:
                    g.g[y][x] = "_"
        # dead ends always pay off; landmarks per region
        degree = {}
        for e in edges:
            for c in e:
                degree[c] = degree.get(c, 0) + 1
        dead = [c for c in centres if degree.get(c, 0) == 1 and c not in (start_c, gate_c)]
        rewards = ["C", "?", "troop", "c", "J2", "?", "C", "troop"]
        rng.shuffle(dead)
        keys = [door, start]
        for i, c in enumerate(dead):
            x, y = centres[c]
            kind = rewards[i % len(rewards)]
            if kind in ("C", "c"):
                g.g[y][x] = kind
                keys.append((x, y))
            elif kind == "?":
                g.g[y][x] = "?"
                g.set(x + 2, y, "C")
                keys.append((x + 2, y))
            elif kind == "troop":
                g.g[y][x] = "3"
                keys += pack(g, rng, "2", (x + 1, y + 1), 3)
                g.set(x - 2, y - 1, "[")
                g.set(x - 2, y + 1, "]")
        # the survey team's log near the start points the way
        jx, jy = sx + 2, sy - 2
        if g.get(jx, jy) != ",":
            continue
        g.g[jy][jx] = "J"
        # creatures: primates throughout, the Brood thicker toward the gate
        mid = [c for c in centres if c not in (start_c, gate_c) and degree.get(c, 0) > 1]
        rng.shuffle(mid)
        for i, c in enumerate(mid):
            x, y = centres[c]
            near_gate = abs(c[0] - gate_c[0]) + abs(c[1] - gate_c[1]) <= 2
            if near_gate:
                keys += pack(g, rng, "w", (x, y), rng.randint(3, 5))
                keys += pack(g, rng, "y", (x + 2, y - 1), 1)
                if rng.random() < 0.5:
                    keys += pack(g, rng, "G", (x - 2, y), 1)
            elif i % 2 == 0:
                keys += pack(g, rng, "2", (x, y), rng.randint(3, 5))
            else:
                keys += pack(g, rng, "w", (x, y), 3)
                keys += pack(g, rng, "2", (x + 2, y + 1), 2)
        elder_c = next((c for c in mid if abs(c[0] - gate_c[0]) + abs(c[1] - gate_c[1]) >= 3), None)
        if elder_c is None:
            continue
        ex_, ey_ = centres[elder_c]
        g.set(ex_ - 1, ey_ - 1, "4")
        keys.append((ex_ - 1, ey_ - 1))
        keys += pack(g, rng, "2", (ex_ + 1, ey_ + 1), 4)
        dist = g.bfs(*start)
        keys += scatter(g, rng, "1", 7, lambda x, y: dist.get((x, y), 0) > 14 and near_wall(g, x, y))
        keys += scatter(g, rng, "3", 2, lambda x, y: dist.get((x, y), 0) > 25 and g.open_around(x, y, 1))
        # set dressing
        place_solid(g, rng, "$", 10, lambda x, y: dist.get((x, y), 0) > 4 and g.open_around(x, y, 1), start)
        place_solid(g, rng, "(", 10, lambda x, y: dist.get((x, y), 0) > 6 and g.open_around(x, y, 1), start)
        place_solid(g, rng, "i", 8, lambda x, y: dist.get((x, y), 0) > 6 and g.open_around(x, y, 1), start)
        sprinkle(g, rng, '"', 0.12, lambda x, y: near_wall(g, x, y))
        sprinkle(g, rng, "!", 0.02, lambda x, y: dist.get((x, y), 0) > 3)
        sprinkle(g, rng, ")", 0.015, lambda x, y: True)
        gd = g.bfs(*door)
        sprinkle(g, rng, "j", 0.18, lambda x, y: gd.get((x, y), 99) < 14)
        # the smashed primate village on the route, halfway
        vx, vy = centres[route[len(route) // 2]]
        for dx, dy, ch in [(-3, -2, "["), (3, -2, "["), (-3, 2, "]"), (2, 3, ")"), (0, -3, "(")]:
            if g.get(vx + dx, vy + dy) == ",":
                g.g[vy + dy][vx + dx] = ch
        prune(g, start)
        ok, why = validate(g, start, keys + [(jx, jy)])
        if not ok:
            continue
        meta = {
            "variant": variant,
            "name": ["Root Maze", "Drowned Causeway", "Howling Gorge"][variant - 1],
            "rooms": {"arrival": [sx - 3, sy - 3, sx + 3, sy + 3], "gate": [door[0] - 2, door[1] - 2, door[0] + 2, door[1] + 2],
                      "village": [vx - 4, vy - 4, vx + 4, vy + 4]},
            "dirs": {"caldera_dir": compass(door[0] - sx, door[1] - sy)},
        }
        return g, meta
    raise SystemExit("tangle variant %d: no valid layout" % variant)


# ---------------------------------------------------------------- the Shoreline

def gen_shore():
    rng = random.Random(7700)
    W, H = 52, 36
    g = JungleGrid(W, H, "#")
    for y in range(H):
        for x in range(W):
            if x < 14 or y > H - 10:
                g.g[y][x] = "~"                                   # the ocean behind you
            elif x < 26 or y > H - 18:
                g.g[y][x] = "."                                   # black sand beach
            elif rng.random() < 0.15 and (x < 30 or y > H - 22):
                g.g[y][x] = "."
    for y in range(2, H - 10):                                    # surf line wobbles
        for x in range(12, 17):
            if rng.random() < 0.5:
                g.g[y][x] = "~" if x < 15 else "."
    # a jungle path inland to the exit
    for x in range(24, W - 3):
        for y in range(8 + (x % 5 == 0), 12 + (x % 7 == 0)):
            g.g[y][x] = ","
    ex, ey = W - 4, 10
    g.g[ey][ex] = "Y"
    lx, ly = 19, 20
    g.g[ly][lx] = "@"
    for (x, y), ch in [((17, 26), "}"), ((18, 26), "}"), ((21, 24), "c"), ((22, 25), "c"), ((23, 22), "*"),
                       ((20, 14), "("), ((24, 27), "("), ((25, 17), "J")]:
        g.g[y][x] = ch
    scatter(g, rng, "^", 9, lambda x, y: g.get(x, y) == "." and 15 < x < 30 and abs(x - lx) + abs(y - ly) > 4)
    sprinkle(g, rng, '"', 0.2, lambda x, y: near_wall(g, x, y))
    mobs = pack(g, rng, "2", (36, 10), 3) + pack(g, rng, "2", (44, 9), 2)
    for y in range(H):
        for x in range(W):
            if g.get(x, y) == "." and near_wall(g, x, y) and rng.random() < 0.3:
                g.g[y][x] = '"'
    prune(g, (lx, ly))
    ok, why = validate(g, (lx, ly), [(ex, ey), (25, 17)] + mobs)
    if not ok:
        raise SystemExit("shore: " + why)
    return g, {"name": "the Shoreline", "rooms": {"beach": [16, 14, 30, 28]}, "dirs": {"jungle_dir": compass(ex - lx, ey - ly)}}


# ---------------------------------------------------------------- the Caldera

def gen_caldera():
    rng = random.Random(8800)
    W, H = 44, 44
    cx, cy, R = 22, 22, 16
    g = JungleGrid(W, H, "#")
    for y in range(H):
        for x in range(W):
            if (x - cx) ** 2 + (y - cy) ** 2 <= R * R + rng.randint(-6, 6):
                g.g[y][x] = ","
    for y in range(cy + R - 1, H - 2):                            # the passage from the gate
        for x in range(cx - 1, cx + 2):
            g.g[y][x] = ","
    g.g[H - 4][cx] = "U"
    g.g[H - 6][cx] = "@"
    pillars = []
    for k in range(8):                                            # stone pillars: cover the King smashes
        a = k * math.tau / 8 + 0.3
        x, y = int(round(cx + math.cos(a) * 9)), int(round(cy + math.sin(a) * 9))
        g.g[y][x] = "+"
        pillars.append((x, y))
    g.g[cy - 6][cx] = "5"                                         # the Brood King
    sprinkle(g, rng, ")", 0.06, lambda x, y: True)
    sprinkle(g, rng, "v", 0.012, lambda x, y: True)
    for (x, y) in [(cx - 12, cy - 4), (cx + 12, cy + 3), (cx - 4, cy + 12)]:
        if g.get(x, y) == ",":
            g.g[y][x] = "?"
    ok, why = validate(g, (cx, H - 6), [(cx, H - 4), (cx, cy - 6)])
    if not ok:
        raise SystemExit("caldera: " + why)
    return g, {"name": "the King's Caldera", "rooms": {"arena": [cx - R, cy - R, cx + R, cy + R]}, "dirs": {}}


def write(name, g, meta):
    base = os.path.join(OUT, name)
    open(base + ".txt", "w").write(g.text())
    json.dump(meta, open(base + ".json", "w"), indent=1)
    counts = {c: sum(r.count(c) for r in g.g) for c in "12345wyG~=:{$?+[]CcJ"}
    print("%s: %s  %s" % (name, meta["name"], " ".join("%s=%d" % kv for kv in counts.items() if kv[1])))


def main():
    write("kessar7_shore", *gen_shore())
    for v in range(1, 4):
        write("kessar7_tangle_%d" % v, *gen_tangle(v))
    write("kessar7_caldera", *gen_caldera())


if __name__ == "__main__":
    main()
