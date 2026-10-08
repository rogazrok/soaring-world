# Soaring World Red

**Version 1.0.1 · Pokémon Red, Blue & Yellow · gen1recomp 0.3.63+**

Explore Kanto from Dragonite's back. Fly over familiar towns, discover places
that cannot be reached by road, and return to the ground whenever you find a
landing spot.

## Features

- A 3D view of Kanto with two flight cameras: CHASE and HIGH SOAR.
- Dragonite arrival, takeoff and landing animations, with Surf music in flight.
- Landing in towns you have already visited.
- Five repeatable Hidden Areas with their own encounters and item rewards.
- Discovery progress and per-visit rewards that persist through saving and loading.
- A panoramic horizon, moving clouds, animated water and atmosphere effects.
- Day and night lighting that follows the game's current time of day.

## Installation

1. Close the game and back up your save before updating an existing installation.
2. Extract the runtime ZIP into the game's `mods` directory. The resulting layout
   should be `mods/soaring_world_red/manifest.json`.
3. When updating, replace the previous `soaring_world_red` folder completely.
4. Start Pokémon Red, Blue or Yellow in gen1recomp and enable the mod in the game's mod settings.

On Windows, the usual mod directory is
`%APPDATA%/pokemon-love2d/mods`. On other platforms, use the mod directory provided
by your game installation.

The runtime ZIP is everything needed to play. The DevKit is an optional download
for people who want to edit the world. Neither download includes the game engine
or Pokémon ROMs or imported game data.

## Getting the Dragon Call

After you become Champion, return to Pallet Town. Lance will meet you and give
you the **DRAGON CALL**. Use it from the Bag while outdoors to summon Dragonite
and enter Soaring.

An existing save with the Champion victory flag can trigger this meeting; you
do not need to defeat the League again solely to unlock it. Leave room in your
Bag for the item.

## Flight controls

Controls use your normal in-game button bindings, including touch controls.

| Button | Action |
| --- | --- |
| Up / Down | Fly forward / backward |
| Left / Right | Turn |
| A / B | Ascend / descend |
| A at an `A: LAND` prompt | Open the landing confirmation |
| A / B in a confirmation | Confirm / go back |
| Select | Switch between CHASE and HIGH SOAR |
| Start | Open the Soaring Map |
| B or Start on the map | Return to flight |

Opening the map pauses your flight. If a landing
prompt appears, confirm the destination before descending into it.

## Exploring hidden places

Unknown Hidden Areas initially display `???`. Land successfully to discover
their names. Their encounters and rewards vary by area and visit. When you are
finished exploring, use the Dragon Call to return to the sky.

When a new hidden place is waiting, Dragonite gives a short cry and a brief
message at the top of the flight screen. The message does not pause flight.
Some discoveries have a different hint; keep an eye on what Dragonite senses.
Each new instance gives its hint once. Opening the Soaring Map pauses the hint.
Rocky Summit is repeatable, including in saves upgraded from 1.0.0.

Encounters adapt automatically to the selected game. Blue offers Red-exclusive
species in the corresponding slots; Yellow adds species unavailable through
ordinary solo play. The rare Kanto starter encounters remain available in
Yellow even after receiving their usual gifts. In Red and Blue, the selected
starter is excluded from its matching rare encounter slot.

Town landings are available after you have visited those towns in the normal
game. Some secrets have additional discovery requirements; keep exploring.

## Compatibility and troubleshooting

The mod supports **Pokémon Red, Blue and Yellow**, and requires gen1recomp
**0.3.63 or newer, below 0.4.0**. Choose the matching game and import your own
game data through the engine. Other generations are not supported.

This update was checked on Windows with gen1recomp 0.3.63 and actual Red, Blue
and Yellow imports. Mobile testing of 1.0.1 remains to be confirmed. Earlier
phone results apply to 1.0.0, not this update.

Vanilla Fly remains available. Modern Field Moves compatibility was checked
in the earlier Red release; its Blue/Yellow combinations need separate testing.
Mods replacing the overworld, maps or rendering may need compatibility checks.

If you see an error, make sure there is only one installed copy of the mod and
that the previous folder was fully replaced. When reporting a problem, include
your game version, platform, other enabled mods and the steps that caused it.
Attach a screenshot of the error if possible.

## Optional test saves

The `test-saves` folder contains separate Blue USA and Yellow USA `.sav` files
for testing the post-League Lance meeting. They are never loaded automatically.
Import into a **new test slot** for the matching game; keep your own save.
Read `test-saves/README.md` for contents, instructions and validation limits.

## Version history

For earlier milestones and the changes included in this release, see
[Version history](VERSION_HISTORY.md).

See [LICENSE](LICENSE) for licensing information.

## Clouds and distant scenery

Each takeoff creates a fresh cloud layout. Clouds drift in world space and use
varied, softly feathered silhouettes. Their approved density is unchanged.
Distant mainland terrain continues as terraces beyond the playable boundary.
Sparse exterior houses and Pokémon Centers use the same 3D models as the cities.
These are scenery, not additional landing destinations.
