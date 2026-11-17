#!/usr/bin/env python3
"""Generates the Kharon Outpost layout variants (Diablo II style: a finite set
of layouts built from hand-designed room types, so players learn to recognise
"oh, it's this map").

  data/maps/outpost_<n>.txt   ASCII map (legend below, see scripts/world/level.gd)
  data/maps/outpost_<n>.json  metadata: layout name, room rectangles, and the
                              screen-relative compass directions used by mission
                              / terminal text ({gen_dir}, {labs_dir}, ...)

Variant 1 is the original hand-placed outpost. Variants 2..N are assembled
from room templates: the mission rooms form a tree (pad -> atrium -> generator,
atrium -E-> labs -R-> xenolab, labs|xenolab -S-> security core -V-> vault, plus
filler rooms) embedded on a coarse grid, joined by dog-leg corridors and
decorated by per-room-type recipes. A tree means locked bulkheads can't be
bypassed. Every candidate is validated (mission order reachable, every floor
tile reachable) and duplicate layouts are rejected.

Legend:
  ' ' void   '#' wall   '.' room floor   '_' corridor grating   ',' exterior ground
  '@' player start   d/r/h enemies (drone/researcher/heavy)   'B' boss
  c crate  C strongbox  o obstacle  p pillar  g machinery  t specimen tank
  l light  k corpse  b blood  v steam vent  z sparks
  D door   E door (needs power)   R door (needs research)   S door (needs cause)   V door (needs boss)
  0-9 terminals (see data/terminals.json)   X exit zone

Run: python3 tools/gen_maps.py   (deterministic; rewrites data/maps/)
"""
import collections
import json
import math
import os
import random

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', 'data', 'maps')
VARIANTS = 6
NAMES = ["Survey Plan Aleph", "Bastion Plan Kappa", "Reliquary Plan Sigma",
         "Foundry Plan Tau", "Cloister Plan Omicron", "Ossuary Plan Vex"]

SOLID = set('# cCopgt0123456789')
LOCK = {'E': 'power', 'R': 'research', 'S': 'cause', 'V': 'boss'}
FLOOR = '.,_'


# ---------------------------------------------------------------- grid

class Grid:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.g = [[' '] * w for _ in range(h)]

    def get(self, x, y):
        return self.g[y][x] if 0 <= x < self.w and 0 <= y < self.h else ' '

    def set(self, x, y, ch):
        self.g[y][x] = ch

    def fill(self, r, ch):
        x0, y0, x1, y1 = r
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.g[y][x] = ch

    def add_walls(self):
        for y in range(self.h):
            for x in range(self.w):
                if self.g[y][x] != ' ':
                    continue
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        c = self.get(x + dx, y + dy)
                        if c not in (' ', '#'):
                            self.g[y][x] = '#'

    def text(self):
        return '\n'.join(''.join(row).rstrip() for row in self.g) + '\n'


def rect_pts(x0, y0, x1, y1):
    return [(x, y) for y in range(y0, y1 + 1) for x in range(x0, x1 + 1)]


def center(r):
    return ((r[0] + r[2]) / 2.0, (r[1] + r[3]) / 2.0)


