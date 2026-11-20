#!/usr/bin/env python3
"""Builds the Last Water (Kessar III) maps, deterministic per variant:

  data/maps/lastwater_port.txt/.json         spaceport landing zone (one layout)
  data/maps/lastwater_streets_<n>.txt/.json  the overrun city, street grid (3 layouts)
  data/maps/lastwater_hall.txt/.json         the Civic Hall interior (one layout)

Map characters beyond tools/gen_kessar.py's set (see scripts/world/level.gd):
  Y  zone exit: spaceport <-> streets          U  zone exit: streets <-> Civic Hall (card-locked)
  A  the Brood Lieutenant (carries the card)   a  Infested Militia   s  Wall Crawler (clings to walls)
  O  cocooned governor (1-3, in order)         n  wrecked vehicle    q  barricade    x  water tower
  J  log terminal (militia log)                l  street lamp (dead)
  &  the desecrated Last Water fountain (city centre)   %  rubble   *  smouldering fire

Every layout is validated: one connected walkable region, every key point reachable.
Run:  python3 tools/gen_lastwater.py
"""
import json
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_kessar import Grid, compass, keep_largest, pack, scatter, validate, DIRS4  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "data", "maps")
VARIANTS = 3
SOLID = set("#goi" + "nqx&")   # (s = Wall Crawler, not solid)


class CityGrid(Grid):
    def walkable(self, x, y):
        return self.get(x, y) not in SOLID


def place_solid(g, rng, ch, count, ok, start):
    """Like scatter, but only keeps a solid prop if every walkable tile stays reachable."""
    cands = [c for c in g.cells() if ok(*c)]
    rng.shuffle(cands)
    placed = []
    total = sum(1 for y in range(g.h) for x in range(g.w) if g.walkable(x, y))
    for (x, y) in cands:
        if len(placed) >= count:
            break
        if any(abs(x - px) + abs(y - py) < 3 for px, py in placed):
            continue
        g.g[y][x] = ch
        if len(g.bfs(*start)) == total - 1:
            placed.append((x, y))
            total -= 1
        else:
            g.g[y][x] = ","
    return placed


def next_to_wall(g, x, y):
    return any(g.get(x + dx, y + dy) == "#" for dx, dy in DIRS4)


# ---------------------------------------------------------------- spaceport

def gen_port():
    rng = random.Random(4100)
    W, H = 46, 32
    g = CityGrid(W, H, ",")
    for y in range(H):
        for x in range(W):
            if x < 2 or y < 2 or x >= W - 2 or y >= H - 2:
                g.g[y][x] = "#"
    # hangars and the control tower as building blocks
    for (x0, y0, x1, y1) in [(6, 3, 13, 8), (6, 23, 13, 28), (30, 3, 37, 7), (30, 24, 37, 28), (21, 9, 24, 12)]:
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                g.g[y][x] = "#"
    lx, ly = 9, 15
    g.g[ly][lx] = "@"
    for x in range(lx - 2, lx + 3):           # landing pad markings: keep clear
        for y in range(ly - 2, ly + 3):
            if g.g[y][x] == ",":
                g.g[y][x] = "_"
    g.g[ly][lx] = "@"
    ex, ey = W - 3, 16
    g.g[ey][ex] = "Y"
    for (x, y), ch in [((16, 9), "g"), ((17, 9), "g"), ((27, 10), "o"), ((28, 10), "o"), ((27, 21), "o"),
                       ((40, 12), "q"), ((40, 13), "q"), ((40, 19), "q"), ((40, 20), "q"), ((18, 22), "n"),
                       ((26, 22), "k"), ((35, 15), "k"), ((15, 20), "c"), ((33, 10), "c"), ((16, 11), "C"),
                       ((15, 15), "l"), ((28, 15), "l"), ((36, 17), "l"), ((20, 25), "x")]:
        g.g[y][x] = ch
    scatter(g, rng, "%", 10, lambda x, y: g.get(x, y) == "," and next_to_wall(g, x, y))
    scatter(g, rng, "*", 3, lambda x, y: x > 20 and g.get(x, y) == ",")
    for x in range(lx + 3, ex):                # the road from the pad to the city gate
        for y in (ey - 1, ey):
            if g.g[y][x] == ",":
                g.g[y][x] = "_"
    mobs = pack(g, rng, "w", (38, 13), 3) + pack(g, rng, "w", (34, 21), 3) + scatter(g, rng, "a", 2, lambda x, y: x > 30)
    ok, why = validate(g, (lx, ly), [(ex, ey)] + mobs)
    if not ok:
        raise SystemExit("port: " + why)
    meta = {"name": "Spaceport", "rooms": {"pad": [lx - 2, ly - 2, lx + 2, ly + 2]}, "dirs": {"gate_dir": compass(ex - lx, ey - ly)}}
    return g, meta


