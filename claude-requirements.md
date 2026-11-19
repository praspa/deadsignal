# Dead Signal


Project: Dead Signal

Game Design & Demo Requirements — v0.2

Status: the demo (sections 1–14) is complete and frozen at git tag demo-v1.0. Development has moved on to the full game; see section 15.

1. Project Vision

Create a dark science-fiction action RPG inspired by Diablo II and the Alternity tabletop RPG universe.

The game features a top-down, quasi-isometric 2D perspective, real-time combat, character progression, equipment, loot, exploration, and environmental storytelling.

The setting should feel grounded, dangerous, technologically advanced, and occasionally unsettling.

Design pillars:

Satisfying, responsive action combat.
Grim dark space gothic graphics, try to stay away from silly roblox/minecraft style blocky silly models. Design aesthetic similar to warhammer 40k.
Meaningful character progression and equipment choices.
Dark, atmospheric science fiction.
Tactical variety rather than repetitive button mashing.
A world that feels like a larger RPG universe beyond the demo.

2. Technical Requirements

Engine: Godot 4.x.
Language: GDScript.
Rendering: 2D Isometric graphics - like diablo 2. Add a projection layer over the square grid simulation.
Input: Keyboard and mouse, with controller support designed into the architecture.
Resolution: 1280x800 for steamdeck
Target: Steam Deck compatibility as a design consideration.
Save system: Local save/load.
Game architecture: Modular, data-driven systems.

Prioritize performance over graphical quality.

Visual style: gritty and grim, not cartoony. Graphics stay procedurally drawn (no image assets yet), with the following:

Lighting and shadows:
Hard shadows from walls and large props (LightOccluder2D), so areas beyond a light are pitch black. Limit shadow casting to key lights (player flashlight, lamps) to protect Steam Deck performance.
Procedurally generated normal maps on the floor and walls, so lights pick out grates, rivets and wall ribs.
Smaller, harsher light pools, darker ambient light, more flickering and failing lights.
Contact shading: dark gradients where walls meet the floor and under props.

Post-processing:
One full-screen shader: film grain, colour grade (crushed blacks, sickly green-brown and rust tones), slight chromatic aberration at the screen edges. Budget about 1 ms per frame.

Art direction:
Minimal outlines. Define shapes with lit and shadowed tones rather than bright outlines (rarity colours stay on loot labels and icons only).
Desaturated palette: dull crimson instead of bright red, tarnished brass instead of yellow.
Characters and props shaded with at least a lit tone, a shadow tone and edge highlights from the light direction, instead of one flat colour per shape.

Sound:
Main Screen Music - 90s mini nine inch nails/doom/command and conquer style industrial. Main screen song has a heart beat type drum beat that increases into a breakdown.
Level music - similar 90s MIDI Nine Inch Nails style. MIDI Industrial heavy metal, dark and ominous.
Combat sounds - automatic rifle bursts, lazer beams shot, melee swing sounds. On a gun reload we hear the gun reload sound.
Monster sounds - biological ones making groaning zombie sounds, robotic monsters making bleeping booping sounds


3. Player Character

The player controls a human operative investigating an abandoned research facility.

Required capabilities:

Eight-direction movement.
Mouse-directed aiming.
Primary weapon attack.
Secondary weapon or melee attack.
Dodge or evasive movement.
Health and energy management.
Experience and leveling.
Equipment management.
Active abilities.

Movement and combat must remain responsive during simultaneous enemy encounters.

4. Combat

Combat should combine Diablo-style accessibility with some tactical depth.

Required systems:

Projectile-based firearms.
Hitscan weapons where appropriate.
Melee attacks.
Enemy detection and aggro.
Enemy attack telegraphs.
Damage calculations.
Armor and damage mitigation.
Critical hits.
Status effects.
Death and loot drops.

Initial weapons:

Assault rifle.
Shotgun.
Energy pistol.
Melee weapon.

5. Character Progression

Implement four core attributes:

Strength: Melee damage and physical capability.
Dexterity: Accuracy, evasion, and ranged weapon effectiveness.
Intelligence: Technology and energy-based abilities.
Willpower: Psionic abilities and resistance.

Characters earn experience through combat and exploration.