def compass(a, b):
    """Screen-relative direction from room a to room b in the isometric view."""
    (ax, ay), (bx, by) = center(a), center(b)
    dx, dy = bx - ax, by - ay
    sx, sy = dx - dy, (dx + dy) / 2.0
    ang = math.degrees(math.atan2(-sy, sx)) % 360.0
    names = ['east', 'north-east', 'north', 'north-west', 'west', 'south-west', 'south', 'south-east']
    return names[int((ang + 22.5) // 45) % 8]


def directions(rooms, core_parent):
    return {
        'gen_dir': compass(rooms['atrium'], rooms['generator']),
        'labs_dir': compass(rooms['atrium'], rooms['labs']),
        'xeno_dir': compass(rooms['labs'], rooms['xenolab']),
        'core_dir': compass(rooms[core_parent], rooms['arena']),
        'core_parent': 'labs' if core_parent == 'labs' else 'Xenolab',
        'vault_dir': compass(rooms['arena'], rooms['containment']),
    }


# ---------------------------------------------------------------- validation

def validate(grid):
    """Mission objectives reachable in order, and nothing walled off."""
    W, H, g = grid.w, grid.h, grid.g
    starts = [(x, y) for y in range(H) for x in range(W) if g[y][x] == '@']
    if len(starts) != 1:
        return False, "player start"
    start = starts[0]

    def reach(flags):
        seen = {start}
        q = collections.deque([start])
        while q:
            x, y = q.popleft()
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if (nx, ny) in seen or not (0 <= nx < W and 0 <= ny < H):
                    continue
                c = g[ny][nx]
                if c in SOLID or (c in LOCK and LOCK[c] not in flags):
                    continue
                seen.add((nx, ny))
                q.append((nx, ny))
        return seen

    def touches(seen, ch):
        pts = [(x, y) for y in range(H) for x in range(W) if g[y][x] == ch]
        return bool(pts) and all((x, y) in seen or any((x + dx, y + dy) in seen for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))) for x, y in pts)

    flags = set()
    for need, flag in (('2', 'power'), ('3', 'research'), ('4', 'cause'), ('B', 'boss'), ('X', None)):
        s = reach(flags)
        if not touches(s, need):
            return False, f"{need} unreachable with {sorted(flags)}"
        # the next stage must still be locked away
        if flag and need in '234B':
            nxt = {'2': '3', '3': '4', '4': 'B', 'B': 'X'}[need]
            if touches(s, nxt):
                return False, f"{nxt} reachable before {flag}"
        if flag:
            flags.add(flag)
    s = reach(flags)
    for ch in 'cCdrh0123456789':
        pts = [(x, y) for y in range(H) for x in range(W) if g[y][x] == ch]
        if pts and not touches(s, ch):
            return False, f"{ch} unreachable"
    for y in range(H):
        for x in range(W):
            c = g[y][x]
            if c not in SOLID and c != ' ' and (x, y) not in s:
                return False, f"isolated floor at {x},{y}"
    return True, "ok"


# ---------------------------------------------------------------- variant 1: original

