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

Unopened loot containers (supply crates, strongboxes) give off a subtle yellow / gold glow with a slow, soft pulse, so they pop out of the dark while exploring. Strongboxes glow a little stronger than crates. The glow goes out when the container is opened, and opened containers stay dark (also after loading a save). [DONE]

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

The Kharon Outpost mission below was the demo's test setting. It is destination 1 of the full game: the intro mission (see 15.12), retuned for a fresh character (area level ~1–2). It also stays a test destination (the smoke test plays through it).

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
Character attributes. Assigning a point keeps the selection on that attribute (it doesn't jump back to the top), so several points can go into one attribute with repeated presses.
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
Item durability and repairs (not wanted).
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

15.2 Crew                                                    [DONE — decryption deferred]

Five crew members, each with a Diablo town role. Names are placeholders.

Quartermaster (Dov Harrow) — trade: buys and sells gear and supplies for UC.
Signals Tech (Ines Ruhl) — decrypts "signal-corrupted" loot (Diablo's identify). Deferred: see 15.2.2.
Medic (Oskar Venn) — heals; attribute respec for a UC fee.
Fence (Kesh) — sealed salvage crates, opened blind (Diablo's gambler).
Pilot (Mara Quill) — flies the ship; talking to her opens the star map as a shortcut.

There is also the cargo locker (stash) in the hold. [DONE]

Talking to crew (all of them):
Interact opens a crew screen: portrait-style name plate, one line of dialogue, and buttons for their services plus "Leave". Fully navigable with the controller (d-pad / stick, A, B to leave).
Dialogue reacts to progress: each crew member has general lines plus lines unlocked by story flags (e.g. after the Brood Queen dies, after the first death and revival). Data in data/crew.json.

15.2.1 Quartermaster — trade
The screen: vendor stock on the left (tabs: Gear, Supplies), the operative's pack on the right, inspection and comparison with the equipped item, price on every item. Items the player can't afford are greyed.
Gear stock: 12–16 items. Mostly Common and Uncommon, 1–2 Rare, never Experimental. Item level: the character's level, capped at the highest area level reached + 2 (so stock keeps pace with progress without outrunning it). Vendor gear is never signal-corrupted.
Stock refreshes at the start of every session and every time the operative returns from a mission site.
Supplies, always in stock: rifle ammo (30 rounds), shotgun shells (8), stim-pack. (Cipher keys join once decryption is built.)
Selling: any pack item, for 25% of its value. Selling a Rare or Experimental item asks for confirmation.
Sell all junk: one button above the pack sells every Common (gray) item in it at once. The button shows how many items and the total UC, and is greyed when there's no junk. Uncommon and better are never touched. Sold junk goes to Buyback like any sale.
No item durability and no repairs: gear never wears out.
Buyback: the last 10 items sold this session can be bought back at the price they sold for.

15.2.2 Signals Tech — decryption                           [DEFERRED — not building signal corruption yet]
Until this is built, all loot drops fully revealed and the Signals Tech only talks. The design below is kept for later.
Signal corruption: Rare and Experimental items found on missions (drops, containers, bosses) come out signal-corrupted. Common and Uncommon items never are.
A corrupted item shows its rarity colour and its base stats (damage, fire rate, armour), but its affixes and special are hidden: name "Corrupted <base name>", affix lines drawn as static ("▒▒▒ +?? ▒▒▒").
It can be equipped, but its affixes and special do nothing until decrypted.
On the ground and in the pack its label is prefixed with a static glyph.
Decrypting aboard the ship: the Signals Tech decrypts everything in the pack and the cargo locker for free, one button ("Decrypt all"). Short reveal effect: the static resolves into the real name and affixes.
Cipher keys: consumable, sold by the Quartermaster and an occasional drop. Used from the inventory screen on one corrupted item, anywhere. Counted like stims.

15.2.3 Medic — healing and respec
Heal: free. Restores full health and energy and clears status effects.
Respec: refunds every spent attribute point so they can be placed again. The first respec is free; after that it costs 100 UC × character level. Asks for confirmation.
Extra dialogue after the operative's first death and revival in the Lazarus Cradle.

15.2.4 Fence — sealed salvage
Sells sealed crates by category: Weapon, Armour (head / body / gloves / boots, random), Utility.
Price scales with item level: about 150 UC × (1 + 0.2 × (item level − 1)); weapons cost 20% more. Item level follows the same rule as the Quartermaster's stock.
Buying opens the crate on the spot: a short reveal, then the item goes into the pack (needs a free slot).
Better rarity odds than drops: Common 50%, Uncommon 33%, Rare 14%, Experimental 3%. Crate items arrive already decrypted (the reveal is the fun).
Available from the start.

15.2.5 Pilot
No shop. Talking to her offers "Open the star map" (same as the nav console) and flight-related banter that reacts to where the ship is on the star map.

15.2.6 Crew look and personality                              [DONE — first pass]

The crew are a mismatched bunch of odd ducks: each one should read instantly from silhouette, colour and one signature prop, and feel alive through an idle animation and a quirk. Drawn procedurally in the game's style (lit / shadow tones, no outlines), clearly distinct from each other and from the operative. Each gets a small accent light or glow so they pop in the ship's silver-blue rooms.

Quartermaster — Dov Harrow ("the Old Man of the hold")
Look: old, short and barrel-wide, grey mutton-chop whiskers, bald and scarred scalp. Heavy oil-stained leather apron hung with tools over a quilted work shirt. Right arm is a crude hydraulic prosthetic, brass and iron, hissing a little steam. An unlit cigar stub he never lights ("ship rules").
Colours: brown leather, tarnished brass, a red rag in the back pocket.
Prop / setting: stands behind a counter of crates in the cargo hold, a dataslate in his flesh hand; a votive candle and a column of tally marks on the crate beside him.
Idle: counts stock on the dataslate, then knocks twice on a crate for luck; the prosthetic arm twitches and vents steam every so often.
Personality: gruff, superstitious, secretly soft-hearted. Talks to the reactor as "her". Names every crate. Haggles out of habit even though his prices are fixed.

Signals Tech — Ines Ruhl ("never sleeps")
Look: young, thin, all elbows, pale with dark rings under the eyes. Oversized headphones wired straight into a port behind her ear, cables trailing to a backpack decoder rig stuffed with blinking boards. Goggles pushed up into a mess of dyed teal hair. Rumpled tech vest over a hoodie, sleeves pulled over her hands.
Colours: grey hoodie, teal hair, teal and green status LEDs on the rig.
Prop / setting: hunched on a stool at a bank of salvaged decoders in the common deck, screens of scrolling waveforms.
Idle: fingers drum constantly; adjusts a dial, flinches at a burst of static, presses a headphone closer. Sometimes hums three notes under her breath (a nod to the Dead Signal) and stops herself.
Personality: brilliant, jittery, laughs nervously, collects "found sounds" from dead channels. A bit too interested in things she should be afraid of.

Medic — Oskar Venn ("the struck-off doctor")
Look: very tall and gaunt, stooped, long grey ponytail, half-moon spectacles on the end of his nose. Off-white surgical coat with old rust-brown stains that never washed out, a faded red-cross armband, rubber gloves tucked in the breast pocket. A battered medical satchel on his hip.
Colours: dirty white, faded red, steel.
Prop / setting: beside the Lazarus Cradle in the medbay, a surgical lamp and a tray of instruments.
Idle: polishes a bone saw with great care; takes a nip from a flask labelled ANTISEPTIC.
Personality: dry, deadpan gallows humour, calm in any crisis. Lost his licence on Thessaly and won't say why. Treats the operative like a patient who keeps coming back.

Fence — Kesh ("strictly a passenger")
Look: a T'sa: small, quick, lizard-like, fine copper-green scales and big glossy eyes. Swamped in layered coats with far too many pockets, gold rings on every claw, a monocle scanner that clicks as it zooms. A sealed crate always within reach.
Colours: deep purple coat, gold trinkets, copper-green scales.
Prop / setting: perched on top of a stack of sealed crates in a corner of the cargo hold, never on the floor.
Idle: never still: fidgets with a ring, checks a pocket, peers around through the monocle, tail flicking.
Personality: fast-talking, charming, shameless, allergic to customs officers. Calls everyone "friend". Swears every crate is "a fortune, probably".

Pilot — Mara Quill ("she flies, don't ask how")
Look: lean, mid-thirties, close-cropped dark hair with a shaved stripe. A worn flight jacket covered in mismatched patches from every navy and outfit she's flown for. One eye is an amber cybernetic that glows faintly and refocuses with a whirr.
Colours: olive jacket, amber eye glow, patches in every colour.
Prop / setting: slouched in the pilot's chair in the cockpit with her boots up on the console, beside the nav console.
Idle: flips a coin and catches it without looking; chews ration gum; pats the console and mutters to the ship.
Personality: cocky, laid-back, superstitious about the Mule ("she knows when you're rude to her"), loyal under the jokes.

Details for all of them:
Height and build differ so they read at a glance (Kesh smallest, Oskar tallest, Dov widest).
They face the operative when spoken to, and turn back to their idle afterwards.
A short ambient bark the first time the operative walks past them in a visit (e.g. Dov: "Mind the crates."), once per visit so it never nags.
Their name shows above them on hover / when in interact range.

15.2.7 Prices (first pass, tunable in one place)
Item value = 20 × rarity multiplier (Common 1, Uncommon 2.5, Rare 6, Experimental 15) × (1 + 0.15 × (item level − 1)) × (1 + 0.1 × number of affixes).
Buy price = value. Sell price = 25% of value.
Supplies: 30 rifle rounds 15 UC, 8 shells 15 UC, stim-pack 40 UC (later: cipher key 30 UC).
Examples at item level 3: Common ~26 UC, Uncommon ~70 UC, Rare ~190 UC, Experimental ~500 UC.
Target feel: one Kessar IV run (drops + 500 UC bounty) affords a Rare from the Quartermaster or two or three Fence crates.

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
3. Descend: when the ship is at a planet or station that has a mission site, A / Enter / click (or the Descend button) drops the operative to that location. If the destination has more than one discovered landing point, Descend first lists them to choose from (see 15.11).
4. B / Esc closes the star map without travelling.

The ship's position in the tree is saved. Moving within the tree is free; only descending changes location.

Data: data/starmap.json. A flat list of nodes, each with a parent, type, name, description, an optional "location" (key into data/locations.json) and optional "requires" (story flags that unlock it). The layout is computed from the tree, so adding a node needs no coordinates.

15.6 Recall (town portal)                                    [DONE — first cut]

Diablo II's town portal, without the scrolls. One button pulls the operative back to the ship and leaves a beacon, so they can return to the exact spot.

Using it:
Bindings: T on keyboard, R3 (right stick click) on controller. Shown on the HUD as a fourth ability slot with its cooldown, like Roll / Overcharge / Pulse.
Press once to start a 2 s channel (no need to hold the button). The operative stands still while channeling.
Channel visuals and sound: a column of blue light rises around the operative, a ring on the floor closes in over the 2 s, rising hum. At the end: flash, the operative dematerialises, cut to the ship.
Interrupted by: taking damage, moving, rolling, firing, or using an ability. Interrupting costs a short 3 s cooldown, not the full one. This keeps it from being a panic button mid-fight.
Cooldown: 60 s from a successful recall. It ticks everywhere, including aboard the ship.
Not usable aboard the ship (nothing to recall from).

The beacon:
A successful recall leaves a recall beacon where the operative stood: a small blinking marker on the floor, also shown on the minimap.
Only one beacon exists at a time; a new recall replaces the old one. It is saved with the game.
The mission site keeps its state while the operative is away (as for all travel): killed enemies stay dead, survivors stay where they were.

Going back:
Aboard the ship, a teleport pad in the cargo hold (by the boarding ramp) shows "Return to beacon — <location name>". Using it drops the operative on the beacon and removes the beacon.
The pad only works while the ship is still in orbit over that beacon's star map node. If the ship has been moved on the star map, the pad says "Beacon out of range — return the ship to <node>".
Descending from the star map still lands at the site's landing point as usual; the beacon stays until it's used or replaced.
Dying does not create a beacon (the operative wakes in the Lazarus Cradle, see 15.8); an existing beacon is kept.

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

15.9 Destination 3: the Brood Queen (Kessar IV)               [first cut DONE, re-slotted as destination 3 — Brood Nurse, new audio/music, art polish to do]

The source of the swarm, in the spirit of Diablo II's Den of Evil: an outdoor area, then one cave, a boss at the end. It is destination 3 of act 1, after Kharon Outpost (1) and Last Water (2, see 15.13): the liberated governors of Last Water tell OVERWATCH the swarm came from the neighbouring planet, and OVERWATCH sends the operative to wipe out the nest. Area levels move up to match (Ashfall Flats ~5, the Hive ~6).
Monsters scale with area level: +15% health and damage per area level above 2 (Kharon is the baseline).

Story and briefing:
Kessar IV is an ash world with a small mining claim. The claim stopped reporting a week ago. A survey drone caught heat signatures moving under the crust before it went dark.
OVERWATCH (briefing after Last Water, on the ship): "The governors were right. The swarm came from Kessar IV, next door. There was a mining claim there; it stopped reporting a week before Last Water fell. Find the nest, find whatever's laying the eggs, and kill it before it fills another planet."
Kessar IV unlocks on the star map when the governors are freed.

Objectives (shown on the HUD in order):
1. Land on Kessar IV.
2. Find the hive entrance. (A log terminal in the abandoned mining camp points the way.)
3. Enter the hive.
4. Kill the Brood Queen.
5. Return to the ship and report to OVERWATCH (Recall, or walk back to the landing shuttle).
Debrief: OVERWATCH pays a bounty (500 UC for now; economy balance comes later) and unlocks the next star map node (Belt Claim 7).

Area 1 — Ashfall Flats (planet surface):
Outdoor, bigger and more open than the outpost: ash plains, rock ridges and cliff edges as walls, craters, alien growth (resin, fleshy pods) spreading toward the hive.
Its own look: rock and ash instead of metal plating; dusty orange-grey palette; no ceiling lights, dim reddish daylight plus the flashlight; drifting ash particles instead of dust.
Landing point with the return-shuttle beacon.
The abandoned mining camp: a few prefab huts, crates, a dead hauler, corpses, the log terminal (objective 2), loot containers. Environmental storytelling: the miners dug into something.
Enemies scattered in small groups, thicker near the hive.
Finding the hive is part of the mission: the entrance (a resin-crusted sinkhole) is in a different place on each layout, never near the landing point, and the player has to search for it. Clues help without giving it away: alien growth thickens and enemy groups get denser the closer you get, and the mining camp log gives a rough direction. The minimap only shows it once seen.
Several layouts, picked at random per new game (like the outpost): 3 to start.

Area 2 — The Hive (cave):
A separate location reached through the sinkhole (interact: "Descend into the hive"); an exit beside the arrival point leads back up.
Tight, dark, organic: chitin and resin walls, wet floors, tunnels opening into egg chambers. Lighting comes only from bioluminescent growths and the flashlight.
Egg clusters: destructible. They hatch Swarmlings when the operative comes close, unless they are shot first.
One level. The Brood Queen's chamber is the largest room, at the end.
Several layouts (3 to start), random per new game.

New enemies (stats relative to the existing roster):
Swarmling: small, fast insect. HP ~18, speed ~230, melee bite. Attacks in packs of 4–8. Low XP each. Dangerous when they surround; Disruptor Pulse is the answer.
Spitter: bloated ranged bug. HP ~40, speed ~120, keeps its distance. Lobs an arcing acid glob (telegraphed: it rears back) that leaves an acid pool on the floor for ~3 s. Acid applies the existing toxin damage-over-time status.
Broodguard: heavy armoured beetle. HP ~160, armor ~8, speed ~90. Telegraphed charge (paws the ground ~0.8 s, then rushes in a straight line, heavy knockback). If it hits a wall it is stunned for ~1.5 s and takes extra damage. Roll sideways to dodge.
Egg cluster: stationary, HP ~25, hatches 2–3 Swarmlings.
Infested Miner: one of the missing miners, brood growth bursting through the overalls and helmet. HP ~55, speed ~185, melee. Reuses the Mutated Researcher's behaviour (aggressive, fast, chance to inflict toxin) with new art. Mostly in and around the mining camp; tells the story without text.
Ash Burrower: ambush predator hidden under the ash. HP ~70, armor ~3. Invisible until the operative comes within a few tiles; the ash bubbles for a split second (the telegraph), then it erupts with a bite and knockback, and fights in the open afterwards. Surface only; makes the plains dangerous rather than empty.
Brood Nurse (optional, build if time allows): slow, soft-bodied support bug. HP ~60, speed ~80, no real attack. Makes egg clusters near it hatch faster and calls Swarmlings to defend it. A priority target that gives hive fights some tactics.

Where they appear:
Ashfall Flats (surface): mostly Infested Miners (around the camp), Ash Burrowers, small Swarmling packs and the odd Spitter; a few Broodguard close to the hive entrance. The message: something is wrong here.
The Hive: all brood — Swarmlings in numbers, Spitters, Broodguard, egg clusters, Brood Nurses, and the Queen.

The Brood is an original species, native to Kessar IV (not taken from Alternity / Star*Drive): the miners dug into its nest.

Later (not part of this mission): Diablo-style champion packs — occasional groups with a random modifier (Frenzied, Bloated, Armoured) led by a named unique monster (e.g. "Gnashmaw the Hungering"). Variety without new art.

Boss — the Brood Queen:
A huge, mostly stationary insect queen, fat egg-sac and armoured head. HP ~1400, large hit radius. Boss health bar and music like WARDEN.
Phase 1 (100–60%): acid spray, a cone in front of her (telegraphed with a floor marker); calls Swarmlings out of the chamber's egg clusters every ~12 s.
Phase 2 (60–25%): burrow. She sinks into the floor; ripples in the floor track toward the operative; she bursts up under them a moment later (telegraphed circle, roll out of it). Between burrows she resumes phase 1 attacks.
Phase 3 (below 25%): enraged. Faster attacks, and on emerging she sprays acid pools in a ring around her.
Disruptor Pulse interrupts the acid spray and forces her out of a burrow early (stunned briefly).
Loot: one Experimental item, one or two Rare items, a large UC drop, stims.

Audio:
New sounds: Swarmling skitter and bite, Spitter retch and splash, Broodguard roar and charge, egg squelch / burst, Queen screech, burrow rumble, Infested Miner moans (reuse / pitch the zombie groans), Ash Burrower eruption, Brood Nurse warble.
Music: a surface track (sparse, windy, industrial) and a hive track (slower, wet, heavier); the Queen gets a boss track.

Kharon Outpost stays: it remains on the star map as a placeholder / secondary test destination, and the smoke test keeps playing through it. The smoke test also gets a play-through of the Brood Queen mission.

15.10 Re-entrant Areas and Diminishing Returns               [DONE]

Like Diablo II, mission areas are replayable: every new play session repopulates them, so the player can farm monsters, loot and bosses. Farming pays less and less as the character outlevels an area.

When areas reset:
A session starts each time the game is loaded from the main menu (Continue, or loading a save). At that point every mission area resets.
Within a session, areas keep their state as now: travelling to the ship and back (Recall, shuttle, star map) finds the area as it was left.
The ship never resets.

What resets:
Monsters respawn, including bosses (the Brood Queen, WARDEN).
Loot containers refill.
Loot left on the floor is gone (warn the player: store keepers in the cargo locker).
Each area re-rolls its random layout (a new Ashfall Flats / Hive / Kharon layout).
The recall beacon is cleared.

What persists:
Character: level, XP, attributes, inventory, equipment, cargo stash, UC.
Story progress: completed objectives and missions, unlocked star map nodes, the ship's position on the star map.
One-time rewards stay one-time: mission bounties and unlocks are paid only on the first completion; story terminals give their XP only the first time they are read.
Re-killing a boss gives its loot and XP again, but no bounty and no story event (no new debrief).

Saving when quitting:   [DONE]
Quitting always autosaves: Quit to Main Menu, Quit to Desktop (pause menu, death screen) and closing the window (Alt+F4, the window's close button, exiting from the Steam Deck overlay) all save first, with a short "Saving..." message. The player never loses progress by quitting.
This fits the session model: loading starts a new session aboard the ship anyway, so the save only needs the character, stash, UC and story progress, not the exact spot.
While a menu is open the save still happens (the game is paused, nothing changes mid-save).
If the operative is dead when quitting (during the fade before the Lazarus Cradle), the death is resolved first: the death penalty applies and the save puts them in the Cradle, so quitting can't dodge the penalty.
Existing save points stay: travel, checkpoints, revival and the quick-save key.

Area level:
Every mission area has an area level (in data/locations.json), e.g. Ashfall Flats 2, the Hive 3, Kharon Outpost 5.
Monster XP and item drops are based on the area level, not the character's level: loot found in Kessar stays Kessar-grade even for a level 20 character.

Diminishing XP:
Monster XP is scaled by the gap between character level and area level:
  character level <= area level + 2      100%
  each level above that                  -15%
  minimum                                5%
Example: in the Hive (area level 3), a level 5 character gets full XP, level 7 gets 70%, level 10 gets 25%, level 12 and up gets 5%.

XP curve:
XP needed per level grows faster than now (today it is linear: 100 + 60 per level). New curve: XP to next level = 100 × level^1.5, rounded (level 1: 100, level 5: ~1,120, level 10: ~3,160, level 20: ~8,940).
Together with diminishing XP this pushes the player toward harder areas instead of farming the first one forever.
Both the curve and the falloff are tunable constants.

15.11 Linked Zones, Landing Beacons and Links Between Destinations   [DONE — beacons, landing choice, lock reasons, intel unlock; data-driven exits and physical links (elevator, derelict, jump gate) to do]

Diablo II's areas join edge to edge (Cold Plains -> Stony Field). Planets and stations don't, so Dead Signal splits "connection" in two: zones inside one destination are physically linked, and destinations are linked to each other mostly by information.

Act structure, by analogy:
  Diablo II act                      -> a star system (or galaxy)
  chain of areas within an act       -> the zones inside one destination
  waypoint                           -> a landing beacon the player activates
  act boss opens the next act        -> the system's big threat opens its jump gate
  town                               -> the Sable Mule

1. Zones inside a destination
A star map node (planet, station, derelict) is a small cluster of zones, each its own map, joined by physical transitions the player walks through:
  planet: landing zone -> plains -> tunnels -> hive -> deep hive (sinkholes, cave mouths, mine shafts)
  station: docking bay -> habitation deck -> reactor ring (lifts, airlocks)
  derelict: bow -> spine -> engine section (crawlways, breached bulkheads)
Kessar IV already works this way: Ashfall Flats <-> the Hive through the sinkhole.
Each zone is one entry in data/locations.json and lists its exits (which zone, which arrival point).

2. Landing beacons (waypoints)
Some zones have an uplink beacon: a small interactable, usually near the zone's entrance. The first time the operative reaches it and activates it, it is added to that destination's landing points (short effect + message "Landing beacon linked: <zone>").
The landing zone of every destination is always available.
Activated beacons are permanent: they persist across sessions (like Diablo II waypoints), even though the areas themselves reset.
Recall beacons (15.6) are separate and unchanged: a recall beacon returns to an exact spot; landing beacons are fixed points you can descend to any time.

Choosing where to land (star map):
With the ship at a destination, Descend shows that destination's landing points in the info panel, e.g.
  KESSAR IV — choose landing point
    > Ashfall Flats (landing zone)
    > The Hive (beacon)
    · ??? (undiscovered)
Undiscovered beacons show as "???", so the player knows there is more to find. With only one landing point, Descend lands directly as now (no extra step).
Controller: d-pad / stick to pick, A to land, B back to the map.

Retrofit Kessar IV: an uplink beacon at the hive's arrival point (next to the climb-up hole), so after the first trip players can descend straight to the hive (and the Brood Queen) every session.

3. Links between destinations
Planets don't share borders, so most links are information:
Nav data: finishing a mission or reading a terminal reveals another node's coordinates and unlocks it on the star map (e.g. Kharon's logs reveal Relay Station 9; the Kessar hive points at whatever seeded it). Gives story beats a mechanical payoff.
OVERWATCH orders: unlocks by mission completion (as now).
Access codes / keys: a station refuses docking until the codes are found somewhere else.
Unlock conditions in data/starmap.json ("requires") use the same flags for all of these, e.g. "intel:relay_9", "kessar:done", "codes:belt_claim_7". The star map shows the reason a node is locked when known ("Coordinates unknown", "Docking codes required", "Awaiting OVERWATCH clearance").

A few links are physical, used sparingly so they feel special:
Space elevator: from a planet's surface zone up to its orbital station; walking into it moves to the other node's zone, and the ship's star map position follows.
Docked derelict: boarded through a station's airlock zone.
Jump gate: opens the next star system. Its key comes from the system's big threat (the act boss), so beating a system is what opens the next one.

Data:
data/starmap.json nodes list their zones: which is the landing zone, and which zones have beacons ("zones": ["kessar_surface", "kessar_hive"], "landing": "kessar_surface", "beacons": ["kessar_hive"]).
data/locations.json zones list their exits ("exits": {"H": {"to": "kessar_hive", "arrive": "@"}}) and their beacon position, if any (map character).
Activated beacons are saved as flags ("beacon:kessar_hive").

15.12 Acts                                                  [to do]

The star map is the outline of the whole game, not one act. Each galaxy is an act, like Diablo II's acts:

  Act 1 — The Veil            open now (Kessar and Halcyon systems)
  Act 2 — Corvane Reach       locked ("Awaiting OVERWATCH clearance")
  Act 3 — The Drift           locked ("Coordinates unknown")
More galaxies (acts) can be added to data/starmap.json later.

Size of an act: roughly Diablo II's, about 6 main missions and 10–15 zones. A galaxy has 2–3 star systems, each with 2–3 destinations, each destination 1–4 linked zones (15.11).

Act 1 — The Veil (draft):
Kessar System
  1. Kharon Outpost — intro mission (the old demo): WARDEN and the first trace of the Dead Signal. Area level ~1–2.
  2. Kessar III — Last Water: the overrun city; free the captive governors (15.13). Area level ~3–4.
  3. Kessar IV — the Brood Queen's nest, source of the swarm (15.9). Area level ~5–6.
  Belt Claim 7 — automated ore refinery "talking to itself" (unlocked by Kessar IV).
Halcyon System (coordinates from a later mission's nav data)
  Halcyon Prime — colony world, census overdue.
  Relay Station 9 — act 1 finale. The relay has been repeating the same three notes since spring: the Dead Signal returns as act 1's big threat.
Area levels rise through the act (1–2 at Kharon up to around 10–12 at the finale).
Story thread (optional): the Brood woke when the Dead Signal reached Kessar. Ines's recordings of the hive's chittering contain the same three notes, which points the way to Relay Station 9.

Moving between acts:
Known Space (the root of the star map) is not a place. Flying from one galaxy to another only passes through it on the chart.
An act is opened by its gate, Diablo-style: defeating the previous act's final boss gives the jump gate key / OVERWATCH clearance for the next galaxy (a story flag, e.g. "act2_open"), and the next galaxy unlocks on the star map.
OVERWATCH briefs the new act on the ship; the ship stays where it is until the player flies it there.

Going back:
Earlier acts stay open for good: the player can fly back to farm, finish side destinations or revisit landing beacons. Area levels and diminishing XP (15.10) make old acts stop paying off naturally.

Star map presentation:
When there are several acts, the star map opens zoomed onto the current act's galaxy; finished acts stay visible but collapsed, so the view doesn't clutter. The info panel of a galaxy node shows its act number.
The HUD / pause menu shows the current act ("Act 1 — The Veil").

15.13 Destination 2: Last Water (Kessar III)                     [first cut DONE]

Last Water: a frontier boomtown on Kessar III, the last settlement before the deep desert, built around the planet's only deep aquifer (dusty, sun-bleached, a little Wild West: water towers, rail lines, saloon-style cantinas next to prefab towers). The Brood came up through its water mains and overran it. Second mission of act 1, area level ~3–4.

Story:
After Kharon, OVERWATCH picks up a mayday from Last Water: the city stopped answering two days ago, and the last transmissions talk about "bugs coming out of the water mains". The swarm has taken the streets and carried the city's governors off alive.
Debrief / handoff: once freed, the governors talk with OVERWATCH over comms: the swarm came from the neighbouring planet, Kessar IV, where a mining claim went quiet first. OVERWATCH orders the nest eradicated and Kessar IV unlocks (15.9).

Objectives:
1. Land at Last Water's spaceport.
2. Fight into the city.
3. Find the Brood Lieutenant carrying the Civic Hall access card, and kill it.
4. Open the Civic Hall (needs the access card).
5. Free the captive governors.
6. Return to the ship (the governors' report reaches OVERWATCH).

Zones (15.11):
Spaceport (landing zone): landing pads, cargo cranes, barricades the militia didn't hold. Return shuttle. Small and safe-ish: the first bugs arrive at its edge.
City streets (main map): the big one. City blocks as walls, streets and alleys, plazas, a dry riverbed with a rail bridge, wrecked trams and ground cars, makeshift barricades, resin creeping up the walls and over the streets. Random layouts (3 to start), built by a street-and-block generator. The Civic Hall stands at the far end, its door sealed.
Civic Hall (interior): reached through the sealed door. Offices and council chambers turned into a nest: resin everywhere, egg clusters, and the governors cocooned against the walls.
Landing beacon at the Civic Hall entrance, so later sessions can land right there.

The Brood Lieutenant (the access card):
A named elite bug that roams the streets with an escort (the first of the Diablo-style champion packs): bigger than a Broodguard, its own name on a health bar (e.g. "Gutspike the Warden-Taker"), one modifier (e.g. Frenzied: faster attacks; or Armoured).
It has the governors' Civic Hall access card fused into its carapace; killing it drops the card.
Its position changes per layout, somewhere away from the spaceport; the minimap does not show it until seen. Rumours help: survivors' messages and dead militia's logs mention where it was last seen.

The access card:
A quest item: picking it up sets a flag ("lastwater:card") and shows on the HUD objective; it does not take a pack slot and can't be sold or dropped.
The Civic Hall door is a flag-locked door (like Kharon's bulkheads): "Sealed. Civic Hall access card required." until the flag is set.
Re-entrant areas (15.10): the card flag persists, so later sessions can walk straight in.

The captive governors:
Three of them (e.g. Governor Ada Calloway, Marshal Eli Brandt, Treasurer Ruth Okafor), each cocooned in resin somewhere in the Civic Hall, guarded by bugs and egg clusters.
Freeing one: interact to cut the cocoon open (a short channel, ~1.5 s, interrupted by damage like Recall). Each freed governor gets a line of thanks and stays put (they are too weak to walk).
When all three are free, the objective completes and the governors' conversation with OVERWATCH plays over comms.
Freed governors persist (story flags); later sessions find the hall still nested but the cocoons empty.

Creatures:
The Kessar IV brood (Swarmlings, Spitters, Broodguard, egg clusters), plus urban variants:
Wall Crawler: clings to building walls and drops onto the operative from above (telegraph: a shadow on the ground, then the drop).
Infested Militia: like Infested Miners, in the city militia's dusters and hats; some still fire their old rifles, badly.
Optional: Brood Nurses in the Civic Hall (15.9).

Music: its own track, audio/music/lastwater.wav (tools/gen_audio.py): 84 BPM, E minor with a phrygian-dominant edge, a spaghetti-western take on the game's industrial sound: desert wind, a cracked mission bell, a twanging tremolo guitar, a galloping drum rhythm, a lonely whistled melody, and distorted chugs and metal when the swarm section kicks in. [DONE — track made, used once Last Water is built]
Per-area music in general: every location names its track in data/locations.json; one track plays at a time (cross-faded), each generated loop is ~1–2 MB, so a track per area costs nothing noticeable. If the track count grows large, load tracks on demand instead of at startup.

Rewards: OVERWATCH bounty, loot from the Lieutenant (good odds of Rare), the governors' thanks (UC reward from the city treasury), Kessar IV unlocked.

New work: city wall / floor style (buildings, streets, signs, a western palette), street-and-block map generator, spaceport and Civic Hall maps, Brood Lieutenant (champion), quest-item pickup + flag-locked door, governors (cocoon interactable + dialogue), Wall Crawler and Infested Militia, mission data, re-slot Kharon (retune to area level 1–2, debrief unlocks Last Water) and Kessar IV (area levels up, briefing after Last Water).

15.14 Build order

1. Ship hub, locations / travel, UC currency.   [DONE]
2. Star map UI on the nav console.   [DONE]
3. Recall button and beacon.   [DONE]
4. First mission: planet surface + hive, new enemies, Brood Queen. (Kharon Outpost stays as a secondary destination.)   [first cut DONE]
5. Crew services: crew screen, Quartermaster trade, Medic heal / respec, Fence crates, Pilot shortcut, crew look and personality. Cargo stash.   [stash DONE]  (Signal corruption / decryption deferred.)   [DONE]
6. Death and revival in the Lazarus Cradle.   [DONE]
7. Re-entrant areas: reset on each session, area levels, diminishing XP, new XP curve.   [DONE]
8. Linked zones and landing beacons: beacon interactable, landing point choice on the star map, Kessar IV hive beacon; locked-node reasons on the star map; intel / access-code unlocks.   [DONE; exits in data + physical links later]
9. Acts: act data on galaxy nodes, current act on the HUD / pause menu, act gate flag unlocking the next galaxy, star map focused on the current act. Then act 1 content: Belt Claim 7, Halcyon Prime, Relay Station 9 finale.
10. Act 1 order: Kharon (intro, retuned) -> Last Water (new) -> Kessar IV (re-slotted). Last Water as in 15.13.   [first cut DONE]


## Target platform

Target 1280x800 for steamdeck
60FPS
Full controller support (but early testing on Ubuntu just keyboard)

simple menus navigatable with joystick (or early keyboard)

single player