The demo must support at least three level-ups and meaningful attribute choices.

6. Abilities

Implement three abilities for the initial character:

Tactical Roll: Short evasive movement with temporary damage avoidance.
Overcharge: Temporarily increases weapon damage or firing performance.
Disruptor Pulse: Area-effect energy attack that interrupts enemies.

Abilities should have cooldowns and clear visual feedback.

7. Equipment and Loot

Equipment slots:

Primary weapon.
Secondary weapon.
Head.
Body armor.
Gloves.
Boots.
Utility device.

Loot rarity:

Common.
Uncommon.
Rare.
Experimental.

Items should have randomized or predefined attributes.

Inventory must support item pickup, inspection, equipping, unequipping, and comparison.

Loot on the ground graphic represents the type (i.e. gun, boots, breastplate, gloves ) along with name and color rarity

8. Enemies

Implement three enemy archetypes:

Security Drone

Fast-moving mechanical enemy.
Ranged energy attack.
Low health.

Mutated Researcher

Aggressive melee enemy.
High movement speed.
Chance to inflict a status effect.

Security Heavy

Slow, heavily armored enemy.
Powerful ranged attacks.
Requires tactical positioning.

Include one boss encounter combining multiple attack patterns.

9. Environment

One explorable research outpost.

Required elements:

Multiple connected rooms.
Corridors and combat arenas.
Environmental obstacles.
Doors and access terminals.
Loot containers.
Environmental storytelling.
Lighting and atmospheric effects.

10. Demo Mission (archived)

The Kharon Outpost mission below was the demo's test setting. It is kept temporarily as the nav console's only destination and will be removed once the first new mission (section 15) exists.

The player investigates a research facility after communications cease.

Objectives:

Enter the facility.
Restore power.
Access the research terminal.
Discover the cause of the incident.
Defeat the facility's security system.
Escape or reach the final containment area.

Narrative delivery should primarily use environmental storytelling, logs, terminals, and limited dialogue.

11. User Interface

Start screen 
Continue
New Game
Controls
Quit

New Game:
Brings you to a character creation Screen.
You choose a Name - A random sci-fi name will be generated
Class (right now only Combat Specialist is available)
There will be , say 5 classes to hover over with class descriptions. 
Combat specialist is the only one with details now (the rest grayed out).

Choose a Race (the character model does get affected by the race)
* Human: The baseline, adaptable species—most widespread across the Stellar Nations.
* Fraal: Slender, pale, large-eyed humanoids modeled after classic "grey" aliens. They are deeply spiritual, generally non-violent, and naturally psionic.   
* Mechalus: Humanoid aliens (also called Aleerians) who bond with cybernetic technology from a young age. They can interface directly with computers and networks.   
* Sesheyan: Nocturnal, winged humanoids with eight small eyes encircling their heads. They come from a low-tech, hunter-gatherer background, have natural gliding/flight capabilities, and are sensitive to bright light.   
* T'sa: Small, fast-moving, reptilian aliens with a sleek build and fine scales. Hyper-curious, talkative, and mechanically gifted, they are constantly in motion.   
* Weren: Towering (over 7 feet tall), heavily muscled, fur-covered warriors with fierce claws and manes. Despite their intimidating size and tribal background, they have a strong sense of honor. 



Required HUD:

Health bar.
Energy bar.
Experience bar.
Ability indicators.
Ammunition count.
Active weapon.
Enemy health indicators.

Additional interfaces:

Inventory.
Equipment.
Character attributes.
Loot inspection.
Dialogue and terminal interaction.

In game Mini-Map to aid in navigation:
In game mini map of the level in the upper right hand corner. Similar to diablo. 
The mini map is Architectural Line-Art: Instead of showing colored textures, grass, or rock surfaces, it renders the level as thin, crisp lines—usually light gray, off-white, or muted gold—representing walls, doorways, cliffs, and impassable obstacles. Explored areas persist. Unexplored areas remain completely blank. Mini map retains the fog of war. Allows you to spot dead ends and unexplored branching paths at a glance.

12. Classes

Will be several classes

For the demo we will focus on first class by default