def original():
    grid = Grid(102, 90)
    ROOMS = [
        ("pad",          40, 76, 69, 87, ','),
        ("entrance",     53, 70, 56, 75, '_'),
        ("atrium",       42, 54, 67, 69, '.'),
        ("west_corr",    26, 60, 41, 62, '_'),
        ("generator",     6, 46, 25, 68, '.'),
        ("barracks_con", 32, 63, 33, 64, '_'),
        ("barracks",     28, 65, 38, 74, '.'),
        ("east_corr",    68, 60, 83, 62, '_'),
        ("medbay",       84, 53, 97, 66, '.'),
        ("north_corr",   53, 44, 56, 53, '_'),
        ("labs",         40, 30, 69, 43, '.'),
        ("storage_con",  38, 35, 39, 37, '_'),
        ("storage",      24, 31, 37, 41, '.'),
        ("xeno_corr",    70, 35, 79, 37, '_'),
        ("xenolab",      80, 25, 99, 45, '.'),
        ("sec_corr",     53, 22, 56, 29, '_'),
        ("arena",        34,  6, 75, 21, '.'),
        ("vault_corr",   20, 12, 33, 15, '_'),
        ("containment",   4,  5, 19, 22, '.'),
    ]
    for _, x0, y0, x1, y1, ch in ROOMS:
        grid.fill((x0, y0, x1, y1), ch)
    grid.add_walls()

    def put(ch, pts):
        for (x, y) in pts:
            assert grid.get(x, y) in FLOOR, f"cannot place {ch} at {x},{y}: {grid.get(x, y)!r}"
            grid.set(x, y, ch)

    def rect(x0, y0, x1, y1):
        return rect_pts(x0, y0, x1, y1)

    # --- Doors ---
    put('D', rect(53, 72, 56, 72))          # airlock
    put('D', rect(34, 60, 34, 62))          # west corridor bulkhead
    put('D', rect(32, 63, 33, 63))          # barracks
    put('D', rect(38, 35, 38, 37))          # storage
    put('D', rect(83, 60, 83, 62))          # medbay
    put('E', rect(53, 49, 56, 49))          # power-locked
    put('R', rect(75, 35, 75, 37))          # research-locked
    put('S', rect(53, 25, 56, 25))          # cause-locked (security core)
    put('V', rect(27, 12, 27, 15))          # boss-locked (vault)
    # --- Landing pad ---
    put('@', [(55, 84)])
    put('l', [(44, 78), (65, 78), (44, 85), (65, 85), (53, 71)])
    put('k', [(60, 80)])
    put('b', [(59, 81), (61, 79)])
    put('c', [(42, 86)])
    put('o', [(47, 80), (48, 80), (63, 83)])
    # --- Atrium ---
    put('p', [(47, 58), (62, 58), (47, 65), (62, 65)])
    put('r', [(50, 60), (58, 62), (60, 57)])
    put('d', [(64, 63)])
    put('1', [(44, 55)])
    put('9', [(65, 55)])
    put('c', [(66, 68), (43, 68)])
    put('k', [(52, 57), (57, 59)])
    put('b', [(53, 58), (56, 60), (51, 66)])
    put('l', [(45, 62), (64, 61), (55, 55)])
    # --- West corridor ---
    put('d', [(30, 61)])
    put('l', [(38, 61)])
    # --- Generator hall ---
    for (gx, gy) in [(10, 52), (19, 52), (10, 60), (19, 60)]:
        put('g', rect(gx, gy, gx + 2, gy + 2))
    put('2', [(15, 47)])
    put('h', [(15, 58)])
    put('d', [(8, 57), (23, 57)])
    put('r', [(15, 65), (8, 66)])
    put('C', [(7, 47)])
    put('v', [(15, 56)])
    put('z', [(13, 55)])
    put('l', [(8, 49), (23, 49), (8, 64), (23, 64)])
    put('k', [(14, 50)])
    put('b', [(13, 50), (16, 51)])
    # --- Barracks ---
    put('r', [(31, 70), (36, 72)])
    put('o', [(29, 67), (29, 68), (29, 71), (29, 72), (37, 67), (37, 68)])
    put('8', [(35, 66)])
    put('c', [(37, 74), (28, 74)])
    put('l', [(33, 69)])
    put('k', [(34, 71)])
    # --- East corridor / medbay ---
    put('l', [(76, 61)])
    put('r', [(80, 61)])
    put('r', [(88, 58), (94, 62), (90, 64)])
    put('5', [(90, 54)])
    put('c', [(96, 54), (96, 65)])
    put('o', [(86, 56), (86, 57), (86, 61), (86, 62)])
    put('l', [(90, 59)])
    put('k', [(93, 57)])
    put('b', [(92, 58), (89, 61)])
    # --- North corridor / labs ---
    put('l', [(54, 46)])
    put('3', [(62, 31)])
    put('9', [(42, 31)])
    put('d', [(48, 36), (60, 41)])
    put('r', [(45, 41), (66, 35)])
    put('h', [(55, 38)])
    put('o', rect(44, 34, 47, 34) + rect(63, 38, 66, 38) + rect(44, 39, 46, 39))
    put('l', [(50, 32), (60, 32), (50, 42), (60, 42)])
    put('k', [(58, 34)])
    put('c', [(68, 42), (41, 42)])
    # --- Storage ---
    put('6', [(26, 32)])
    put('r', [(31, 38)])
    put('c', [(25, 40), (36, 32)])
    put('C', [(36, 40)])
    put('o', rect(28, 34, 30, 35) + [(33, 37), (33, 38)])
    put('l', [(31, 36)])
    # --- Xeno corridor / xenolab ---
    put('l', [(72, 36)])
    put('4', [(95, 26)])
    put('7', [(82, 44)])
    put('r', [(85, 30), (92, 33), (88, 40), (96, 42)])
    put('h', [(90, 37)])
    put('d', [(84, 36)])
    put('t', [(84, 26), (87, 26), (90, 26), (98, 31), (98, 35), (98, 39)])
    put('l', [(85, 34), (94, 34), (85, 43), (94, 43)])
    put('k', [(93, 38), (82, 30)])
    put('b', [(92, 39), (83, 31)])
    put('C', [(99, 44)])
    put('z', [(88, 44)])
    put('v', [(96, 28)])
    # --- Security corridor / arena ---
    put('d', [(54, 23)])
    put('B', [(55, 11)])
    put('p', [(40, 9), (69, 9), (40, 18), (69, 18)])
    put('l', [(45, 7), (65, 7), (45, 20), (65, 20), (35, 14), (74, 14)])
    put('k', [(50, 19)])
    put('b', [(49, 19)])
    # --- Containment vault ---
    put('X', rect(5, 12, 7, 15))
    put('0', [(18, 6)])
    put('t', [(8, 6), (15, 6), (8, 21), (15, 21)])
    put('l', [(12, 8), (12, 19)])

    rooms = {n: (x0, y0, x1, y1) for n, x0, y0, x1, y1, _ in ROOMS}
    return grid, rooms, 'labs'


