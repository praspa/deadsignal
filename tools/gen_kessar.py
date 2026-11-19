#!/usr/bin/env python3
"""Builds the Kessar IV layouts (deterministic per variant):

  data/maps/kessar_surface_<n>.txt/.json   Ashfall Flats, open ash plains
  data/maps/kessar_hive_<n>.txt/.json      the Brood hive, chambers + tunnels

Map characters (see scripts/world/level.gd):
  #  rock / chitin wall       ,  ground           @  arrival point
  H  hive sinkhole (surface: way down, hive: way back up)
  J  mining camp log terminal       k  corpse          c / C  container
  g  mining machinery (solid)       o  crates (solid)  i  boulder (solid)
  j  resin growth (decor)           f  glowing fungus (light)
  m  infested miner   u  ash burrower   w  swarmling   y  spitter
  G  broodguard       e  egg cluster    K  Brood Queen

Every layout is validated: one connected walkable region, and every key point
(arrival, sinkhole, terminal, containers, enemies, queen) reachable.
Run:  python3 tools/gen_kessar.py
"""
import json
import math
import os
import random
from collections import deque

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "data", "maps")
VARIANTS = 3
SOLID = set("#gois")
DIRS8 = [(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)]
DIRS4 = DIRS8[:4]


class Grid:
    def __init__(self, w, h, fill="#"):
        self.w, self.h = w, h
        self.g = [[fill] * w for _ in range(h)]

    def inside(self, x, y):
        return 0 <= x < self.w and 0 <= y < self.h

    def get(self, x, y):
        return self.g[y][x] if self.inside(x, y) else "#"

    def set(self, x, y, c):
        if 1 <= x < self.w - 1 and 1 <= y < self.h - 1:
            self.g[y][x] = c

    def walkable(self, x, y):
        return self.get(x, y) not in SOLID

    def bfs(self, sx, sy):
        dist = {(sx, sy): 0}
        q = deque([(sx, sy)])
        while q:
            x, y = q.popleft()
            for dx, dy in DIRS4:
                n = (x + dx, y + dy)
                if n not in dist and self.walkable(*n):
                    dist[n] = dist[(x, y)] + 1
                    q.append(n)
        return dist

    def cells(self, ch=","):
        return [(x, y) for y in range(self.h) for x in range(self.w) if self.g[y][x] == ch]

    def open_around(self, x, y, r=1):
        return all(self.get(x + dx, y + dy) == "," for dy in range(-r, r + 1) for dx in range(-r, r + 1))

    def text(self):
        return "\n".join("".join(r).rstrip() for r in self.g) + "\n"