Combat Specialist - Character sprite looks like a space marine - similar to a star craft space marine with a suit and glass helmet
Skills: Firearms, Heavy Weapons, Armor, Melee, Brute Force
Player Model: A burly, battle hardened, human male space marine


More to come...


13. Demo Acceptance Criteria (met — tag demo-v1.0)

The demo is considered complete when:

The player can move and aim in eight directions.
Combat works reliably against all three enemy archetypes.
Enemies can detect, pursue, attack, and die.
Weapons have distinct behavior.
Loot drops and can be equipped.
Experience and leveling work.
All three abilities work.
The player can complete the mission.
The boss can be defeated.
Progress can be saved and loaded.
The demo can be completed without developer intervention.

14. Explicitly Out of Scope

Originally out of scope for the demo. Now that the full game is under way:

Now in scope: multiple planets and installations (star map), trading (crew vendor, UC currency).

Still out of scope:

Multiplayer.
Crafting.
Companion management / hirelings (undecided whether the game wants this at all).
Ship repair or ship upgrade progression (not wanted for now).
Multiple playable characters.
Extensive dialogue trees.
Endgame systems.
Complex skill trees.



15. Full Game Structure (post-demo)

The game follows Diablo II's town-and-wilderness loop. The "town" is the interior of the player's ship.

15.1 The Ship (hub)                                          [DONE — first pass]

The ship color palette is a silver with blue undertones. Well lit, the player doesn't need to have flashlight turned on. Additionally the player holds no weapon in the ship.

The operative is assigned a ship, the Sable Mule (placeholder name). Not owned or captained by the player. A functional but beat-up bucket of bolts: welded hull patches, exposed cabling, one light that always flickers. The ship is lit well enough such that the character doesn't need to use flash light.

A new game starts aboard the ship (after character creation).
Safe zone: no enemies; weapons and combat abilities are holstered.
Warmer lighting than mission sites; quieter (ship music/ambience still to come).
Rooms: engineering, common deck, cargo hold, medbay, cockpit.
Footlocker stash in the bunk area (to do).
Needs its own visual identity (to do) — it currently reuses the outpost's walls and floors.

15.2 Crew                                                    [placeholders DONE — services to do]

Five crew members, each with a Diablo town role. Dialogue lines react to story flags.

Quartermaster (Dov Harrow) — vendor: buys / sells gear for UC, repairs.
Signals Tech (Ines Ruhl) — identify: decrypts "signal-corrupted" loot.
Medic (Oskar Venn) — heals; attribute respec for a UC fee.
Fence (Kesh) — gambler: sells sealed salvage crates opened blind.
Pilot (Mara Quill) — flies the ship; flavour and dialogue.

Names are placeholders. Currently they stand at their posts and talk; services are not built yet.

Identify mechanic: Rare and Experimental drops come out of missions "signal-corrupted", with affixes shown as static (e.g. "▒▒▒ +?? Damage"). The Signals Tech decrypts them for free aboard the ship. A consumable cipher key decrypts in the field.

There is also a ship cargo stash to hold items that need not be carried in inventory.

15.3 OVERWATCH                                               [DONE — briefing / debrief]

OVERWATCH is the quest giver, over comms. Missions are handed out at the ship's nav console, not by a crew member. OVERWATCH briefs the player on a new game and debriefs after a mission.

15.4 Currency: Universal Credits                              [DONE — earning; spending to do]

Universal Credits, "UC", colloquially "creds".
Drop from enemies, crates and bosses, scaled by character level; picked up by walking over them.
Shown on the HUD and the inventory screen.
Spent at the crew's services (vendor, medic respec, fence crates).

15.5 Star Map (waypoints)                                    [DONE — first pass]

The nav console in the cockpit opens the star map, the game's waypoint system.

What the player sees:
A full-screen star chart over a dark starfield: a visual tree of the known universe, laid out left to right.
Universe (root) → galaxies → star systems → destinations (planets, space stations / floating installations).
Lines connect each node to its parent, like a navigation chart.
Each node type has its own symbol: galaxy = spiral, star system = glowing star, planet = shaded sphere, station = angular hull.
A ship marker shows where the Sable Mule currently is in the tree.
An info panel shows the selected node: name, type, short description, and its status (ship is here / locked / ready to descend).
Locked nodes are drawn dim with a lock and "Uncharted"; their children stay hidden, hinting at a larger universe without spoiling it.

