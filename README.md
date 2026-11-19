# Dead Signal — vertical slice

Grimdark sci-fi action RPG (Godot 4.5, GDScript, 2D isometric in the style of Diablo II). Built from `claude-requirements.md`.

All art is drawn procedurally in code (`_draw()`), so there are no image assets. All audio is synthesised into WAV files (see [Sound](#sound)), which Godot has to import once before the game can play them.

## Run

```bash
godot --path . --headless --import   # import assets (first run, after pulling, after adding audio or classes)
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
| Pause / Quick save / Quick load | Esc / F5 / F9 | Start |
| Show all loot names (hold) | Alt | L3 |
| Menus: move / select / back | Arrows / Enter / Esc | D-pad or left stick / A (PS Cross) / B (PS Circle) |

Movement is screen-relative: W moves up the screen, and diagonals follow the isometric grid, so they run along corridors.

## Character and gear

- **New Game opens character creation.**
  - **Name:** a random sci-fi name is filled in. Type your own or press **Random**.
  - **Race:** six races. Each changes how the operative looks, not their stats (yet). The race list, names and descriptions are in `GameState.RACES`; the look of each race is in `Player.RACE_LOOK`.
  - **Class:** five classes are listed. Only Combat Specialist is available; the rest are locked (`GameState.CLASSES`).
  - **Preview:** a turning figure of the operative, drawn with the real in-game art.
- **What you wear shows.** The helmet, body armour, gloves, boots and utility gear each have their own look on the operative. An empty slot shows the bare undersuit.
- **Paint by rarity**, matching the loot colours: Common is plain gunmetal, Uncommon metallic green, Rare metallic gold, Experimental metallic violet with glowing seams. Weapons are painted the same way.
- **Stance by weapon:**
  - **Assault rifle:** shouldered, two hands.
  - **Shotgun:** held lower at the hip, and pumps after each shot.
  - **Energy pistol:** one hand, arm extended.
  - **Secondary weapon:** a melee weapon hangs at the hip until swung. An energy pistol in the secondary slot sits in a hip holster and is drawn in the off hand while it fires.
- **Auto-equip.** Picking something up fills any empty equipment slot with the best item that fits (highest rarity, then item level). Occupied slots are never changed.
- **Containers glow.** Unopened crates and strongboxes glow softly so you can tell what can be looted, and the glow goes out once they're opened. Future containers get the same look from `InteractGlow`.
- **Minimap** (top right), like Diablo II's automap: line art of walls, doors and obstacles in the game's isometric angle, centred on you. It only shows what you've seen: walls and closed doors block your line of sight, and everything else stays blank, so dead ends and unexplored branches stand out. The explored map is saved with the game.

## Outpost layouts

Like Diablo II, the outpost comes in a finite set of layouts, so players learn them ("oh, it's this map"). There are six:

- **Variant 1** is the original hand-placed map.
- **Variants 2–6** are assembled by `tools/gen_maps.py` from hand-designed room types and validated before they're kept.

The rooms are the generator hall, labs, Xenolab, security core, vault, barracks, storage, medbay, chapel and cargo bay. The mission rooms form a tree, so locked bulkheads can't be bypassed, and the tree is laid out on a coarse grid joined by bending corridors.

Each new game picks a random layout, never the one in your current save. The layout is stored in the save and announced when the game starts. Story text gets its compass directions from the layout (`{gen_dir}` and so on in `data/mission.json` and `data/terminals.json`), so "the generator hall is north-west of the atrium" is always true. To force a layout for testing, add `-- --variant N`.

## Mission

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
scripts/
  autoload/      Events (signal bus), InputSetup (KB/M + pad bindings),
                 ItemDB (data + item generation), GameState (character, flags, save/load)
  core/          Combat (armor, crits, statuses), Actor (HP, status effects base class),
                 Iso (projection maths), IsoView (screen-space proxy for an entity)
  player/        Player controller, weapons, abilities, drawing
  enemies/       Enemy state machine (drone/researcher/heavy), Boss (WARDEN)
  world/         Level builder (AStarGrid2D pathing, merged collision, floor baking,
                 wall cutaway), floor chunks, isometric wall blocks, doors,
                 terminals, crates (with InteractGlow), props, loot drops
  fx/            Projectile (ray-swept, ground-plane), lightweight effects
  ui/            HUD, minimap, character creation, inventory, character sheet,
                 terminal, pause and end screens, theme
tools/
  gen_maps.py    builds the layouts (variant 1 hand-placed, 2-6 from room templates)
  check_map.py   validates every layout (objective order, gates, no walled-off floor)
  smoke_test.gd  automated play-through of the acceptance criteria
  gen_audio.py   synthesises every sound and music loop into audio/
  screenshots.gd one-scene screenshot capture and `perf` timing (needs a display)
```

## Sound

Every sound is synthesised by `tools/gen_audio.py` (pure Python, no dependencies,
deterministic) into `audio/`, 22 kHz mono WAV for a lo-fi 90s sound-module feel:

- **Music** (`audio/music/`): `menu.wav` is the 92 BPM title loop: a muffled heartbeat
  that quickens bar by bar, a snare roll, then a halftime industrial breakdown that
  collapses back into the heartbeat. `level.wav` is a 100 BPM E-phrygian industrial loop. It opens
  on a heartbeat kick and monitor beep, then brings in distorted "MIDI guitar" chugs, a
  clanking metal snare and a squelchy lead, with a tritone breakdown. `boss.wav` is a
  138 BPM four-on-the-floor loop that starts when the WARDEN wakes. Both loop seamlessly.
- **Combat**: rifle, shotgun, energy-pistol laser, sword/maul/chainblade swings and hits,
  impacts, grenades and explosions, plus dodge and abilities. Reloads come in two halves,
  played when the reload starts and when it finishes, so they match any reload time:
  rifle magazine out → magazine in and charging handle; shotgun shells loading → pump.
- **Monsters**: mutated researchers groan, snarl when they lunge, and gurgle when they die
  (synthesised vocal tract). Servo-skulls, security heavies and the WARDEN bleep, chatter
  and power down; bigger machines are pitched lower.
- **Facility**: doors, crates, pickups, terminals and level-ups.

`scripts/autoload/audio.gd` (`Audio`) plays sounds at their position in the isometric
view, varies pitch slightly, and caps how many copies of a sound play at once. It also
cross-fades the music. Regenerate with `python3 tools/gen_audio.py`, or one part with
`sfx`, `music` (all loops) or `menu` (just the title loop). Per-sound volume and voice
limits are in the `SFX` table in `audio.gd`. Then run the import step from [Run](#run).

## Tests

```bash
python3 tools/gen_maps.py                      # regenerate the six layouts (deterministic)
python3 tools/check_map.py                     # validate every layout; exit code = failures
godot --headless --path . -- --smoke --variant 3   # gameplay checks on one layout; exit code = failures
```

The smoke test strips joypad bindings so a connected controller can't interfere. It writes to its own save file.

Screenshots (needs a display): `godot --path . -- --shots <dir> <scene>`. Scenes include `menu`, `creation`, `races` (every race from the front, side and back), `gear` (each weapon stance and rarity tier), `container`, `landing`, `generator`, `labs`, `loot`, `inventory` and `character`; the full list is at the top of `tools/screenshots.gd`.

Performance check (needs a display): `godot --path . -- --shots /tmp/shots perf [--cap]` prints the average frame time in the busiest room. It runs uncapped (`--cap` limits it to 60 FPS), but some desktops, such as Wayland compositors, still hold it to the display refresh and report about 16–17 ms. To check whether a change costs performance, compare against `main` on the same machine, for example from a `git worktree` of `main`.

## Working together

- One branch per feature off an up-to-date `main` (`git switch main && git pull && git switch -c feature/<name>`), merged by pull request.
- Before opening a PR, run the smoke test (above). It should pass with no `SCRIPT ERROR` lines in its output.
- After pulling, run the import step from [Run](#run): new audio files and new `class_name` scripts aren't picked up until you do.
- Godot rewrites `project.godot` (header comments, settings that match the defaults) whenever the editor or an import touches it. Only commit it when a setting really changed.

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
- **Save format.** Items are plain dictionaries, so the save is readable JSON at `user://deadsignal_save.json`. Version 2 added the operative's name, class, race and the explored minimap (deflate-compressed, base64). Older saves still load: they get the defaults and a blank map.