# ---------------------------------------------------------------- streets

def gen_streets(variant):
    for attempt in range(300):
        rng = random.Random(9000 + variant * 1000 + attempt)
        W, H = 96, 74
        g = CityGrid(W, H, "#")
        # avenues and cross streets, jittered so no two layouts share a grid
        xs, x = [], 3
        while x < W - 6:
            xs.append(x)
            x += rng.randint(13, 18)
        ys, y = [], 3
        while y < H - 6:
            ys.append(y)
            y += rng.randint(11, 15)
        for ax in xs:
            w = rng.randint(3, 4)
            for yy in range(2, H - 2):
                for xx in range(ax, min(W - 2, ax + w)):
                    g.g[yy][xx] = ","
        for ay in ys:
            w = rng.randint(3, 4)
            for xx in range(2, W - 2):
                for yy in range(ay, min(H - 2, ay + w)):
                    g.g[yy][xx] = ","
        # find blocks (wall regions) to turn into plazas or cut alleys through
        seen, blocks = set(), []
        for yy in range(H):
            for xx in range(W):
                if g.g[yy][xx] == "#" and (xx, yy) not in seen and 2 <= xx < W - 2 and 2 <= yy < H - 2:
                    stack, cells = [(xx, yy)], []
                    seen.add((xx, yy))
                    while stack:
                        cx, cy = stack.pop()
                        cells.append((cx, cy))
                        for dx, dy in DIRS4:
                            n = (cx + dx, cy + dy)
                            if n not in seen and 2 <= n[0] < W - 2 and 2 <= n[1] < H - 2 and g.g[n[1]][n[0]] == "#":
                                seen.add(n)
                                stack.append(n)
                    blocks.append(cells)
        # the central plaza (Founders' Plaza, with the fountain) plus two more
        cxm, cym = W // 2, H // 2
        centre = min(blocks, key=lambda cells: (sum(c[0] for c in cells) / len(cells) - cxm) ** 2 + (sum(c[1] for c in cells) / len(cells) - cym) ** 2)
        blocks.remove(centre)
        rng.shuffle(blocks)
        blocks.insert(0, centre)
        plazas = []
        for cells in blocks[:3]:
            for (cx, cy) in cells:
                g.g[cy][cx] = ","
            bx = [c[0] for c in cells]
            by = [c[1] for c in cells]
            plazas.append(((min(bx) + max(bx)) // 2, (min(by) + max(by)) // 2))
        for cells in blocks[3:]:
            if rng.random() < 0.45:
                bx = [c[0] for c in cells]
                by = [c[1] for c in cells]
                if rng.random() < 0.5:
                    ax = (min(bx) + max(bx)) // 2
                    for cy in range(min(by), max(by) + 1):
                        g.g[cy][ax] = ","
                else:
                    ay = (min(by) + max(by)) // 2
                    for cx in range(min(bx), max(bx) + 1):
                        g.g[ay][cx] = ","
        keep_largest(g)
        floor = g.cells()
        # arrival from the spaceport: a street at the left edge; the Civic Hall door far away
        left = [c for c in floor if c[0] <= 5 and g.open_around(c[0], c[1], 1)]
        if not left:
            continue
        sx, sy = min(left, key=lambda c: abs(c[1] - H // 2))
        dist = g.bfs(sx, sy)
        far = max(dist.values())
        door_c = [c for c, d in dist.items() if d > far * 0.8 and next_to_wall(g, *c) and g.get(c[0], c[1]) == ","]
        if not door_c:
            continue
        ux, uy = rng.choice(door_c)
        g.g[sy][sx] = "Y"
        if g.get(sx + 1, sy) != ",":
            continue
        g.g[sy][sx + 1] = "@"
        g.g[uy][ux] = "U"
        ud = g.bfs(ux, uy)
        # the Lieutenant roams the middle distance, away from the hall door
        lt_c = [c for c, d in dist.items() if far * 0.45 < d < far * 0.8 and ud.get(c, 0) > 18 and g.open_around(c[0], c[1], 1)]
        if not lt_c:
            continue
        ax, ay = rng.choice(lt_c)
        g.g[ay][ax] = "A"
        escort = pack(g, rng, "w", (ax, ay), 4) + pack(g, rng, "G", (ax + 2, ay), 1)
        away = lambda x, y, m=14: dist.get((x, y), 0) > m
        start = (sx + 1, sy)
        props = place_solid(g, rng, "n", 14, lambda x, y: away(x, y, 6) and g.open_around(x, y, 1), start)
        props += place_solid(g, rng, "q", 10, lambda x, y: away(x, y, 6) and g.open_around(x, y, 1), start)
        fx, fy = plazas[0]
        fountain = place_solid(g, rng, "&", 1, lambda x, y: (x, y) == (fx, fy), start)
        if not fountain:
            continue
        for k in range(4):                       # the brood came up through the water mains
            a = k * math.tau / 4 + 0.4
            ex_, ey_ = int(round(fx + math.cos(a) * 3)), int(round(fy + math.sin(a) * 3))
            if g.get(ex_, ey_) == ",":
                g.g[ey_][ex_] = "e"
        for (px, py) in plazas[1:]:
            place_solid(g, rng, "x", 1, lambda x, y, px=px, py=py: (x, y) == (px, py), start)
        scatter(g, rng, "l", 12, lambda x, y: next_to_wall(g, x, y) and away(x, y, 4))
        scatter(g, rng, "k", 9, lambda x, y: away(x, y, 5))
        scatter(g, rng, "%", 45, lambda x, y: next_to_wall(g, x, y) or rng.random() < 0.25)
        scatter(g, rng, "*", 12, lambda x, y: away(x, y, 6))
        mobs = []
        for _ in range(6):
            cands = [c for c in g.cells() if away(c[0], c[1], 16) and g.open_around(c[0], c[1], 1)]
            if cands:
                mobs += pack(g, rng, "w", rng.choice(cands), rng.randint(3, 5))
        mobs += scatter(g, rng, "a", 8, lambda x, y: away(x, y, 12))
        mobs += scatter(g, rng, "s", 7, lambda x, y: away(x, y, 12) and next_to_wall(g, x, y))
        mobs += scatter(g, rng, "y", 4, lambda x, y: away(x, y, 16))
        mobs += scatter(g, rng, "G", 3, lambda x, y: ud.get((x, y), 99) < 14 and ud.get((x, y), 0) > 3)
        mobs += pack(g, rng, "w", (fx + 2, fy + 2), 4)
        # resin thickens toward the Civic Hall
        for (cx, cy) in g.cells():
            d = ud.get((cx, cy))
            if d is not None and d < 22 and rng.random() < 0.3 * (1 - d / 22) ** 2:
                g.g[cy][cx] = "j"
        cont = scatter(g, rng, "c", 6, lambda x, y: away(x, y, 8))
        cont += scatter(g, rng, "C", 1, lambda x, y: away(x, y, 30))
        logs = scatter(g, rng, "J", 1, lambda x, y: far * 0.2 < dist.get((x, y), 0) < far * 0.45 and next_to_wall(g, x, y))
        if not logs:
            continue
        jx, jy = logs[0]
        ok, why = validate(g, (sx + 1, sy), [(sx, sy), (ux, uy), (ax, ay), (jx, jy)] + escort + mobs + cont)
        if not ok:
            continue
        meta = {
            "variant": variant,
            "name": ["Main Street", "Rail Yards", "Old Quarter"][variant - 1],
            "rooms": {"arrival": [sx - 1, sy - 2, sx + 3, sy + 2], "hall_door": [ux - 1, uy - 1, ux + 1, uy + 1], "fountain": [fx - 3, fy - 3, fx + 3, fy + 3]},
            "dirs": {"lt_dir": compass(ax - jx, ay - jy), "hall_dir": compass(ux - sx, uy - sy)},
        }
        return g, meta
    raise SystemExit("streets variant %d: no valid layout" % variant)


# ---------------------------------------------------------------- Civic Hall

def gen_hall():
    rng = random.Random(5150)
    W, H = 58, 44
    g = CityGrid(W, H, "#")
    rooms = {
        "foyer": (3, 17, 12, 26),
        "hallway": (14, 20, 44, 23),
        "office_n": (16, 4, 27, 15),
        "council": (30, 3, 53, 16),
        "office_s": (16, 28, 27, 39),
        "archive": (32, 28, 52, 40),
    }
    for (x0, y0, x1, y1) in rooms.values():
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                g.g[y][x] = "."
    for y in range(20, 24):
        g.g[y][13] = "_"                                   # foyer -> hallway
    for (x, y0, y1) in [(21, 16, 19), (40, 17, 19), (21, 24, 27), (42, 24, 27)]:
        for y in range(y0, y1 + 1):
            g.g[y][x] = "_"
            g.g[y][x + 1] = "_"
    ux, uy = 4, 21
    g.g[uy][ux] = "U"
    g.g[uy][ux + 2] = "@"
    for (x, y) in [(5, 18), (10, 18), (5, 25), (10, 25), (20, 21), (33, 21), (42, 21), (21, 9), (41, 9), (21, 33), (42, 34)]:
        g.g[y][x] = "l"
    # the three governors, cocooned: council chamber, north office, archive
    govs = [(48, 9), (18, 6), (49, 37)]
    for (x, y) in govs:
        g.g[y][x] = "O"
    for (x, y), ch in [((32, 5), "o"), ((33, 5), "o"), ((24, 30), "g"), ((25, 30), "g"), ((35, 30), "o"),
                       ((36, 30), "o"), ((44, 38), "c"), ((18, 37), "c"), ((52, 4), "C"), ((7, 24), "k"), ((30, 22), "k")]:
        g.g[y][x] = ch
    eggs = []
    for (cx, cy, n) in [(46, 10, 6), (20, 8, 3), (46, 36, 4), (24, 34, 3)]:
        for k in range(n):
            a = k * math.tau / n
            x, y = int(round(cx + math.cos(a) * 4)), int(round(cy + math.sin(a) * 3))
            if g.get(x, y) == ".":
                g.g[y][x] = "e"
                eggs.append((x, y))
    mobs = pack(g, rng, "w", (25, 21), 4) + pack(g, rng, "w", (40, 9), 5) + pack(g, rng, "w", (40, 34), 4)
    mobs += scatter(g, rng, "y", 3, lambda x, y: x > 28 and g.get(x, y) == ".")
    mobs += scatter(g, rng, "G", 2, lambda x, y: x > 34 and y < 16 and g.get(x, y) == ".")
    mobs += scatter(g, rng, "a", 2, lambda x, y: 14 <= x <= 44 and 20 <= y <= 23)
    for (x, y) in [c for c in g.cells(".") if rng.random() < 0.12 and c[0] > 14]:
        g.g[y][x] = "j"
    ok, why = validate(g, (ux + 2, uy), [(ux, uy)] + govs + eggs + mobs)
    if not ok:
        raise SystemExit("hall: " + why)
    meta = {"name": "Civic Hall", "rooms": {k: list(v) for k, v in rooms.items()}, "dirs": {}}
    return g, meta


def write(name, g, meta):
    base = os.path.join(OUT, name)
    open(base + ".txt", "w").write(g.text())
    json.dump(meta, open(base + ".json", "w"), indent=1)
    counts = {c: sum(r.count(c) for r in g.g) for c in "AawsyGeOnqxjcCJl"}
    print("%s: %s  %s" % (name, meta["name"], " ".join("%s=%d" % kv for kv in counts.items() if kv[1])))


def main():
    write("lastwater_port", *gen_port())
    for v in range(1, VARIANTS + 1):
        write("lastwater_streets_%d" % v, *gen_streets(v))
    write("lastwater_hall", *gen_hall())


if __name__ == "__main__":
    main()
