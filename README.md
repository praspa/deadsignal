# Dead Signal

Grimdark sci-fi action RPG (Godot 4.5, GDScript, 2D isometric in the style of Diablo II). Built from `claude-requirements.md`.

All art is drawn procedurally in code (`_draw()`), so the project has no image assets and needs no import step.

## Run

```bash
godot --path . --headless --import   # import assets (first run / after changes)
godot --path .                       # play
godot -e --path .                    # open in the editor
```

Target is 1280x800 (Steam Deck) at 60 FPS with the GL Compatibility renderer.

## Controls

| Action | Keyboard / mouse | Controller |
|---|---|---|
| Move (8-dir, screen-relative) | WASD / arrows | Left stick |
| Aim | Mouse | Right stick (light aim assist) |
| Primary / secondary weapon | LMB / RMB | RT / LT |
| Tactical Roll | Space | A |
| Overcharge | Q | LB |
| Disruptor Pulse | F | RB |
| Reload / Interact / Stim | R / E / H | X / Y / D-Up |
| Swap primary ↔ secondary | X | D-Down |
| Inventory / Character | I or Tab / C | Back or D-Right / D-Left |
| Mission journal | J | Start, then Journal |
| Pause / Quick save / Quick load | Esc / F5 / F9 | Start |
| Show all loot names (hold) | Alt | L3 |
| Menus: move / select / back | Arrows / Enter / Esc | D-pad or left stick / A (PS Cross) / B (PS Circle) |

Movement is screen-relative: W moves up the screen, and diagonals follow the isometric grid, so they run along corridors.

## Outpost layouts

Like Diablo II, the outpost comes in a finite set of layouts, so players learn them ("oh, it's this map"). There are six:

- **Variant 1** is the original hand-placed map.
- **Variants 2–6** are assembled by `tools/gen_maps.py` from hand-designed room types and validated before they're kept.

The rooms are the generator hall, labs, Xenolab, security core, vault, barracks, storage, medbay, chapel and cargo bay. The mission rooms form a tree, so locked bulkheads can't be bypassed, and the tree is laid out on a coarse grid joined by bending corridors.

Each new game picks a random layout, never the one in your current save. The layout is stored in the save and announced when the game starts. Story text gets its compass directions from the layout (`{gen_dir}` and so on in `data/mission.json` and `data/terminals.json`), so "the generator hall is north-west of the atrium" is always true. To force a layout for testing, add `-- --variant N`.

## Ship and locations

A new game starts aboard the operative's assigned ship, the *Sable Mule*. It's the hub, the equivalent of a Diablo town: it has its own silver-blue look and bright, steady lighting (no flashlight), the operative carries no weapon and can't fire or use combat abilities aboard, a cargo locker in the hold stores items you don't want to carry, the crew stand at their posts (placeholders for now, they only talk), and the cockpit's nav console opens the star map. Each location is an entry in `data/locations.json` that names its map, lighting and music. A location's look is data too: `palette` remaps wall / floor / prop brightness onto a colour ramp (`shaders/luma_normal.gdshader`), plus `post` grade, `lamp_color`, `flashlight` and `steady_lights`. The ship map is `data/maps/ship.txt` (`N` = nav console, `L` = cargo locker, `Q T M F P` = crew from `data/crew.json`).