# ---------------------------------------------------------------- variants 2..N: room templates

CW, CH, GC, GR = 28, 24, 5, 4      # macro cell size (tiles) and grid
MARGIN = 3
# kind: (min w, max w, min h, max h, cells spanned horizontally)
SPECS = {
    'pad':         (18, 22, 9, 12, 1),
    'atrium':      (17, 22, 13, 16, 1),
    'generator':   (17, 22, 14, 18, 1),
    'labs':        (18, 22, 11, 15, 1),
    'xenolab':     (17, 22, 14, 17, 1),
    'arena':       (34, 44, 14, 17, 2),
    'containment': (14, 18, 12, 16, 1),
    'barracks':    (10, 14, 8, 11, 1),
    'storage':     (11, 15, 9, 11, 1),
    'medbay':      (11, 15, 10, 13, 1),
    'chapel':      (11, 15, 10, 14, 1),
    'cargo':       (12, 17, 9, 13, 1),
}
FLOOR_OF = {'pad': ','}


class Room:
    def __init__(self, name, cells):
        self.name = name
        self.cells = cells
        self.rect = None
        self.openings = []   # floor tiles just inside each doorway

    @property
    def x0(self): return self.rect[0]
    @property
    def y0(self): return self.rect[1]
    @property
    def x1(self): return self.rect[2]
    @property
    def y1(self): return self.rect[3]