How it works:
1. Select a node: d-pad / left stick moves the selection to the nearest node in that direction; the mouse selects by hovering.
2. Plot a course: A / Enter / click on an unlocked node. The ship marker flies there along the tree's lines (up to the shared parent, then down), animated.
3. Descend: when the ship is at a planet or station that has a mission site, A / Enter / click (or the Descend button) drops the operative to that location.
4. B / Esc closes the star map without travelling.

The ship's position in the tree is saved. Moving within the tree is free; only descending changes location.

Data: data/starmap.json. A flat list of nodes, each with a parent, type, name, description, an optional "location" (key into data/locations.json) and optional "requires" (story flags that unlock it). The layout is computed from the tree, so adding a node needs no coordinates.

15.6 Recall (town portal)                                    [to do]

No consumable town-portal scrolls.
A Recall button with a cooldown (~60 s, not ticking aboard the ship).
Hold ~2 s to channel; taking damage interrupts it, so it isn't a panic button.
Leaves a beacon where the player stood; the ship's boarding ramp / teleport pad returns the player to that exact spot.
Bindings: T on keyboard, R3 on controller.
Mission sites also have a return-shuttle beacon at the landing point. [DONE]

15.7 Locations and travel                                    [DONE]

Each place (the ship, each mission site) is an entry in data/locations.json: map, lighting, music, comms.
Travel autosaves and puts the player at the destination's start point.
Each location remembers its own state while the player is away: floor loot, killed enemies, opened crates, doors, minimap exploration.

15.8 Death and Revival: the Lazarus Cradle                  [DONE]

When the operative dies on a mission, they are not sent to a game-over screen. Their suit's bio-link pulls them back and they wake aboard the ship in the Lazarus Cradle, a regeneration chamber in the medbay (a rejuvenator: fluid-filled pod, med-arms, a lot of noise).

On death: a short death beat on the mission site (fade out), then cut to the ship.
The operative revives in the Lazarus Cradle with full health and energy, and the medic gets a line about it.
The ship is still in orbit where the operative last descended, so the star map is unchanged.
To go back: walk to the nav console, open the star map (the ship is already at that node) and descend.
The mission site keeps its state: enemies already killed stay dead, survivors are still there, loot on the floor stays.
Weapons are holstered on waking, as anywhere aboard the ship.
Death is no longer a "load last save" moment; the game autosaves on revival.

Death penalty:
Lose 10% of carried UC (rounded down).
Lose 5% of the XP needed for the current level, taken from progress toward the next level. Never drops below 0 for the level: the operative can't lose a level.
Gear, inventory and the cargo stash are untouched; no corpse run.
On revival, a message states what was lost (e.g. "-42 UC, -15 XP").
Both percentages are tunable constants.

15.9 First Mission: the Brood Queen                           [to do]

The starter quest, in the spirit of Diablo II's Den of Evil.

OVERWATCH assigns it; the player uses the star map to travel to the first hostile planet.
Planet surface: outdoor area (rock, ash, alien growth) with scattered enemies, loot containers and the hive entrance.
Alien hive: tight, dark, organic cave.
Objective: kill the Brood Queen.
New enemies: Swarmlings (fast, weak, packs), Spitters (ranged acid, damage over time), Broodguard (armoured, charges).
Boss: Brood Queen — spawns eggs, acid spray, burrows to reposition.
Reward: UC, an item, and the next star map node unlocks.

15.10 Build order

1. Ship hub, locations / travel, UC currency.   [DONE]
2. Star map UI on the nav console.   [DONE]
3. Recall button and beacon.
4. First mission: planet surface + hive, new enemies, Brood Queen. Then remove Kharon Outpost.
5. Crew services: vendor, decryption / identify, medic, fence. Cargo stash.   [stash DONE]
6. Death and revival in the Lazarus Cradle.   [DONE]


## Target platform

Target 1280x800 for steamdeck
60FPS
Full controller support (but early testing on Ubuntu just keyboard)

simple menus navigatable with joystick (or early keyboard)

single player
