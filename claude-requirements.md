# Dead Signal


Project: Dead Signal

Game Design & Demo Requirements — v0.1

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

Lootable containers, crates, chests, boxes, tables (any container in the future) - should emit a soft glow indicating that it's interactable. It's hard to tell exactly what's openable.

The in game player model gets updated based on what type of weapon or equipment is being held/worn/wielded.
A big part of these games is the satisfaction of seeing your character wear the new armor or new weapon. The way the weapon is wielded depends on its type, e.g. an assault rife is held differently than a blaster pistol. Low level equipment is boring gunmetal gray, where as unique armor might be metallic red or green for example.

If the player has an equipment slot not occupied, the game automatically equips the highest rarity item in inventory to that equipemnt slot (mostly applicable on item pickup)

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

10. Demo Mission

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


13. Demo Acceptance Criteria

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

Do not implement these features in the initial demo:

Multiplayer.
Multiple planets.
Crafting.
Trading.
Companion management.
Multiple playable characters.
Extensive dialogue trees.
Endgame systems.
Complex skill trees.

These may be considered after the vertical slice is playable and evaluated.



## Target platform

Target 1280x800 for steamdeck
60FPS
Full controller support (but early testing on Ubuntu just keyboard)

simple menus navigatable with joystick (or early keyboard)

single player