def generate(seed):
    rng = random.Random(seed)
    core_parent = rng.choice(['labs', 'xenolab'])
    tree = [('atrium', 'pad', 'D'), ('generator', 'atrium', rng.choice(['D', 'D', ''])),
            ('labs', 'atrium', 'E'), ('xenolab', 'labs', 'R'),
            ('arena', core_parent, 'S'), ('containment', 'arena', 'V')]
    fillers = ['barracks', 'storage', 'medbay'] + rng.sample(['chapel', 'cargo'], rng.randint(0, 2))
    rng.shuffle(fillers)
    for f in fillers:
        tree.append((f, rng.choice(['atrium', 'atrium', 'generator', 'labs', 'xenolab']), rng.choice(['D', 'D', ''])))

    # --- embed the room tree on the macro grid
    occ = {}
    rooms = {}
    pad_cell = (rng.randrange(GC), GR - 1)
    occ[pad_cell] = 'pad'
    rooms['pad'] = Room('pad', [pad_cell])
    edges = []
    for name, parent, gate in tree:
        span = SPECS[name][4]
        options = []
        for pc in rooms[parent].cells:
            for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nc = (pc[0] + d[0], pc[1] + d[1])
                if span == 1:
                    groups = [[nc]]
                else:
                    groups = [[nc, (nc[0] + 1, nc[1])], [(nc[0] - 1, nc[1]), nc]]
                for grp in groups:
                    if all(0 <= c[0] < GC and 0 <= c[1] < GR and c not in occ for c in grp):
                        options.append((grp, pc, nc))
        if not options:
            return None
        grp, pc, nc = rng.choice(options)
        for c in grp:
            occ[c] = name
        rooms[name] = Room(name, grp)
        edges.append((parent, name, pc, nc, gate))

    # --- size and place each room inside its cells
    for room in rooms.values():
        wmin, wmax, hmin, hmax, _ = SPECS[room.name]
        cx0 = min(c[0] for c in room.cells) * CW
        cx1 = (max(c[0] for c in room.cells) + 1) * CW - 1
        cy0 = room.cells[0][1] * CH
        cy1 = cy0 + CH - 1
        avail_w = cx1 - cx0 + 1 - 2 * MARGIN
        avail_h = cy1 - cy0 + 1 - 2 * MARGIN
        w = rng.randint(wmin, min(wmax, avail_w))
        h = rng.randint(hmin, min(hmax, avail_h))
        x0 = rng.randint(cx0 + MARGIN, cx1 - MARGIN - w + 1)
        y0 = rng.randint(cy0 + MARGIN, cy1 - MARGIN - h + 1)
        room.rect = (x0, y0, x0 + w - 1, y0 + h - 1)

    grid = Grid(GC * CW, GR * CH)
    for room in rooms.values():
        grid.fill(room.rect, FLOOR_OF.get(room.name, '.'))

    # --- corridors (dog-legs through the gap between cells); door on the child side
    doors = []
    corridors = []
    for parent, child, pc, nc, gate in edges:
        P, C = rooms[parent], rooms[child]
        tiles = []
        if pc[1] == nc[1]:   # horizontal neighbours
            left, right = (P, C) if nc[0] > pc[0] else (C, P)
            bx = max(pc[0], nc[0]) * CW
            lo, hi = max(left.y0, right.y0), min(left.y1, right.y1) - 2
            if lo <= hi and rng.random() < 0.55:
                ly = ry = rng.randint(lo, hi)
            else:
                ly = rng.randint(left.y0, left.y1 - 2)
                ry = rng.randint(right.y0, right.y1 - 2)
            tiles += rect_pts(left.x1 + 1, ly, bx + 1, ly + 2)
            tiles += rect_pts(bx - 1, min(ly, ry), bx + 1, max(ly, ry) + 2)
            tiles += rect_pts(bx - 1, ry, right.x0 - 1, ry + 2)
            if C is right:
                door = rect_pts(C.x0 - 1, ry, C.x0 - 1, ry + 2)
                C.openings += rect_pts(C.x0, ry, C.x0, ry + 2)
                P.openings += rect_pts(P.x1, ly, P.x1, ly + 2)
            else:
                door = rect_pts(C.x1 + 1, ly, C.x1 + 1, ly + 2)
                C.openings += rect_pts(C.x1, ly, C.x1, ly + 2)
                P.openings += rect_pts(P.x0, ry, P.x0, ry + 2)
        else:                # vertical neighbours
            top, bot = (P, C) if nc[1] > pc[1] else (C, P)
            by = max(pc[1], nc[1]) * CH
            lo, hi = max(top.x0, bot.x0), min(top.x1, bot.x1) - 2
            if lo <= hi and rng.random() < 0.55:
                tx = bx_ = rng.randint(lo, hi)
            else:
                tx = rng.randint(top.x0, top.x1 - 2)
                bx_ = rng.randint(bot.x0, bot.x1 - 2)
            tiles += rect_pts(tx, top.y1 + 1, tx + 2, by + 1)
            tiles += rect_pts(min(tx, bx_), by - 1, max(tx, bx_) + 2, by + 1)
            tiles += rect_pts(bx_, by - 1, bx_ + 2, bot.y0 - 1)
            if C is bot:
                door = rect_pts(bx_, C.y0 - 1, bx_ + 2, C.y0 - 1)
                C.openings += rect_pts(bx_, C.y0, bx_ + 2, C.y0)
                P.openings += rect_pts(tx, P.y1, tx + 2, P.y1)
            else:
                door = rect_pts(tx, C.y1 + 1, tx + 2, C.y1 + 1)
                C.openings += rect_pts(tx, C.y1, tx + 2, C.y1)
                P.openings += rect_pts(bx_, P.y0, bx_ + 2, P.y0)
        for (x, y) in tiles:
            if grid.get(x, y) == ' ':
                grid.set(x, y, '_')
        corridors.append(tiles)
        if gate:
            doors.append((gate, door))

    grid.add_walls()
    for gate, pts in doors:
        for (x, y) in pts:
            assert grid.get(x, y) in FLOOR, (seed, gate, x, y, grid.get(x, y))
            grid.set(x, y, gate)

    deco = Decorator(grid, rng)
    for room in rooms.values():
        deco.room(room)
    for tiles in corridors:
        deco.corridor(tiles)

    rects = {n: r.rect for n, r in rooms.items()}
    signature = tuple(sorted((n, tuple(r.cells)) for n, r in rooms.items() if n in ('pad', 'atrium', 'generator', 'labs', 'xenolab', 'arena', 'containment')))
    return grid, rects, core_parent, signature