def compass(dx, dy):
    """Grid direction (y down = south) as a compass word."""
    ang = math.degrees(math.atan2(-dy, dx)) % 360
    names = ["east", "north-east", "north", "north-west", "west", "south-west", "south", "south-east"]
    return names[int((ang + 22.5) // 45) % 8]


def keep_largest(grid):
    seen, best = set(), set()
    for (x, y) in grid.cells():
        if (x, y) in seen:
            continue
        region = set(grid.bfs(x, y).keys())
        seen |= region
        if len(region) > len(best):
            best = region
    for (x, y) in grid.cells():
        if (x, y) not in best:
            grid.g[y][x] = "#"


def scatter(grid, rng, ch, count, ok):
    cands = [c for c in grid.cells() if ok(*c)]
    rng.shuffle(cands)
    placed = []
    for (x, y) in cands:
        if len(placed) >= count:
            break
        if any(abs(x - px) + abs(y - py) < 3 for px, py in placed):
            continue
        grid.g[y][x] = ch
        placed.append((x, y))
    return placed


def pack(grid, rng, ch, center, n):
    """A tight group of `n` monsters around `center`."""
    cx, cy = center
    spots = [(cx + dx, cy + dy) for dy in range(-2, 3) for dx in range(-2, 3)]
    rng.shuffle(spots)
    out = []
    for (x, y) in spots:
        if len(out) >= n:
            break
        if grid.get(x, y) == ",":
            grid.g[y][x] = ch
            out.append((x, y))
    return out


def validate(grid, start, keys):
    dist = grid.bfs(*start)
    floor = [(x, y) for y in range(grid.h) for x in range(grid.w) if grid.walkable(x, y)]
    if len(dist) != len(floor):
        return False, "walled-off floor (%d of %d reachable)" % (len(dist), len(floor))
    for k in keys:
        if k not in dist:
            return False, "unreachable %s" % (k,)
    return True, ""


# ---------------------------------------------------------------- surface

def gen_surface(variant):
    for attempt in range(200):
        rng = random.Random(variant * 1000 + attempt)
        W, H = 92, 72
        g = Grid(W, H, ",")
        for y in range(H):
            for x in range(W):
                if x in (0, W - 1) or y in (0, H - 1) or rng.random() < 0.43:
                    g.g[y][x] = "#"
        for _ in range(5):   # cellular-automata smoothing into ridges / plains
            n = [[sum(1 for dx, dy in DIRS8 if g.get(x + dx, y + dy) == "#") for x in range(W)] for y in range(H)]
            for y in range(1, H - 1):
                for x in range(1, W - 1):
                    g.g[y][x] = "#" if n[y][x] > 4 or (n[y][x] == 4 and g.g[y][x] == "#") else ","
        keep_largest(g)
        floor = g.cells()
        if len(floor) < W * H * 0.45:
            continue
        # landing in one corner (which one depends on the variant), the sinkhole far away
        corners = [(4, 4), (W - 5, 4), (4, H - 5), (W - 5, H - 5)]
        cx, cy = corners[(variant + attempt) % 4]
        land = min((c for c in floor if g.open_around(*c, 2)), key=lambda c: (c[0] - cx) ** 2 + (c[1] - cy) ** 2, default=None)
        if land is None:
            continue
        dist = g.bfs(*land)
        far = max(dist.values())
        hole_c = [c for c, d in dist.items() if d > far * 0.8 and g.open_around(*c, 1)]
        if not hole_c:
            continue
        hole = rng.choice(hole_c)
        hd = g.bfs(*hole)
        # mining camp: a clearing roughly a third of the way to the hive
        camp_c = [c for c, d in dist.items() if far * 0.3 < d < far * 0.5 and hd.get(c, 0) > far * 0.35]
        if not camp_c:
            continue
        camp = rng.choice(camp_c)
        x0, y0, x1, y1 = camp[0] - 5, camp[1] - 4, camp[0] + 5, camp[1] + 4
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                g.set(x, y, ",")
        lx, ly = land
        g.g[ly][lx] = "@"
        g.g[hole[1]][hole[0]] = "H"
        # camp contents: hauler machinery, crates, the log, the dead, loot, the infested
        for (x, y), ch in [((camp[0] - 3, camp[1] - 2), "g"), ((camp[0] - 2, camp[1] - 2), "g"),
                           ((camp[0] + 3, camp[1] - 3), "o"), ((camp[0] + 4, camp[1] - 3), "o"),
                           ((camp[0] + 4, camp[1] - 2), "o"), ((camp[0], camp[1] - 3), "J"),
                           ((camp[0] - 4, camp[1] + 2), "k"), ((camp[0] + 1, camp[1] + 3), "k"),
                           ((camp[0] + 3, camp[1] + 2), "c"), ((camp[0] - 1, camp[1] + 1), "c")]:
            g.set(x, y, ch)
        miners = scatter(g, rng, "m", 4, lambda x, y: abs(x - camp[0]) <= 7 and abs(y - camp[1]) <= 6)
        # everything else keeps clear of the landing zone
        far_from_land = lambda x, y, m=12: dist.get((x, y), 0) > m
        near_hole = lambda x, y, r: hd.get((x, y), 999) <= r
        scatter(g, rng, "i", 26, lambda x, y: g.open_around(x, y, 1) and dist.get((x, y), 0) > 4)
        scatter(g, rng, "u", 8, lambda x, y: far_from_land(x, y) and g.open_around(x, y, 1))
        packs = [c for c in g.cells() if far_from_land(c[0], c[1], 18) and g.open_around(*c, 1)]
        rng.shuffle(packs)
        centers = []
        for c in packs:
            if len(centers) >= 4:
                break
            if all(abs(c[0] - p[0]) + abs(c[1] - p[1]) > 14 for p in centers + [camp]):
                centers.append(c)
        sw = []
        for c in centers:
            sw += pack(g, rng, "w", c, rng.randint(3, 5))
        sp = scatter(g, rng, "y", 4, lambda x, y: far_from_land(x, y, 16))
        bg = scatter(g, rng, "G", 2, lambda x, y: near_hole(x, y, 10) and hd.get((x, y), 0) > 2)
        # resin growth thickens toward the hive: the main clue
        for (x, y) in g.cells():
            d = hd.get((x, y))
            if d is None or d > far * 0.55:
                continue
            p = 0.32 * (1.0 - d / (far * 0.55)) ** 2
            if rng.random() < p:
                g.g[y][x] = "j"
        cont = scatter(g, rng, "c", 4, lambda x, y: far_from_land(x, y, 8))
        strong = scatter(g, rng, "C", 1, lambda x, y: near_hole(x, y, 18))
        keys = [hole, (camp[0], camp[1] - 3)] + miners + sw + sp + bg + cont + strong
        ok, why = validate(g, land, keys)
        if not ok or len(bg) < 1 or len(strong) < 1:
            continue
        meta = {
            "variant": variant,
            "name": "Survey Grid %s" % "ABC"[variant - 1],
            "rooms": {"landing": [lx - 2, ly - 2, lx + 2, ly + 2], "camp": [x0, y0, x1, y1],
                      "hive_entrance": [hole[0] - 1, hole[1] - 1, hole[0] + 1, hole[1] + 1]},
            "dirs": {"hive_dir": compass(hole[0] - camp[0], hole[1] - camp[1])},
        }
        return g, meta
    raise SystemExit("surface variant %d: no valid layout" % variant)


# ---------------------------------------------------------------- hive

def carve_disc(g, cx, cy, r):
    for y in range(cy - r, cy + r + 1):
        for x in range(cx - r, cx + r + 1):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r * r + r * 0.6:
                g.set(x, y, ",")


def carve_tunnel(g, rng, a, b):
    x, y = a
    while (x, y) != b:
        if rng.random() < 0.7:
            x += (b[0] > x) - (b[0] < x)
            y += (b[1] > y) - (b[1] < y)
        else:
            dx, dy = rng.choice(DIRS4)
            x, y = max(2, min(g.w - 3, x + dx)), max(2, min(g.h - 3, y + dy))
        for dx, dy in [(0, 0), (1, 0), (0, 1), (1, 1)]:
            g.set(x + dx, y + dy, ",")


def gen_hive(variant):
    for attempt in range(200):
        rng = random.Random(77000 + variant * 1000 + attempt)
        W, H = 74, 62
        g = Grid(W, H, "#")
        chambers = []
        for _ in range(400):
            if len(chambers) >= 9:
                break
            r = rng.randint(4, 6)
            c = (rng.randint(r + 3, W - r - 4), rng.randint(r + 3, H - r - 4))
            if all(math.dist(c, (o[0], o[1])) > r + o[2] + 6 for o in chambers):
                chambers.append((c[0], c[1], r))
        if len(chambers) < 8:
            continue
        # the queen's chamber: the chamber farthest from the arrival one, made larger
        start = chambers[0]
        qi = max(range(1, len(chambers)), key=lambda i: math.dist(start[:2], chambers[i][:2]))
        q = chambers[qi]
        chambers[qi] = (q[0], q[1], 8)
        for (cx, cy, r) in chambers:
            carve_disc(g, cx, cy, r)
        # connect: minimum spanning tree plus a couple of loops
        pts = [c[:2] for c in chambers]
        linked, edges = {0}, []
        while len(linked) < len(pts):
            a, b = min(((i, j) for i in linked for j in range(len(pts)) if j not in linked),
                       key=lambda e: math.dist(pts[e[0]], pts[e[1]]))
            edges.append((a, b))
            linked.add(b)
        for _ in range(2):
            a, b = rng.sample(range(len(pts)), 2)
            if a != qi and b != qi:
                edges.append((a, b))
        for a, b in edges:
            carve_tunnel(g, rng, pts[a], pts[b])
        keep_largest(g)
        sx, sy = start[0], start[1]
        if g.get(sx, sy) != ",":
            continue
        g.g[sy][sx] = "@"
        ex, ey = sx - 1, sy - 2
        if g.get(ex, ey) != ",":
            continue
        g.g[ey][ex] = "H"
        qx, qy = q[0], q[1]
        g.g[qy][qx] = "K"
        dist = g.bfs(sx, sy)
        # eggs along chamber rims, a ring of them around the queen
        eggs = []
        for i, (cx, cy, r) in enumerate(chambers):
            if i == 0:
                continue
            n = 7 if i == qi else rng.randint(2, 4)
            rr = (8 if i == qi else r) - 1
            for k in range(n):
                a = rng.random() * math.tau if i != qi else k * math.tau / n
                x, y = int(round(cx + math.cos(a) * rr)), int(round(cy + math.sin(a) * rr))
                if g.get(x, y) == ",":
                    g.g[y][x] = "e"
                    eggs.append((x, y))
        # fungus lights: a couple per chamber, sparse in tunnels
        for i, (cx, cy, r) in enumerate(chambers):
            for _k in range(2 if i != qi else 4):
                a = rng.random() * math.tau
                x, y = int(round(cx + math.cos(a) * (r - 2))), int(round(cy + math.sin(a) * (r - 2)))
                if g.get(x, y) == ",":
                    g.g[y][x] = "f"
        scatter(g, rng, "f", 6, lambda x, y: dist.get((x, y), 0) > 6)
        away = lambda x, y, m=10: dist.get((x, y), 0) > m and math.dist((x, y), (qx, qy)) > 9
        mobs = []
        for i, (cx, cy, r) in enumerate(chambers):
            if i in (0, qi):
                continue
            mobs += pack(g, rng, "w", (cx, cy), rng.randint(3, 5))
        mobs += scatter(g, rng, "y", 6, away)
        mobs += scatter(g, rng, "G", 4, lambda x, y: away(x, y, 16))
        scatter(g, rng, "j", 40, lambda x, y: dist.get((x, y), 0) > 4)
        cont = scatter(g, rng, "c", 3, away)
        ok, why = validate(g, (sx, sy), [(ex, ey), (qx, qy)] + eggs + mobs + cont)
        if not ok:
            continue
        meta = {
            "variant": variant,
            "name": "Brood Warren %s" % ["I", "II", "III"][variant - 1],
            "rooms": {"arrival": [sx - 3, sy - 3, sx + 3, sy + 3], "queen": [qx - 8, qy - 8, qx + 8, qy + 8]},
            "dirs": {},
        }
        return g, meta
    raise SystemExit("hive variant %d: no valid layout" % variant)


def main():
    for v in range(1, VARIANTS + 1):
        for kind, gen in [("kessar_surface", gen_surface), ("kessar_hive", gen_hive)]:
            g, meta = gen(v)
            base = os.path.join(OUT, "%s_%d" % (kind, v))
            open(base + ".txt", "w").write(g.text())
            json.dump(meta, open(base + ".json", "w"), indent=1)
            counts = {c: sum(r.count(c) for r in g.g) for c in "mwyGueKcCjfi"}
            print("%s_%d: %s  %s" % (kind, v, meta["name"], " ".join("%s=%d" % kv for kv in counts.items() if kv[1])))


if __name__ == "__main__":
    main()