- **Star map** (`data/starmap.json`): a tree of known space drawn left to right (universe → galaxies → systems → planets / stations). Move the selection with the d-pad, stick, arrows or mouse; Accept flies the ship marker along the chart lines to an unlocked node, and Accept again (or Descend) drops you to that node's mission site. Locked nodes show as "Uncharted" and hide their children. The ship's position on the map is saved.
- **Crew services** (talk to them: crew screen, `scripts/ui/crew_ui.gd`): the Quartermaster trades (12-16 items of gear refreshed every session and every return from a mission, supplies, sell for 25%, "Sell all junk" for every Common item in one press, buyback of the last 10; `scripts/ui/trade_ui.gd`), the Medic heals for free and respecs attributes (first free, then 100 UC x level), the Fence sells sealed Weapon / Armour / Utility crates opened on the spot (better rarity odds), the Pilot opens the star map. Prices live in `ItemDB` (one formula). Each crew member has their own procedural look, prop, idle animation, accent light, a once-per-visit bark and progress-based lines (`data/crew.json`). Signal corruption / decryption is designed but deferred.
- **Death** on a mission fades out and the operative wakes aboard the ship in the **Lazarus Cradle** (medbay, map char `Z`), at full health. It costs 10% of carried UC and 5% of the current level's XP (never a whole level); the ship stays in orbit where you descended and the mission site keeps its state, so the way back is the star map. Revival autosaves.
- **Landing beacons** (Diablo's waypoints): reaching a zone's uplink beacon links it as a landing point of its star map node, permanently (flag `beacon:<zone>`). Descend then lists the node's landing points (undiscovered ones show as ???); with one, it lands directly. Kessar IV's hive has one. Nodes are linked by `requires` flags (mission done, `intel:*` nav data, access codes) and show why they're locked (`locked_reason`); finishing Kharon reveals the Halcyon System.
- **Travel** autosaves and drops you at the destination's start point. Floor loot and map state (kills, crates, doors) are kept per location.
- **Mission sites** have a return-shuttle beacon at the landing point that flies you back to the ship.
- **Universal Credits (UC, "creds")** drop from enemies, crates and bosses, are collected by walking over them, and show on the HUD and the inventory screen. There's nothing to spend them on yet.
- **Recall** (T / R3): a 2 s channel standing still; moving, firing, rolling, abilities or taking a hit interrupt it (3 s cooldown), otherwise it pulls you to the ship and leaves a recall beacon (60 s cooldown). The ship's teleport pad (cargo hold, map char `W`) drops you back on the beacon while the ship is still in orbit over that node.
- **Kessar IV — the Brood Queen** (first mission, `data/missions/kessar.json`): the Ashfall Flats surface and the Hive below, 3 random layouts each, built by `tools/gen_kessar.py` (`python3 tools/gen_kessar.py`). Find the resin sinkhole (the mining camp log hints at its direction, growth thickens near it), descend, kill the Queen, recall home for the 500 UC bounty; Belt Claim 7 unlocks. Creatures: Swarmlings, Spitters (acid pools), Broodguard (charge; dazed if they hit rock), Infested Miners, Ash Burrowers (ambush), egg clusters, and the three-phase Brood Queen (acid spray, summons, burrowing; Disruptor Pulse interrupts her).
- **Doctrines (skill trees, `data/doctrines.json`, K or pause menu):** the Combat Specialist's Gunline, Vanguard and Siegebreaker. One Doctrine point at levels 2, 5, 10 ... 40 (nine in all), single-rank skills, tiers needing 0 / 2 / 4 / 6 points in the tree, so a build is a real trade-off. Two ability slots (Q/LB, F/RB), a third at level 20 (G/B), changed aboard the ship only; Overcharge and Disruptor Pulse are basic training. All 21 skills are in: the Gunline (Overcharge, Steady Hands, Marked Target, Quick Hands, Deadeye, Hollow Points, Gunline Unbroken), the Vanguard (Disruptor Pulse, Iron Hide, Shoulder Charge, Bloodletter, Battle Litany, Unbreakable, Juggernaut) and the Siegebreaker (`scripts/player/ordnance.gd`: Concussion Grenade, Blast Discipline, Semtex Charge, Shrapnel, Incendiary Charge, Chain Reaction, Danger Close). A new operative starts with only Tactical Roll and their guns. The Medic's respec refunds Doctrine points too.
- **Act 1 order:** Kharon Outpost (intro; its debrief clears Last Water) -> **Last Water** on Kessar III -> Kessar IV (the Brood Queen). Monsters scale +15% health and damage per area level above 2.
- **Last Water** (`data/missions/lastwater.json`, maps by `tools/gen_lastwater.py`): a frontier city overrun by the Brood. Spaceport -> the streets (3 random street-grid layouts) -> the Civic Hall, joined by zone exits defined in `data/locations.json` (`"exits"`, chars `Y` / `U`; the hall door needs the access card). Kill Gutspike the Warden-Taker, a named champion Brood Lieutenant, for the card (a quest pickup), then cut the three cocooned governors free (`O`, interruptible 1.5 s). Their intel unlocks Kessar IV. New creatures: Infested Militia (bad shots), Wall Crawlers (drop from walls; watch for the shadow). City building wall style, wrecks / barricades / water towers, its own music. The Civic Hall has a landing beacon.
- **Re-entrant areas:** loading a save starts a new session aboard the ship, Diablo-style: every mission area is repopulated (monsters, bosses, containers) and re-rolls its layout; floor loot and the recall beacon are gone. Character, stash, UC, story progress and the star map persist; bounties and terminal XP are one-time. Each area has an `area_level` (Ashfall Flats 2, Hive 3, Kharon 5) that sets loot and creds; monster XP falls off 15% per level once you're more than 2 levels above it (min 5%). XP to next level is 100 x level^1.5.
- **Kharon Outpost** (the demo mission, frozen at git tag `demo-v1.0`) stays on the star map as a secondary / test destination. Extracting from Kharon flies you back to the ship.

## Mission (Kharon Outpost, temporary)

1. Enter Kharon Outpost.
2. Restore power in the generator hall (west).
3. Access the research terminal (north).
4. Discover the cause in the Xenolab (east).
5. Destroy WARDEN in the security core.
6. Reach the containment vault and extract.

Checkpoints autosave at each objective. Blue "Field Uplink" terminals save on demand.

## Layout

```
data/            all tunable content (JSON + ASCII map)
  maps/          the 6 outpost layouts: outpost_<n>.txt (ASCII map) + .json
                 (layout name, room rects, compass directions for story text)
  items.json     item bases, rarities, affixes, experimental specials
  enemies.json   enemy archetype stats and attack timings
  terminals.json logs / terminal text and the flags they set
  mission.json   objective chain + radio comms
  locations.json the ship and mission sites: map, lighting, music, OVERWATCH comms
  crew.json      ship crew: names, colours, dialogue lines
  starmap.json   the star map tree (galaxies, systems, planets, stations), unlocks, mission sites
scripts/
  autoload/      Events (signal bus), InputSetup (KB/M + pad bindings),
                 ItemDB (data + item generation), GameState (character, flags, save/load)
  core/          Combat (armor, crits, statuses), Actor (HP, status effects base class),
                 Iso (projection maths), IsoView (screen-space proxy for an entity)
  player/        Player controller, weapons, abilities, drawing
  enemies/       Enemy state machine (drone/researcher/heavy), Boss (WARDEN)
  world/         Level builder (AStarGrid2D pathing, merged collision, floor baking,
                 wall cutaway), floor chunks, isometric wall blocks, doors,
                 terminals, crates, props, loot drops
  fx/            Projectile (ray-swept, ground-plane), lightweight effects
  ui/            HUD, inventory, character, terminal, pause, end screens, theme
tools/
  gen_maps.py    builds the layouts (variant 1 hand-placed, 2-6 from room templates)
  check_map.py   validates every layout (objective order, gates, no walled-off floor)
  smoke_test.gd  automated play-through of the acceptance criteria
  screenshots.gd one-scene screenshot capture and `perf` timing (needs a display)
```

## Sound

Every sound is synthesised by `tools/gen_audio.py` (pure Python, no dependencies,
deterministic) into `audio/`, 22 kHz mono WAV for a lo-fi 90s sound-module feel:

- **Music** (`audio/music/`): `level.wav`, a 100 BPM E-phrygian industrial loop. It opens
  on a heartbeat kick and monitor beep, then brings in distorted "MIDI guitar" chugs, a
  clanking metal snare and a squelchy lead, with a tritone breakdown. `boss.wav` is a
  138 BPM four-on-the-floor loop that starts when the WARDEN wakes. Both loop seamlessly.
- **Combat**: rifle, shotgun, energy-pistol laser, sword/maul/chainblade swings and hits,
  impacts, grenades and explosions, plus dodge, abilities and reload.
- **Monsters**: mutated researchers groan, snarl when they lunge, and gurgle when they die
  (synthesised vocal tract). Servo-skulls, security heavies and the WARDEN bleep, chatter
  and power down; bigger machines are pitched lower.
- **Facility**: doors, crates, pickups, terminals and level-ups.

`scripts/autoload/audio.gd` (`Audio`) plays sounds at their position in the isometric
view, varies pitch slightly, and caps how many copies of a sound play at once. It also
cross-fades the music. Regenerate with `python3 tools/gen_audio.py` (`sfx` or `music`
for one half). Per-sound volume and voice limits are in the `SFX` table in `audio.gd`.

## Tests

```bash
python3 tools/gen_maps.py                      # regenerate the six layouts (deterministic)
python3 tools/check_map.py                     # validate every layout; exit code = failures
godot --headless --path . -- --smoke --variant 3   # gameplay checks on one layout; exit code = failures
```

The smoke test strips joypad bindings so a connected controller can't interfere. It writes to its own save file.

Performance check (needs a display): `godot --path . -- --shots /tmp/shots perf [--cap]` prints the average frame time in the busiest room.

## Steam Deck

One-time setup on the Deck (Desktop Mode -> Konsole): `passwd` (set a password for
`deck`) and `sudo systemctl enable --now sshd`.

Then from this machine:

```bash
./deploy-to-steamdeck.sh            # host 'steamdeck' (falls back to steamdeck.local)
./deploy-to-steamdeck.sh 192.168.1.50
```

It builds the game, asks for the Deck password once (or uses your SSH key), and
installs to `/home/deck/Games/DeadSignal/`. In Desktop Mode Steam: *Games -> Add a
Non-Steam Game -> Browse*, file filter "All Files", pick `DeadSignal.sh`. Re-run the
script to update; the Steam shortcut keeps working. Saves live in
`~/.local/share/godot/app_userdata/Dead Signal/` on the Deck and are never touched by a redeploy.

If Godot export templates are installed (*Editor -> Manage Export Templates*) it does a
proper release export; otherwise it ships the game data (`DeadSignal.pck`) with the
Godot runtime from this machine. Both run the same. The export preset includes
`data/` (maps, items, story text) and leaves out `tools/`, so `--smoke` and `--shots`
only work from the project, not the deployed build.

Steam artwork (icon, library capsule, wide capsule, hero banner, logo) lives in
`steam_art/` and is copied to `/home/deck/Games/DeadSignal/artwork/`; the script prints
where each image goes in Steam. It's rendered from a staged fight in the real game
(layout 1, generator hall) by `tools/steam_art.gd`, which also writes the window icon
`icon.png`. Regenerate with `godot --path . -- --steam-art` (needs a display).

## Design notes

- **Mission journal** (`scripts/ui/journal_ui.gd`). Every comms line is written to `GameState.journal` as it plays (`journal_log`), tagged with its mission (or "crew"), and saved with the game. Mission status comes from the objective flags; a mission shows up once its `open_flag` (in its mission JSON) is set.
- **Races.** Six playable races (`GameState.RACES`) change the operative's look and nudge their attributes by a small, balanced amount (`attr_mod`, summing to zero; Human has none). The adjustment is added on top of spent points like gear is, so respec and saves only deal with spent points. The creation screen lists each race's adjustments, and the character sheet shows them as "+N race".
- **Isometric projection layer.**
  - The simulation is unchanged: physics, pathing, AI and combat all run on the square tile grid.
  - Rendering uses a 2:1 isometric projection, `screen = (x - y, (x + y) / 2)`, so a 32 px tile becomes a 64x32 diamond.
  - Each entity's body is never drawn. Its `IsoView` sits at the projected position inside a y-sorted root, and screen y equals isometric depth, so plain y-sorting gives the correct draw order.
  - Entity art is drawn in screen space through the view (`cv.draw_*`). Floor-level shapes such as rings, telegraphs and shadows are drawn through `Iso.ground()`, so circles become ellipses on the floor.
- **Walls.**
  - Each wall tile is its own block (`WallTile`), so actors sort correctly in front of or behind it.
  - Blocks between the camera and the player fade out (cutaway), as in Diablo II.
- **Performance.**
  - Floor chunks are baked to textures once after load, so the floor is one quad per 8x8 chunk.
  - Animated views off-screen skip redraws.
  - In the busiest room on an AMD Renoir iGPU, the game runs at about 7 ms per frame uncapped (roughly 138 FPS).

- **Ground-plane combat.**
  - Hit circles sit at actors' feet.
  - Projectiles and aiming are simulated on the ground plane and drawn 16–34 px higher.
  - The mouse is un-projected back to the ground, so the cursor lines up with bodies.
- **Tactical layer.**
  - Security Heavies take only 30% damage from the front and turn slowly, so flank them.
  - Disruptor Pulse stuns enemies, drops the Heavy's shield, cancels telegraphed attacks, and exposes WARDEN's core (+50% damage).
- **Grim visual style** (requirements §2, *Visual style*):
  - **Shadows.** Walls and large props have `LightOccluder2D` footprints. Only the player's lights cast shadows, and those shadows fall on the floor only: the floor uses light layer 2 (`Level.LIGHT_FLOOR`) and is lit by shadow-casting copies of the player's lights. Walls and actors get unshadowed copies, so their faces never sit in their own shadow.
  - **Normal maps.** `shaders/luma_normal.gdshader` derives normals from the brightness of baked art, so lights pick out grout, grates and ribs.
  - **Baking.** `Baker` bakes the floor chunks, and every distinct wall-block look (`WallTile.signature()`), into textures after load.
  - **Lighting.** The ambient light is dark. Lamp pools are small, and some lamps are failing or dying. Floor shading darkens where the floor meets walls and under props.
  - **Post-processing.** `shaders/post_grade.gdshader` runs on CanvasLayer 2: desaturation, crushed blacks, a green-rust grade, film grain and edge chromatic aberration. Loot labels (layer 3) and the HUD (layer 10) sit above it.
  - **Art.** `Shade` draws volumes with a shadow tone, a lit tone and a highlight on the edge facing the light, with no bright outlines. The palette is dull crimson and tarnished brass.
- **Ground loot.**
  - Every item type has its own silhouette on the floor (`scripts/ui/item_icon.gd`), with a glow in its rarity colour.
  - Names are drawn by `LootLabels` on an unlit layer above the world, in rarity colour. Overlapping names stack instead of overlapping.
  - Names show for nearby items, or for all items while Alt / L3 is held.
  - The item you would pick up is highlighted.
- **Controller in menus.** Godot's built-in `ui_*` actions are keyboard-only, so `InputSetup` adds A (Cross) to accept, B (Circle) to go back, and the d-pad and left stick to navigate. The smoke test checks this with synthetic pad events.
- **Save format.** Items are plain dictionaries, so the save is readable JSON at `user://deadsignal_save.json`.