class Decorator:
    """Per-room-type recipes: set pieces, props, story terminals and enemies."""

    def __init__(self, grid, rng):
        self.g = grid
        self.rng = rng
        self.keep = set()

    def free(self, x, y):
        return self.g.get(x, y) in '.,_' and (x, y) not in self.keep

    def put(self, ch, x, y):
        if self.free(x, y):
            self.g.set(x, y, ch)
            return True
        return False

    def scatter(self, room, ch, n, inset=1, tries=60):
        r = room.rect
        placed = 0
        for _ in range(tries):
            if placed >= n:
                break
            x = self.rng.randint(r[0] + inset, r[2] - inset)
            y = self.rng.randint(r[1] + inset, r[3] - inset)
            if self.put(ch, x, y):
                placed += 1
        return placed

    def on_wall(self, room, ch, side='n', n=1):
        """Terminals / tanks against a wall, spread out, clear of doorways."""
        r = room.rect
        if side in 'ns':
            y = r[1] if side == 'n' else r[3]
            xs = list(range(r[0] + 1, r[2]))
            pts = [(x, y) for x in xs]
        else:
            x = r[0] if side == 'w' else r[2]
            pts = [(x, y) for y in range(r[1] + 1, r[3])]
        self.rng.shuffle(pts)
        placed = []
        for (x, y) in pts:
            if len(placed) >= n:
                break
            if all(abs(x - px) + abs(y - py) > 2 for px, py in placed) and self.put(ch, x, y):
                placed.append((x, y))
        return placed

    def lamps(self, room, inset=2):
        r = room.rect
        for (x, y) in ((r[0] + inset, r[1] + inset), (r[2] - inset, r[1] + inset),
                       (r[0] + inset, r[3] - inset), (r[2] - inset, r[3] - inset)):
            self.put('l', x, y)

    def gore(self, room, corpses, blood):
        for _ in range(corpses):
            r = room.rect
            x = self.rng.randint(r[0] + 2, r[2] - 2)
            y = self.rng.randint(r[1] + 2, r[3] - 2)
            if self.put('k', x, y):
                for (bx, by) in ((x - 1, y), (x + 1, y + 1)):
                    self.put('b', bx, by)
        self.scatter(room, 'b', blood, inset=1)

    def corridor(self, tiles):
        floor = [t for t in tiles if self.g.get(*t) == '_']
        if len(floor) > 24:
            mid = floor[len(floor) // 2]
            self.put('l', *mid)
            if self.rng.random() < 0.45:
                self.put('d', *floor[len(floor) // 3])

    def room(self, room):
        r = room.rect
        for (ox, oy) in room.openings:
            for dy in range(-2, 3):
                for dx in range(-2, 3):
                    self.keep.add((ox + dx, oy + dy))
        getattr(self, 'room_' + room.name)(room)

    # --- recipes ---------------------------------------------------------

    def room_pad(self, room):
        r = room.rect
        # start on the far side from the airlock
        far = max(((x, y) for x in range(r[0] + 2, r[2] - 1) for y in range(r[1] + 2, r[3] - 1)),
                  key=lambda p: min(abs(p[0] - ox) + abs(p[1] - oy) for ox, oy in room.openings))
        self.put('@', *far)
        self.keep |= {(far[0] + dx, far[1] + dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1)}
        # open landing zone through the middle of the pad: room to move from the start
        cy = (r[1] + r[3]) // 2
        self.keep |= set(rect_pts(r[0] + 1, cy - 3, r[2] - 1, cy + 3))
        self.lamps(room, 1)
        self.gore(room, 1, 2)
        self.scatter(room, 'c', 1)
        self.scatter(room, 'o', 3, inset=2)

    def room_atrium(self, room):
        r = room.rect
        for (x, y) in ((r[0] + 4, r[1] + 4), (r[2] - 4, r[1] + 4), (r[0] + 4, r[3] - 4), (r[2] - 4, r[3] - 4)):
            self.put('p', x, y)
        self.on_wall(room, '1', 'n')
        self.on_wall(room, '9', self.rng.choice('ns'))
        self.scatter(room, 'r', 3, inset=2)
        self.scatter(room, 'd', 1, inset=2)
        self.scatter(room, 'c', 2)
        self.gore(room, 2, 3)
        self.put('l', (r[0] + r[2]) // 2, (r[1] + r[3]) // 2)
        self.lamps(room, 2)

    def room_generator(self, room):
        r = room.rect
        for (x, y) in ((r[0] + 3, r[1] + 4), (r[2] - 5, r[1] + 4), (r[0] + 3, r[3] - 5), (r[2] - 5, r[3] - 5)):
            if all(self.free(x + dx, y + dy) for dx in range(3) for dy in range(3)):
                for dx in range(3):
                    for dy in range(3):
                        self.put('g', x + dx, y + dy)
        self.on_wall(room, '2', 'n')
        cx, cy = (r[0] + r[2]) // 2, (r[1] + r[3]) // 2
        self.put('h', cx, cy + 1)
        self.put('v', cx, cy - 1)
        self.scatter(room, 'z', 1, inset=2)
        self.scatter(room, 'd', 2, inset=2)
        self.scatter(room, 'r', 2, inset=2)
        self.scatter(room, 'C', 1)
        self.gore(room, 1, 2)
        self.lamps(room, 2)

    def room_labs(self, room):
        r = room.rect
        for _ in range(3):   # lab benches
            ln = self.rng.randint(3, 4)
            x = self.rng.randint(r[0] + 3, r[2] - 3 - ln)
            y = self.rng.randint(r[1] + 3, r[3] - 3)
            if all(self.free(x + i, y + dy) for i in range(-1, ln + 1) for dy in (-1, 0, 1)):
                for i in range(ln):
                    self.put('o', x + i, y)
        self.on_wall(room, '3', 'n')
        self.on_wall(room, '9', 's')
        self.scatter(room, 'd', 2, inset=2)
        self.scatter(room, 'r', 2, inset=2)
        self.scatter(room, 'h', 1, inset=3)
        self.scatter(room, 'c', 2)
        self.gore(room, 1, 2)
        self.lamps(room, 2)

    def room_xenolab(self, room):
        self.on_wall(room, 't', 'n', 3)
        self.on_wall(room, 't', self.rng.choice('ew'), 3)
        self.on_wall(room, '4', 'n')
        self.on_wall(room, '7', 's')
        self.scatter(room, 'r', 4, inset=2)
        self.scatter(room, 'h', 1, inset=3)
        self.scatter(room, 'd', 1, inset=2)
        self.scatter(room, 'C', 1)
        self.scatter(room, 'z', 1)
        self.scatter(room, 'v', 1, inset=2)
        self.gore(room, 2, 2)
        self.lamps(room, 2)

    def room_arena(self, room):
        r = room.rect
        cx = (r[0] + r[2]) // 2
        by = r[1] + max(4, int((r[3] - r[1]) * 0.35))
        self.put('B', cx, by)
        self.keep |= {(cx + dx, by + dy) for dx in range(-3, 4) for dy in range(-3, 4)}
        for (x, y) in ((r[0] + 6, r[1] + 3), (r[2] - 6, r[1] + 3), (r[0] + 6, r[3] - 3), (r[2] - 6, r[3] - 3)):
            self.put('p', x, y)
        for (x, y) in ((r[0] + 11, r[1] + 1), (r[2] - 11, r[1] + 1), (r[0] + 11, r[3] - 1),
                       (r[2] - 11, r[3] - 1), (r[0] + 1, (r[1] + r[3]) // 2), (r[2] - 1, (r[1] + r[3]) // 2)):
            self.put('l', x, y)
        self.gore(room, 1, 2)

    def room_containment(self, room):
        r = room.rect
        # extraction zone against the wall furthest from the vault door
        ox = sum(p[0] for p in room.openings) / max(1, len(room.openings))
        oy = sum(p[1] for p in room.openings) / max(1, len(room.openings))
        cx, cy = (r[0] + r[2]) / 2.0, (r[1] + r[3]) / 2.0
        if abs(ox - cx) / (r[2] - r[0]) > abs(oy - cy) / (r[3] - r[1]):
            x0 = r[0] + 1 if ox > cx else r[2] - 3
            y0 = int(cy) - 2
            pts = rect_pts(x0, y0, x0 + 2, y0 + 3)
        else:
            y0 = r[1] + 1 if oy > cy else r[3] - 3
            x0 = int(cx) - 2
            pts = rect_pts(x0, y0, x0 + 3, y0 + 2)
        for (x, y) in pts:
            self.put('X', x, y)
        self.keep |= {(x + dx, y + dy) for (x, y) in pts for dx in (-1, 0, 1) for dy in (-1, 0, 1)}
        self.on_wall(room, '0', 'n')
        for (x, y) in ((r[0] + 1, r[1] + 1), (r[2] - 1, r[1] + 1), (r[0] + 1, r[3] - 1), (r[2] - 1, r[3] - 1)):
            self.put('t', x, y)
        self.put('l', (r[0] + r[2]) // 2, r[1] + 2)
        self.put('l', (r[0] + r[2]) // 2, r[3] - 2)

    def room_barracks(self, room):
        r = room.rect
        for x in (r[0], r[2]):    # bunks along the side walls
            for y in range(r[1] + 2, r[3] - 1, 3):
                self.put('o', x, y)
                self.put('o', x, y + 1)
        self.on_wall(room, '8', 'n')
        self.scatter(room, 'r', 2, inset=2)
        self.scatter(room, 'c', 2)
        self.gore(room, 1, 1)
        self.put('l', (r[0] + r[2]) // 2, (r[1] + r[3]) // 2)

    def room_storage(self, room):
        self.on_wall(room, '6', 'n')
        self.scatter(room, 'o', 4, inset=2)
        self.scatter(room, 'c', 2)
        self.scatter(room, 'C', 1)
        self.scatter(room, 'r', 1, inset=2)
        r = room.rect
        self.put('l', (r[0] + r[2]) // 2, (r[1] + r[3]) // 2)

    def room_medbay(self, room):
        r = room.rect
        for y in range(r[1] + 2, r[3] - 1, 4):   # medicae slabs
            self.put('o', r[0] + 2, y)
            self.put('o', r[0] + 2, y + 1)
        self.on_wall(room, '5', 'n')
        self.scatter(room, 'r', 3, inset=2)
        self.scatter(room, 'c', 2)
        self.gore(room, 1, 2)
        self.put('l', (r[0] + r[2]) // 2, (r[1] + r[3]) // 2)

    def room_chapel(self, room):
        r = room.rect
        for (x, y) in ((r[0] + 3, r[1] + 3), (r[2] - 3, r[1] + 3), (r[0] + 3, r[3] - 3), (r[2] - 3, r[3] - 3)):
            self.put('p', x, y)
        self.gore(room, 3, 4)
        self.scatter(room, 'h' if self.rng.random() < 0.5 else 'd', 1, inset=3)
        self.scatter(room, 'C', 1)
        self.lamps(room, 2)

    def room_cargo(self, room):
        self.scatter(room, 'o', 6, inset=2)
        self.scatter(room, 'c', 3)
        self.scatter(room, 'd', 2, inset=2)
        self.scatter(room, 'z', 1)
        r = room.rect
        self.put('l', (r[0] + r[2]) // 2, (r[1] + r[3]) // 2)


# ---------------------------------------------------------------- main

def write(n, grid, rooms, core_parent):
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, f'outpost_{n}.txt'), 'w') as f:
        f.write(grid.text())
    meta = {
        'variant': n,
        'name': NAMES[n - 1],
        'rooms': {k: list(v) for k, v in rooms.items()},
        'dirs': directions(rooms, core_parent),
    }
    with open(os.path.join(OUT, f'outpost_{n}.json'), 'w') as f:
        json.dump(meta, f, indent=1)


def main():
    grid, rooms, core_parent = original()
    ok, why = validate(grid)
    assert ok, why
    write(1, grid, rooms, core_parent)
    print('variant 1: original layout')
    seen = set()
    n = 2
    seed = 1000
    rejected = collections.Counter()
    while n <= VARIANTS:
        seed += 1
        res = generate(seed)
        if res is None:
            rejected['embedding'] += 1
            continue
        grid, rooms, core_parent, sig = res
        if sig in seen:
            rejected['duplicate'] += 1
            continue
        ok, why = validate(grid)
        if not ok:
            rejected[why.split(' ')[0]] += 1
            continue
        seen.add(sig)
        write(n, grid, rooms, core_parent)
        enemies = sum(row.count(c) for row in grid.g for c in 'drh')
        print(f'variant {n}: seed {seed}, {len(rooms)} rooms, {enemies} enemies, {grid.w}x{grid.h}')
        n += 1
    print('rejected candidates:', dict(rejected))


if __name__ == '__main__':
    main()
